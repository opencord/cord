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
import pprint
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
    """ split a docker image name in the format name:tag into components """

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

    def path_clean(self, test_path, branch=None):
        """ Is working tree on branch and no untracked files in path? """
        global conf

        if not branch:
            branch = conf['branch']

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

        # Find the remote URL for these repos
        remote = self.manifest_xml.find('remote')
        self.remote = remote.attrib['review']

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

    def get_repo(self, repo_name):
        return self.repos[repo_name]


class DockerImage():

    def __init__(self, name, repo_name=None, repo_d=None, path=".",
                 context=".", dockerfile='Dockerfile', labels={},
                 tags=[], image_id=None, ):

        # These should all be set
        self.repo_name = repo_name
        self.repo_d = repo_d
        self.path = path
        self.context = context
        self.dockerfile = dockerfile
        self.labels = labels
        self.tags = tags
        self.parent_name = None  # set by _find_parent_name()
        self.parent = None  # pointer to parent DockerImage object
        self.children = []   # list of child objects

        LOG.debug("New DockerImage object from name: %s" % name)

        # name as provided on creation
        self.raw_name = name

        # split name:tag if given in combined format
        (image_name, image_tag) = split_name(name)
        if image_tag:  # has tag
            self.name = image_name
            tags.append(image_tag)
        else:  # no tag
            self.name = image_name

        # split names from tag list
        for tag in tags:
            thistag = ""
            (tag_name, tag_tag) = split_name(tag)
            if tag_tag:  # has name, split off
                thistag = tag_tag
            else:  # just a bare tag
                thistag = tag_name

            if thistag not in tags:  # don't duplicate tags
                tags.append(thistag)

        self._find_parent_name()

    def __str__(self):
        return self.name

    def same_labels(self, other):
        """ Comparison of containers based on label-schema.org labels """

        comparable_labels = [
                "org.label-schema.name",
                "org.label-schema.vcs-url",
                "org.label-schema.vcs-ref",
                ]

        for cl in comparable_labels:
            if cl in self.labels \
                 and cl in other.labels \
                 and self.labels[cl] != other.lables[cl]:
                pass
            else:
                return False

        return True

    def same_name(self, other_name):
        """ compare image name (possibly with tag) against image name/tag """

        (o_name, o_tag) = split_name(other_name)

        if o_tag is None and self.name == o_name:
            return True
        elif self.name == o_name and o_tag in self.tags:
            return True

        return False

    def create_labels(self):
        """ Create label-schema.org labels to be applied to images """

        if self.buildable():
            # determine cleanliness of parents and build context
            if self.repo_d.clean and self._context_clean():
                clean = True
            else:
                clean = False

            self.labels['org.label-schema.name'] = self.name
            self.labels['org.label-schema.version'] = "1.0"

            # org.label-schema.build-date
            time_now = datetime.datetime.utcnow()
            build_date = time_now.strftime("%Y-%m-%dT%H:%M:%SZ")
            self.labels['org.label-schema.build-date'] = build_date

            # git related labels
            self.labels['org.label-schema.vcs-url'] = self.repo_d.git_url

            if clean:
                self.labels['org.label-schema.version'] = conf['branch']
                self.labels['org.label-schema.vcs-ref'] = \
                    self.repo_d.head_commit
                self.labels['org.opencord.vcs-commit-date'] = \
                    self.repo_d.head_commit_t
            else:
                self.labels['org.label-schema.version'] = "dirty"

    def _find_parent_name(self):
        """ set self.parent to name of parent image on Dockerfile FROM line """

        if self.buildable():
            # read contents of Dockerfile into df
            with open(self.dockerfile_abspath()) as dfh:
                df = dfh.read()

            # find FROM line to determine image parent
            frompatt = re.compile(r'^FROM\s+(.*)$', re.MULTILINE)
            fromline = re.search(frompatt, df)

            self.parent_name = fromline.group(1)  # may have tag

    def _context_clean(self):
        """ determine if build context is clean """
        if self.buildable():
            context_path = os.path.normpath(
                                os.path.join(self.path, self.context))
            clean = self.repo_d.path_clean(context_path)
            LOG.debug("  context is clean?: %s", clean)
            return clean

        return True  # unbuildable images are clean

    def buildable(self):
        """ is this image have a repo to be built from """
        if self.repo_name:  # has a git repo to be built from
            return True
        return False

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

            # see docker-py source for context
            exclusion_list = ['.git']
            for path in sorted(
                    docker.utils.exclude_paths(context_path, exclusion_list)):
                t.add(os.path.join(context_path, path),
                      arcname=path,
                      recursive=False)

            # t.list()  # prints all files in tarball
            t.close()
            t_fh.seek(0)
            return t_fh

        else:
            return None

    def buildargs(self):
        """
        returns array of labels in docker buildargs compliant format
        """
        ba_a = {}

        for lbl in self.labels:
            ba_re = re.compile(r'\W')  # non alpha/num/_ chars
            ba_lbl = ba_re.sub('_', lbl)
            ba_a[ba_lbl] = self.labels[lbl]

        return ba_a


