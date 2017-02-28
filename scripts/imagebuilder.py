#!/usr/bin/env python

# imagebuilder.py
# rebuilds/fetches docker container images per their git status in repo
# in addition to docker, needs `sudo apt-get install python-git`

import argparse
import datetime
import git
import json
import logging
import os
# import pprint  # occasionally needed for debugging docker output
import re
import string
import sys
import tarfile
import tempfile
import time
import xml.etree.ElementTree as ET
import yaml

global args
global conf


def setup_logging(name=None, logfile=False):
    global args

    if name:
        log = logging.getLogger("-".join([__name__, name]))
    else:
        log = logging.getLogger(__name__)

    slh = logging.StreamHandler(sys.stdout)
    slh.setFormatter(logging.Formatter(logging.BASIC_FORMAT))
    slh.setLevel(logging.DEBUG)

    log.addHandler(slh)

    # secondary logging to a file, always DEBUG level
    if logfile:
        fn = os.path.join(conf.logdir, "%s.log" % name)
        flh = logging.FileHandler(fn)
        flh.setFormatter(logging.Formatter(logging.BASIC_FORMAT))
        flh.setLevel(logging.DEBUG)
        log.addHandler(flh)

    return log

LOG = setup_logging()


def parse_args():
    global args

    parser = argparse.ArgumentParser()

    parser.add_argument('container_list',
                        type=argparse.FileType('r'),
                        help="YAML Config and container list")

    group = parser.add_mutually_exclusive_group()

    group.add_argument('-b', '--build_force',
                       action="store_true",
                       help="Build (don't fetch) all internal containers")

    group.add_argument('-f', '--fetch_force',
                       action="store_true",
                       help="Only fetch containers, fail if build required")

    parser.add_argument('-d', '--dry_run',
                        action="store_true",
                        help="Don't build/fetch anything")

    parser.add_argument('-g', '--graph', default=None,
                        help="Filename for DOT graph file of image dependency")

    parser.add_argument('-l', '--build_log_dir',
                        action="store",
                        help="Log build output to this dir if set")

    parser.add_argument('-p', '--push',
                        action="store_true",
                        help="Push to docker registry")

    parser.add_argument('-r', '--repo_root',
                        default="..",
                        action="store",
                        help="Repo root directory")

    parser.add_argument('-v', '--verbosity',
                        action='count', default=1,
                        help="Repeat to increase log level")

    args = parser.parse_args()

    if args.verbosity > 1:
        LOG.setLevel(logging.DEBUG)
    else:
        LOG.setLevel(logging.INFO)


def load_config():
    global args
    global conf

    try:
        conf = yaml.safe_load(args.container_list)
    except yaml.YAMLError:
        LOG.exception("Problem loading container list file")
        sys.exit(1)


def split_name(input_name):
    """ split a docker image name in the 'name:tag' format into components """

    name = input_name
    tag = None

    # split name:tag if given in combined format
    name_tag_split = string.split(input_name, ":")

    if len(name_tag_split) > 1:  # has tag, return separated version
        name = name_tag_split[0]
        tag = name_tag_split[1]

    return (name, tag)


class RepoRepo():
    """ git repo managed by repo tool"""

    manifest_branch = ""

    def __init__(self, name, path, remote):

        self.name = name
        self.path = path
        self.remote = remote
        self.git_url = "%s%s" % (remote, name)

        try:
            self.git_repo_o = git.Repo(self.abspath())
            LOG.debug("Repo - %s, path: %s" % (name, path))

            self.head_commit = self.git_repo_o.head.commit.hexsha
            LOG.debug(" head commit: %s" % self.head_commit)

            commit_t = time.gmtime(self.git_repo_o.head.commit.committed_date)
            self.head_commit_t = time.strftime("%Y-%m-%dT%H:%M:%SZ", commit_t)
            LOG.debug(" commit date: %s" % self.head_commit_t)

            self.clean = not self.git_repo_o.is_dirty(untracked_files=True)
            LOG.debug(" clean: %s" % self.clean)

            # list of untracked files (expensive operation)
            self.untracked_files = self.git_repo_o.untracked_files
            for u_file in self.untracked_files:
                LOG.debug("  Untracked: %s" % u_file)

        except Exception:
            LOG.exception("Error with git repo: %s" % name)
            sys.exit(1)

    def abspath(self):
        global args
        return os.path.abspath(os.path.join(args.repo_root, self.path))

    def path_clean(self, test_path, branch=""):
        """ Is working tree on branch and no untracked files in path? """
        global conf

        if not branch:
            branch = self.manifest_branch

        LOG.debug("  Looking for changes in path: %s" % test_path)

        p_clean = True

        # diff between branch head and working tree (None)
        branch_head = self.git_repo_o.commit(branch)
        diff = branch_head.diff(None, paths=test_path)

        if diff:
            p_clean = False

        for diff_obj in diff:
            LOG.debug("  file not on branch: %s" % diff_obj)

        # remove . to compare paths using .startswith()
        if test_path == ".":
            test_path = ""

        for u_file in self.untracked_files:
            if u_file.startswith(test_path):
                LOG.debug("  untracked file in path: %s" % u_file)
                p_clean = False

        return p_clean