class DockerBuilder():

    def __init__(self, repo_manifest):

        self.rm = repo_manifest
        self.dc = None  # Docker Client object

        self.images = []
        self.preexisting = []

        # create dict of images, setting defaults
        for image in conf['repo_docker_images']:

            repo_d = self.rm.get_repo(image['repo'])

            img_o = DockerImage(image['name'], image['repo'], repo_d,
                                image.get('path', '.'),
                                image.get('context', '.'),
                                image.get('dockerfile', 'Dockerfile'))

            self.images.append(img_o)

        if not args.dry_run:
            self._docker_connect()

        self._get_preexisting()
        self.create_dependency()

        if args.graph is not None:
            self.dependency_graph(args.graph)

        LOG.info("Preexisting Images: %s" % ", ".join(self.preexisting))

        # make lists of images to fetch/build
        f_a = []
        b_a = []

        for image in self.images:
            if image.parent:
                b_a.append(image.name)
            else:
                f_a.append(image.name)

        LOG.info("Images to fetch: %s" % ", ".join(f_a))
        LOG.info("Images to build: %s" % ", ".join(b_a))

        self.process_images()

    def _docker_connect(self):
        """ Connect to docker daemon """

        self.dc = docker.from_env()

        if self.dc.ping():
            LOG.debug("Docker server is responding")
        else:
            LOG.error("Unable to ping docker server")
            sys.exit(1)

    def _get_preexisting(self):
        """ find images that already exist in Docker """

        if self.dc:
            LOG.info("Evaluating images that preexist in Docker")

            # get list of images from docker
            pe_imgs = self.dc.images()

            for pe_img in pe_imgs:
                raw_tags = pe_img['RepoTags']

                LOG.info(" Preexisting Image - ID: %s, tags: %s" %
                         (pe_img['Id'], ",".join(raw_tags)))

                # Print label list here?

                # ignoring all <none>:<none> images, reasonable?
                if "<none>:<none>" not in raw_tags:
                    img_o = DockerImage(raw_tags[0], tags=raw_tags,
                                        labels=pe_img["Labels"],
                                        image_id=pe_img['Id'], )

                    self.preexisting.append(img_o)

    def find_image(self, image_name):
        """ return image object matching name """
        LOG.debug("attempting to find image for: %s" % image_name)

        for image in self.images:
            if image.same_name(image_name):
                return image
        return None

    def find_preexisting(self, image_name):
        """ return preexisting image object matching name """
        LOG.debug("attempting to find preexisting image for: %s" % image_name)

        for image in self.preexisting:
            if image.same_name(image_name):
                return image
        return None

    def _image_clean(self, image_name):
        """ determine if an image and it's parents are clean """
        image = self.find_image(image_name)

        if not image.parent:
            # images with no parent are external/clean
            return True
        else:
            # clean if self and parent is recursively clean
            if image.clean and self._image_clean(image.parent_name):
                return True

        return False

    def create_dependency(self):
        """ set parent/child links for images """

        # list of all parent image names, with dupes
        parents_with_dupes = [img.parent_name for img in self.images]

        # remove duplicates
        parents = list(set(parents_with_dupes))

        LOG.info("All parents list: %s" % ", ".join(parents))

        # list of "external parents", ones not built internally
        external_parents = []

        for parent_name in parents:

            LOG.info("Evaluating parent image: %s" % parent_name)

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

            LOG.info("Associating image: %s" % image.name)

            parent = self.find_image(image.parent_name)
            image.parent = parent

            if parent is not None:
                LOG.info(" internal image '%s' is parent of '%s'" %
                         (parent.name, image.name))
                parent.children.append(image)

            else:
                LOG.info(" external image '%s' is parent of '%s'" %
                         (image.parent_name, image.name))

        image.create_labels()  # requires parent link before labeling

    def dependency_graph(self, graph_fn):
        """ save a DOT dependency graph to a file """

        LOG.info("Creating a DOT dependency graph to: %s" % graph_fn)

        try:
            import graphviz
        except ImportError:
            LOG.error('graphviz pip module not found')
            raise

        dg = graphviz.Digraph(comment='Image Dependency Graph')

        # Use raw names, so they match with what's in Dockerfiles
        # delete colons as python graphviz module quotes them weird
        for image in self.images:
            name_g = image.raw_name.replace(':', ' ')
            dg.node(name_g)

            if image.parent is not None:
                name_p = image.parent.raw_name.replace(':', ' ')
                dg.edge(name_p, name_g)

        with open(graph_fn, 'w') as g_fh:
            g_fh.write(dg.source)

    def process_images(self):

        # check if preexisting images are up to date

        # remove all images that don't need to be built

        # remove unnecessary parents

        f_a = filter(lambda img: img.parent is None, self.images)
        f_sort = sorted(f_a, key=(lambda img: len(img.children)), reverse=True)
        LOG.info("Fetch order: %s" % ", ".join(f.name for f in f_sort))

        # fetch needed upstream images, ordered by len(children)

        p_a = filter(lambda img: img.parent is not None, self.images)
        p_sort = sorted(p_a, key=(lambda img: len(img.children)), reverse=True)
        LOG.info("Parents build order: %s" % ", ".join(p.name for p in p_sort))

        # If can't fetch, build (or fail if not buildable)

        # build images that need to be built, ordered by len(children)

    def _get_buildable(self):

        # yield the first image whose parent is present
        for to_build in self.build_d.keys():
            if self.images[to_build]['parent'] in self.present_d.keys():
                return to_build

        # die if none are buildable
        LOG.error("No buildable images in set: %s" %
                  ", ".join(self.build_d.keys()))
        sys.exit(1)

    def _fetch_image(self, image_name, tag):

        LOG.info("Attempting to fetch docker image for %s, tag: %s" %
                 (image_name, tag))

        # pull "latest" if no tag specified, as in CLI
        if tag:
            pulltag = tag
        else:
            pulltag = "latest"

        image_id = ''

        if self.dc:
            try:

                for stat_json in self.dc.pull(image_name,
                                              stream=True,
                                              tag=pulltag):

                    stat_d = json.loads(stat_json)

                    if 'stream' in stat_d:
                        for stat_l in stat_d['stream'].split('\n'):
                            LOG.debug(stat_l)

                    if 'status' in stat_d:
                        if stat_d['status'].startswith('Pull Complete'):
                            image_id = stat_d['id']
                            LOG.info("Image ID: %s" % image_id)

                        for stat_l in stat_d['status'].split('\n'):
                            noisy = ["Extracting", "Downloading",
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

            LOG.debug("Fetched %s" % (image_name))

        if tag:
            tagged_image_name = "%s:%s" % (image_name, pulltag)
        else:
            tagged_image_name = image_name

        self.present_d[tagged_image_name] = {
            "present": True,
            "image_id": image_id,
            }

    def _build_image(self, image):

        LOG.info("Building docker image for %s" % image)

        if self.dc:

            build_tag = "%s:%s" % (image.name, conf['docker_build_tag'])

            buildargs = image.buildargs()
            context_tar = image.context_tar()
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

                    pp = pprint.PrettyPrinter(indent=4)
                    pp.pprint(stat_d)

                    if 'stream' in stat_d:

                        if bl_fh:
                            bl_fh.write(stat_d['stream'].encode('utf-8'))

                        for stat_l in stat_d['stream'].split('\n'):
                            if(stat_l):
                                LOG.debug(stat_l)
                        if stat_d['stream'].startswith("Successfully built "):
                            image_id = stat_d['stream'].split(' ')[2]
                            image.image_id = image_id
                            LOG.info("Image id: %s" % image_id)

                    if 'status' in stat_d:
                        for stat_l in stat_d['status'].split('\n'):
                            if(stat_l):
                                LOG.info(stat_l)

                    if 'error' in stat_d:
                        LOG.error(stat_d['error'])
                        sys.exit(1)

            except:
                LOG.exception("Error building docker image")
            else:

                # apply additional tags
                for tag in image.tags:
                    extra_tag = "%s:%s" % (image.name, tag)
                    repository = "localhost"

                    if(extra_tag != build_tag):
                        LOG.info("Tagging id: '%s', repo: '%s', tag: '%s'" %
                                 (image_id, repository, extra_tag))
                        self.dc.tag(image_id, repository, tag=extra_tag)

                LOG.debug("Built %s" % (image.name))

            finally:
                if(bl_fh):
                    bl_fh.close()


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