class RepoManifest():
    """ parses manifest XML file used by repo tool"""

    def __init__(self):
        global args
        global conf

        self.manifest_xml = {}
        self.repos = {}
        self.branch = ""

        self.manifest_file = os.path.abspath(
                                os.path.join(args.repo_root,
                                             ".repo/manifest.xml"))

        LOG.info("Loading manifest file: %s" % self.manifest_file)

        try:
            tree = ET.parse(self.manifest_file)
            self.manifest_xml = tree.getroot()
        except Exception:
            LOG.exception("Error loading repo manifest")
            sys.exit(1)

        # Find the default branch
        default = self.manifest_xml.find('default')
        self.branch = "%s/%s" % (default.attrib['remote'],
                                 default.attrib['revision'])

        # Find the remote URL for these repos
        remote = self.manifest_xml.find('remote')
        self.remote = remote.attrib['review']

        LOG.info("Manifest is on branch '%s' with remote '%s'" %
                 (self.branch, self.remote))

        project_repos = {}

        for project in self.manifest_xml.iter('project'):
            repo_name = project.attrib['name']
            rel_path = project.attrib['path']
            abs_path = os.path.abspath(os.path.join(args.repo_root,
                                       project.attrib['path']))

            if os.path.isdir(abs_path):
                project_repos[repo_name] = rel_path
            else:
                LOG.debug("Repo in manifest but not checked out: %s" %
                          repo_name)

        for repo_name, repo_path in project_repos.iteritems():
            self.repos[repo_name] = RepoRepo(repo_name, repo_path, self.remote)
            self.repos[repo_name].manifest_branch = self.branch

    def get_repo(self, repo_name):
        return self.repos[repo_name]

# DockerImage Status Constants

DI_UNKNOWN = 'unknown'  # unknown status
DI_EXISTS = 'exists'  # already exists in docker, has an image_id

DI_BUILD = 'build'  # needs to be built
DI_FETCH = 'fetch'  # needs to be fetched (pulled)


class DockerImage():

    def __init__(self, name, repo_name=None, repo_d=None, path=".",
                 context=".", dockerfile='Dockerfile', labels=None,
                 tags=None, image_id=None, components=None, status=DI_UNKNOWN):

        LOG.debug("New DockerImage object from name: %s" % name)

        # name to pull as, usually what is provided on creation.
        # May be changed by create_tags
        self.raw_name = name

        # Python's mutable defaults is a landmine
        if labels is None:
            self.labels = {}
        else:
            self.labels = labels

        self.repo_name = repo_name
        self.repo_d = repo_d
        self.path = path
        self.context = context
        self.dockerfile = dockerfile
        self.tags = []  # tags are added to this later in __init__
        self.image_id = image_id
        self.components = components
        self.status = status

        self.parent_name = None  # set by _find_parent_name()
        self.parent = None  # pointer to parent DockerImage object
        self.children = []   # list of child DockerImage objects

        # split name:tag if given in combined format
        (image_name, image_tag) = split_name(name)
        if image_tag:  # has tag
            self.name = image_name
            self.tags.append(image_tag)
        else:  # no tag
            self.name = image_name

        # Add the build tag if exists
        if conf['docker_build_tag'] is not None and \
                conf['docker_build_tag'] not in self.tags:
            self.tags.append(conf['docker_build_tag'])

        # split names from tag list
        if tags is not None:
            for tag in tags:
                thistag = ""
                (tag_name, tag_tag) = split_name(tag)
                if tag_tag:  # has name also, use just tag
                    thistag = tag_tag
                else:  # just a bare tag
                    thistag = tag_name

                if thistag not in self.tags:  # don't duplicate tags
                    self.tags.append(thistag)

        # self.clean only applies to this container
        self.clean = self._context_clean()
        self._find_parent_name()

    def __str__(self):
        return self.name

    def buildable(self):
        """ Can this image be built from a Dockerfile? """
        if self.repo_name:  # has a git repo to be built from
            return True
        return False

    def _context_clean(self):
        """ Determine if this is repo and context is clean """

        if self.buildable():

            # check if on master branch
            repo_clean = self.repo_d.clean

            # only check the Docker context for cleanliness
            context_path = os.path.normpath(
                                os.path.join(self.path, self.context))
            context_clean = self.repo_d.path_clean(context_path)

            # check of subcomponents are clean
            components_clean = self.components_clean()

            LOG.debug(" Build Context Cleanliness -")
            LOG.debug("  repo: %s, context: %s, components: %s" %
                      (repo_clean, context_clean, components_clean))

            if context_clean and repo_clean and components_clean:
                return True
            else:
                return False

        return True  # unbuildable images are clean

    def parent_clean(self):
        """ if all parents are clean """

        if self.buildable():
            if self.clean and self.parent.parent_clean():
                return True
            else:
                return False

        return True  # unbuildable images are clean

    def compare_labels(self, other_labels):
        """ Returns True if image label-schema.org labels match dict """

        comparable_labels_re = [
                r".*name$",
                r".*vcs-url$",
                r".*vcs-ref$",
                ]

        for clr in comparable_labels_re:  # loop on all comparable labels
            for label in self.labels:  # loop on all labels
                if re.match(clr, label) is not None:   # if label matches re
                    # and label exists in other, and values are same
                    if label in other_labels and \
                            self.labels[label] == other_labels[label]:
                        pass  # continue through loop
                    else:
                        return False  # False when first difference found

        return True  # only when every label matches

    def same_name(self, other_name):
        """ compare image name (possibly with tag) against image name/tag """

        (o_name, o_tag) = split_name(other_name)

        if o_tag is None and self.name == o_name:
            return True
        elif self.name == o_name and o_tag in self.tags:
            return True

        return False

    def components_clean(self):

        if self.buildable() and self.components is not None:
            for component in self.components:
                if not component['repo_d'].clean or \
                        not component['repo_d'].path_clean(component['path']):
                    return False

        return True

    def component_labels(self):
        """ returns a dict of labels for subcomponents """

        if self.buildable() and self.components is not None:

            comp_l = {}

            for component in self.components:

                LOG.debug(" component %s generating child labels" %
                          component['repo_name'])

                prefix = "org.opencord.component.%s." % component['repo_name']

                comp_l[prefix + "vcs-url"] = component['repo_d'].git_url

                if component['repo_d'].clean and \
                        component['repo_d'].path_clean(component['path']):
                    clean = True
                else:
                    clean = False

                if clean:
                    comp_l[prefix + "version"] = self.repo_d.manifest_branch
                    comp_l[prefix + "vcs-ref"] = \
                        component['repo_d'].head_commit
                else:
                    comp_l[prefix + "version"] = "dirty"
                    comp_l[prefix + "vcs-ref"] = ""

            return comp_l

        return None

    def child_labels(self, repo_list=None):
        """ return a dict of labels to apply to child images """

        LOG.debug(" parent image %s generating child labels" % self.name)

        # only create labels when they haven't already been created
        if repo_list is None:
            repo_list = []

        LOG.debug(" repos already labeled with: %s" % ",".join(repo_list))

        cl = {}

        if self.buildable() and self.repo_name not in repo_list:

            LOG.debug("  labeling for repo %s" % self.repo_name)

            prefix = "org.opencord.component.%s." % self.repo_name

            cl[prefix + "vcs-url"] = self.repo_d.git_url

            if self.clean:
                cl[prefix + "version"] = self.repo_d.manifest_branch
                cl[prefix + "vcs-ref"] = self.repo_d.head_commit
            else:
                cl[prefix + "version"] = "dirty"
                cl[prefix + "vcs-ref"] = ""

            repo_list.append(self.repo_name)

        # include component labels if present
        if self.components is not None:
            cl.update(self.component_labels())

        # recursively find labels up the parent chain
        if self.parent is not None:
            cl.update(self.parent.child_labels(repo_list))

        return cl

    def create_labels(self):
        """ Create label-schema.org labels for image """

        if self.buildable():

            LOG.debug("Creating labels for: %s" % self.name)

            self.labels['org.label-schema.name'] = self.name
            self.labels['org.label-schema.schema-version'] = "1.0"

            # org.label-schema.build-date
            time_now = datetime.datetime.utcnow()
            build_date = time_now.strftime("%Y-%m-%dT%H:%M:%SZ")
            self.labels['org.label-schema.build-date'] = build_date

            # git version related labels
            self.labels['org.label-schema.vcs-url'] = self.repo_d.git_url

            if self.clean:
                self.labels['org.label-schema.version'] = \
                    self.repo_d.manifest_branch
                self.labels['org.label-schema.vcs-ref'] = \
                    self.repo_d.head_commit
                self.labels['org.opencord.vcs-commit-date'] = \
                    self.repo_d.head_commit_t
            else:
                self.labels['org.label-schema.version'] = "dirty"
                self.labels['org.label-schema.vcs-ref'] = ""

            # include component labels if present
            if self.components is not None:
                self.labels.update(self.component_labels())

    def create_tags(self):
        """ Create docker tags as needed """

        if self.buildable():
            LOG.debug("Creating tags for image: %s" % self.name)

            # if clean and parents clean, add tags for branch/commit
            if self.parent_clean():
                build_tag = conf['docker_build_tag']
                if build_tag not in self.tags:
                    self.tags.append(build_tag)

                commit_tag = self.repo_d.head_commit
                if commit_tag not in self.tags:
                    self.tags.append(commit_tag)

                    # pulling is done via raw_name, set tag to commit
                    self.raw_name = "%s:%s" % (self.name, commit_tag)

            LOG.debug("All tags: %s" %
                      ", ".join(self.tags))

    def _find_parent_name(self):
        """ set self.parent_name using Dockerfile FROM line """

        if self.buildable():
            # read contents of Dockerfile into df
            with open(self.dockerfile_abspath()) as dfh:
                df = dfh.read()

            # find FROM line to determine image parent
            frompatt = re.compile(r'^FROM\s+(.*)$', re.MULTILINE)
            fromline = re.search(frompatt, df)

            self.parent_name = fromline.group(1)  # may have tag

    def dockerfile_abspath(self):
        """ returns absolute path to Dockerfile for this image """

        if self.buildable():
            return os.path.join(self.repo_d.abspath(),
                                self.path, self.dockerfile)
        else:
            return None

    def dockerfile_rel_path(self):
        """ returns the path relative to the context of the Dockerfile """

        if self.buildable():
            if self.context is ".":
                return self.dockerfile
            else:
                return os.path.normpath(os.path.join(self.path,
                                                     self.dockerfile))
        else:
            return None

    def context_tarball(self):
        """ returns a filehandle to a tarball (tempfile) for the image """

        if self.buildable():

            context_path = os.path.normpath(
                               os.path.join(self.repo_d.abspath(),
                                            self.path, self.context))

            LOG.info("Creating context tarball of path: %s" % context_path)

            t_fh = tempfile.NamedTemporaryFile()
            t = tarfile.open(mode='w', fileobj=t_fh, dereference=True)

            # exclude files in this list
            exclusion_list = ['.git']

            # see docker-py source for context
            for path in sorted(
                    docker.utils.exclude_paths(context_path, exclusion_list)):
                t.add(os.path.join(context_path, path),
                      arcname=path,
                      recursive=False)

            # add sub-components to tarball if required
            if self.components is not None:
                for component in self.components:
                    c_ctx_p = os.path.normpath(
                                os.path.join(component['repo_d'].abspath(),
                                             component['path']))

                    LOG.info("Adding component %s at context %s" %
                             (component['repo_name'], c_ctx_p))

                    # walk component source path
                    for path in sorted(
                      docker.utils.exclude_paths(c_ctx_p, exclusion_list)):

                        # path to where to put files in the archive
                        cf_dest = os.path.normpath(
                                    os.path.join(component['dest'], path))

                        t.add(os.path.join(c_ctx_p, path),
                              arcname=cf_dest,
                              recursive=False)

                # t.list()  # prints all files in tarball
            t.close()
            t_fh.seek(0)
            return t_fh

        else:
            return None

    def buildargs(self):
        """ returns array of labels in docker buildargs compliant format """
        ba_a = {}

        for label_k in self.labels:
            ba_re = re.compile(r'\W')  # non alpha/num/_ chars
            ba_label = ba_re.sub('_', label_k)
            ba_a[ba_label] = self.labels[label_k]

        return ba_a


class DockerBuilder():

    def __init__(self, repo_manifest):

        self.rm = repo_manifest
        self.dc = None  # Docker Client object

        self.images = []

        # create dict of images, setting defaults
        for image in conf['repo_docker_images']:

            repo_d = self.rm.get_repo(image['repo'])

            if "components" in image:
                components = []

                for component in image['components']:
                    comp = {}
                    comp['repo_name'] = component['repo']
                    comp['repo_d'] = self.rm.get_repo(component['repo'])
                    comp['dest'] = component['dest']
                    comp['path'] = component.get('path', '.')
                    components.append(comp)
            else:
                components = None

            # set the full name in case this is pulled
            full_name = "%s:%s" % (image['name'], conf['docker_build_tag'])

            img_o = DockerImage(full_name, image['repo'], repo_d,
                                image.get('path', '.'),
                                image.get('context', '.'),
                                image.get('dockerfile', 'Dockerfile'),
                                components=components)

            self.images.append(img_o)

        # add misc images
        for misc_image in conf['misc_docker_images']:
            img_o = DockerImage(misc_image)
            self.images.append(img_o)

        if not args.dry_run:
            self._docker_connect()

        self.create_dependency()
        self.find_preexisting()

        if args.graph is not None:
            self.dependency_graph(args.graph)

        self.process_images()

    def _docker_connect(self):
        """ Connect to docker daemon """

        self.dc = docker.from_env()

        if self.dc.ping():
            LOG.debug("Docker server is responding")
        else:
            LOG.error("Unable to ping docker server")
            sys.exit(1)

    def find_preexisting(self):
        """ find images that already exist in Docker and mark """

        if self.dc:
            LOG.info("Evaluating already built/fetched Docker images")

            # get list of images from docker
            pe_images = self.dc.images()

            for pe_image in pe_images:
                raw_tags = pe_image['RepoTags']

                # ignoring all <none>:<none> images, reasonable?
                if "<none>:<none>" not in raw_tags:
                    LOG.debug(" Preexisting Image - ID: %s, tags: %s" %
                              (pe_image['Id'], ",".join(raw_tags)))

                    image = self.find_image(raw_tags[0])

                    if image is not None and \
                            image.compare_labels(pe_image['Labels']):
                        image.image_id = pe_image['Id']
                        image.status = DI_EXISTS

    def find_image(self, image_name):
        """ return image object matching name """
        LOG.debug("attempting to find image for: %s" % image_name)

        for image in self.images:
            if image.same_name(image_name):
                return image
        return None

    def create_dependency(self):
        """ set parent/child links for images """

        # list of all parent image names, with dupes
        parents_with_dupes = [img.parent_name for img in self.images
                              if img.parent_name is not None]

        # remove duplicates
        parents = list(set(parents_with_dupes))

        LOG.info("All parents list: %s" % ", ".join(parents))

        # list of "external parents", ones not built internally
        external_parents = []

        for parent_name in parents:
            LOG.debug("Evaluating parent image: %s" % parent_name)
            internal_parent = False

            # match on p_name, without tag
            (p_name, p_tag) = split_name(parent_name)

            for image in self.images:
                if image.same_name(p_name):  # internal image is a parent
                    internal_parent = True
                    LOG.info(" Internal parent: %s" % image.name)
                    break

            if not internal_parent:  # parent is external
                LOG.info(" External parent: %s" % parent_name)
                external_parents.append(parent_name)

        # add unique external parents to image list
        for e_p_name in set(external_parents):
            LOG.info(" Creating external parent image object: %s" % e_p_name)
            img_o = DockerImage(e_p_name)
            self.images.append(img_o)

        # now that all images (including parents) are in list, associate them
        for image in filter(lambda img: img.parent_name is not None,
                            self.images):

            LOG.debug("Associating image: %s" % image.name)

            parent = self.find_image(image.parent_name)
            image.parent = parent

            if parent is not None:
                LOG.debug(" internal image '%s' is parent of '%s'" %
                          (parent.name, image.name))
                parent.children.append(image)

            else:
                LOG.debug(" external image '%s' is parent of '%s'" %
                          (image.parent_name, image.name))

        # loop again now that parents are linked to create labels
        for image in self.images:
            image.create_labels()
            image.create_tags()

            # if image has parent, get labels from parent(s)
            if image.parent is not None:
                LOG.debug("Adding parent labels from %s to child %s" %
                          (image.parent.name, image.name))

                # don't create component labels for same repo as image
                repo_list = [image.repo_name]
                image.labels.update(image.parent.child_labels(repo_list))

    def dependency_graph(self, graph_fn):
        """ save a DOT dependency graph to a file """

        LOG.info("Saving DOT dependency graph to: %s" % graph_fn)

        try:
            import graphviz
        except ImportError:
            LOG.error('graphviz pip module not found')
            raise

        dg = graphviz.Digraph(comment='Image Dependency Graph',
                              graph_attr={'rankdir': 'LR'})

        component_nodes = []

        # Use raw names, so they match with what's in Dockerfiles
        # delete colons as python graphviz module breaks with them
        for image in self.images:
            name_g = image.raw_name.replace(':', '\n')
            dg.node(name_g)

            if image.parent is not None:
                name_p = image.parent.raw_name.replace(':', '\n')
                dg.edge(name_p, name_g)

            if image.components is not None:
                for component in image.components:
                    name_c = "component - %s" % component['repo_name']
                    if name_c not in component_nodes:
                        dg.node(name_c)
                        component_nodes.append(name_c)
                    dg.edge(name_c, name_g, "", {'style': 'dashed'})

        with open(graph_fn, 'w') as g_fh:
            g_fh.write(dg.source)

    def process_images(self):
        """ determine whether to build/fetch images """

        # upstream images (have no parents), must be fetched
        must_fetch_a = filter(lambda img: img.parent is None, self.images)

        for image in must_fetch_a:
            if image.status is not DI_EXISTS:
                image.status = DI_FETCH

        # images that can be built or fetched (have parents)
        b_or_f_a = filter(lambda img: img.parent is not None, self.images)

        for image in b_or_f_a:
            if not image.parent_clean():
                # must be built if not clean
                image.status = DI_BUILD
            elif image.status is not DI_EXISTS:
                # try to fetch if clean and doesn't exist
                image.status = DI_FETCH
            # otherwise, image is clean and exists (image.status == DI_EXISTS)

        c_and_e_a = filter(lambda img: img.status is DI_EXISTS, self.images)
        LOG.info("Clean and preexisting images: %s" %
                 ", ".join(c.name for c in c_and_e_a))

        upstream_a = filter(lambda img: (img.status is DI_FETCH and
                                         img.parent is None), self.images)
        LOG.info("Upstream images that must be fetched: %s" %
                 ", ".join(u.name for u in upstream_a))

        fetch_a = filter(lambda img: (img.status is DI_FETCH and
                                      img.parent is not None), self.images)
        LOG.info("Clean but buildable images to attempt to fetch: %s" %
                 ", ".join(f.name for f in fetch_a))

        build_a = filter(lambda img: img.status is DI_BUILD, self.images)
        LOG.info("Unclean context or parents, images must be built: %s" %
                 ", ".join(b.name for b in build_a))

        for image in upstream_a:
            self._fetch_image(image)

        fetch_failed = []

        fetch_sort = sorted(fetch_a, key=(lambda img: len(img.children)),
                            reverse=True)
        for image in fetch_sort:
            if not self._fetch_image(image):
                # if didn't fetch, build
                image.status = DI_BUILD
                fetch_failed.append(image)

        for image in fetch_failed:
            self._build_image(image)

        for image in build_a:
            self._build_image(image)

    def tag_image(self, image):
        """ applies tags to an image """

        for tag in image.tags:

            LOG.info("Tagging id: '%s', repo: '%s', tag: '%s'" %
                     (image.image_id, image.name, tag))

            if self.dc is not None:
                self.dc.tag(image.image_id, image.name, tag=tag)

    def _fetch_image(self, image):

        LOG.info("Attempting to fetch docker image: %s" % image.raw_name)

        if self.dc is not None:
            try:
                for stat_json in self.dc.pull(image.raw_name,
                                              stream=True):

                    stat_d = json.loads(stat_json)

                    # pp = pprint.PrettyPrinter(indent=4)
                    # pp.pprint(stat_d)

                    if 'stream' in stat_d:
                        for stat_l in stat_d['stream'].split('\n'):
                            LOG.debug(stat_l)

                    if 'status' in stat_d:
                        for stat_l in stat_d['status'].split('\n'):
                            noisy = ["Extracting", "Downloading", "Waiting",
                                     "Download complete", "Pulling fs layer",
                                     "Pull complete", "Verifying Checksum"]
                            if stat_l in noisy:
                                LOG.debug(stat_l)
                            else:
                                LOG.info(stat_l)

                    if 'error' in stat_d:
                        LOG.error(stat_d['error'])
                        sys.exit(1)

            except:
                LOG.exception("Error pulling docker image")
                image.status
                return False

            # obtain the image_id by inspecting the pulled image. Seems unusual
            # that the Docker API `pull` method doesn't provide it when the
            # `build` method does
            img_inspection = self.dc.inspect_image(image.raw_name)
            image.image_id = img_inspection['Id']

            LOG.debug("Fetched %s, id: %s" %
                      (image.raw_name, image.image_id))

            self.tag_image(image)
            image.status = DI_EXISTS
            return True

    def _build_image(self, image):

        LOG.info("Building docker image for %s" % image.raw_name)

        if self.dc is not None:

            build_tag = "%s:%s" % (image.name, image.tags[0])

            buildargs = image.buildargs()
            context_tar = image.context_tarball()
            dockerfile = image.dockerfile_rel_path()

            for key, val in buildargs.iteritems():
                LOG.info("Buildarg - %s : %s" % (key, val))

            time_now = datetime.datetime.utcnow()
            if(args.build_log_dir):
                bl_name = "%s_%s" % (time_now.strftime("%Y%m%dT%H%M%SZ"),
                                     re.sub(r'\W', '_', image.name))
                bl_path = os.path.join(args.build_log_dir, bl_name)

                LOG.info("Build log: %s" % bl_path)
                bl_fh = open(bl_path, 'w+', 0)  # 0 = unbuffered writes
            else:
                bl_fh = None

            try:
                LOG.info("Building %s with docker" % image)

                for stat_d in self.dc.build(tag=build_tag,
                                            buildargs=buildargs,
                                            custom_context=True,
                                            fileobj=context_tar,
                                            dockerfile=dockerfile,
                                            rm=True,
                                            forcerm=True,
                                            pull=False,
                                            stream=True,
                                            decode=True):

                    # pp = pprint.PrettyPrinter(indent=4)
                    # pp.pprint(stat_d)

                    if 'stream' in stat_d:

                        if bl_fh:
                            bl_fh.write(stat_d['stream'].encode('utf-8'))

                        for stat_l in stat_d['stream'].split('\n'):
                            if(stat_l):
                                LOG.debug(stat_l)
                        if stat_d['stream'].startswith("Successfully built "):
                            image_id = stat_d['stream'].split(' ')[2]
                            image.image_id = image_id.strip()
                            LOG.info("Image ID: %s" % image_id)

                    if 'status' in stat_d:
                        for stat_l in stat_d['status'].split('\n'):
                            if(stat_l):
                                LOG.info(stat_l)

                    if 'error' in stat_d:
                        LOG.error(stat_d['error'])
                        sys.exit(1)

            except:
                LOG.exception("Error building docker image")
                return

            finally:
                if(bl_fh):
                    bl_fh.close()

            LOG.info("Built Image: %s, id: %s" %
                     (image.name, image.image_id))

            self.tag_image(image)
            image.status = DI_EXISTS


if __name__ == "__main__":
    parse_args()
    load_config()

    # only include docker module if not a dry run
    if not args.dry_run:
        try:
            import docker
        except ImportError:
            LOG.error("Unable to load python docker module (-d ?)")
            sys.exit(1)

    rm = RepoManifest()
    db = DockerBuilder(rm)
