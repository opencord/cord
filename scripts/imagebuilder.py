#!/usr/bin/env python

# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# imagebuilder.py
# rebuilds/fetches docker container images per their git status in repo
# in addition to docker, needs `sudo apt-get install python-git`

import argparse
import datetime
import git
import json
import logging
import os
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
global build_tag
global buildable_images
global pull_only_images


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

    parser.add_argument('-c', '--container_list', default='docker_images.yml',
                        type=argparse.FileType('r'),
                        help="YAML Config and master container list")

    # -f is optional, so using type=argparse.FileType is problematic
    parser.add_argument('-f', '--filter_images', default=None, action='store',
                        help="YAML file restricting images to build/fetch")

    parser.add_argument('-a', '--actions_taken', default=None,
                        help="Save a YAML file with actions taken during run")

    group = parser.add_mutually_exclusive_group()
    group.add_argument('-b', '--build', action="store_true", default=False,
                       help="Build (don't fetch) all internal images, nocache")
    group.add_argument('-p', '--pull', action="store_true", default=False,
                       help="Only pull containers, fail if build required")

    parser.add_argument('-d', '--dry_run', action="store_true",
                        help="Don't build/fetch anything")

    parser.add_argument('-g', '--graph', default=None,
                        help="Filename for DOT graph file of image dependency")

    parser.add_argument('-l', '--build_log_dir', action="store",
                        help="Log build output to this dir if set")

    parser.add_argument('-r', '--repo_root', default="..", action="store",
                        help="Repo root directory")

    parser.add_argument('-t', '--build_tag', default=None, action="store",
                        help="tag all images built/pulled using this tag")

    parser.add_argument('-v', '--verbosity', action='count', default=1,
                        help="Repeat to increase log level")

    args = parser.parse_args()

    if args.verbosity > 1:
        LOG.setLevel(logging.DEBUG)
    else:
        LOG.setLevel(logging.INFO)


def load_config():
    global args
    global conf
    global buildable_images
    global pull_only_images
    global build_tag

    try:
        cl_abs = os.path.abspath(args.container_list.name)
        LOG.info("Master container list file: %s" % cl_abs)

        conf = yaml.safe_load(args.container_list)
    except yaml.YAMLError:
        LOG.exception("Problem loading container list file")
        sys.exit(1)

    if args.build_tag:
        build_tag = args.build_tag
    else:
        build_tag = conf['docker_build_tag']

    if args.filter_images is None:
        buildable_images = conf['buildable_images']
        pull_only_images = conf['pull_only_images']
    else:
        fi_abs = os.path.abspath(args.filter_images)

        LOG.info("Filtering image list per 'docker_image_whitelist' in: %s" %
                 fi_abs)
        try:
            fi_fh = open(fi_abs, 'r')
            filter_list = yaml.safe_load(fi_fh)
            fi_fh.close()

            if 'docker_image_whitelist' not in filter_list:
                LOG.error("No 'docker_image_whitelist' defined in: %s" %
                          fi_abs)
                sys.exit(1)

            # fail if filter list specifies tags
            for f_i in filter_list['docker_image_whitelist']:
                (name, tag) = split_name(f_i)
                if tag:
                    LOG.error("filter list may not be tagged")
                    sys.exit(1)

            buildable_images = [img for img in conf['buildable_images']
                                if split_name(img['name'])[0]
                                in filter_list['docker_image_whitelist']]

            pull_only_images = [img for img in conf['pull_only_images']
                                if split_name(img)[0]
                                in filter_list['docker_image_whitelist']]

        except:
            LOG.exception("Problem with filter list file")
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
DI_ERROR = 'error'  # build or other fatal failure


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

        self.parent_names = []  # names of parents from _find_parent_names()
        self.parents = []  # list of parent DockerImage object
        self.children = []   # list of child DockerImage objects

        # split name:tag if given in combined format
        (image_name, image_tag) = split_name(name)
        if image_tag:  # has tag
            self.name = image_name
            self.tags.append(image_tag)
        else:  # no tag
            self.name = image_name

        # Add the build tag if exists
        if build_tag not in self.tags:
            self.tags.append(build_tag)

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
        self._find_parent_names()

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

            LOG.debug(" Build Context Cleanliness - "
                      "repo: %s, context: %s, components: %s" %
                      (repo_clean, context_clean, components_clean))

            if context_clean and repo_clean and components_clean:
                return True
            else:
                return False

        return True  # unbuildable images are clean

    def parents_clean(self):
        """ if all parents are clean """

        if self.buildable():
            if not self.clean:
                return False
            else:
                for parent in self.parents:
                    if not parent.parents_clean():
                        return False
                else:
                    return True

        return True  # unbuildable images are clean

    def compare_labels(self, other_labels):
        """ Returns True if image label-schema.org labels match dict """

        comparable_labels_re = [
                r".*name$",
                r".*vcs-url$",
                r".*vcs-ref$",
                r".*version$",
                ]

        for clr in comparable_labels_re:  # loop on all comparable labels
            for label in self.labels:  # loop on all labels
                if re.match(clr, label) is not None:   # if label matches re
                    # and label exists in other, and values are same
                    if label in other_labels and \
                            self.labels[label] == other_labels[label]:
                        pass  # continue through loop
                    else:
                        LOG.info("Non-matching label: %s" % label)
                        return False  # False when first difference found

        LOG.debug(" All labels matched")
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

        LOG.debug(" Generating child labels from parent: %s" % self.name)

        # only create labels when they haven't already been created
        if repo_list is None:
            repo_list = []

        LOG.debug(" Already labeled with: %s" % ", ".join(repo_list))

        cl = {}

        if self.buildable() and self.repo_name not in repo_list:

            LOG.debug("  Adding parent labels from repo: %s" % self.repo_name)

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
        if self.parents is not None:
            for parent in self.parents:
                cl.update(parent.child_labels(repo_list))

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
            if self.parents_clean():
                if build_tag not in self.tags:
                    self.tags.append(build_tag)

                commit_tag = self.repo_d.head_commit
                if commit_tag not in self.tags:
                    self.tags.append(commit_tag)

                    # pulling is done via raw_name, set tag to commit
                    self.raw_name = "%s:%s" % (self.name, commit_tag)

            LOG.debug("All tags: %s" % ", ".join(self.tags))

    def _find_parent_names(self):
        """ set self.parent_names using Dockerfile FROM lines """

        if self.buildable():
            # read contents of Dockerfile into df
            with open(self.dockerfile_abspath()) as dfh:
                dfl = dfh.readlines()

            parent_names = []
            frompatt = re.compile(r'^FROM\s+([\w/_:.-]+)', re.MULTILINE)

            for line in dfl:
                fromline = re.search(frompatt, line)
                if fromline:
                    parent_names.append(fromline.group(1))

            self.parent_names = parent_names  # may have tag

            LOG.debug(" Parents: %s" % ", ".join(self.parent_names))

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

            # exclude git directories anywhere in the context
            exclusion_list = ['**/.git']

            docker_ignore = os.path.join(context_path, '.dockerignore')
            if os.path.exists(docker_ignore):
                for line in open(docker_ignore).readlines():
                    # slightly out of spec, we allow whitespace before comments
                    # https://docs.docker.com/engine/reference/builder/#dockerignore-file
                    if line.strip()[0] is not '#':
                        exclusion_list.append(line.strip().rstrip('\/'))

            LOG.debug("Exclusion list: %s" % exclusion_list)

            # see docker-py source for context
            for path in sorted(
                    DockerUtils.exclude_paths(context_path, exclusion_list)):
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
                          DockerUtils.exclude_paths(c_ctx_p, exclusion_list)):

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

        global buildable_images
        global pull_only_images

        self.rm = repo_manifest
        self.dc = None  # Docker Client object

        self.images = []

        # arrays of images, used for write_actions
        self.preexisting = []
        self.obsolete = []
        self.pulled = []
        self.failed_pull = []
        self.obsolete_pull = []
        self.built = []
        self.failed_build = []

        # create dict of images, setting defaults
        for image in buildable_images:

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
            full_name = "%s:%s" % (image['name'], build_tag)

            img_o = DockerImage(full_name, image['repo'], repo_d,
                                image.get('path', '.'),
                                image.get('context', '.'),
                                image.get('dockerfile', 'Dockerfile'),
                                components=components)

            self.images.append(img_o)

        # add misc images
        for misc_image in pull_only_images:
            img_o = DockerImage(misc_image)
            self.images.append(img_o)

        if not args.dry_run:
            self._docker_connect()

        self.create_dependency()

        if not args.build:  # if forcing build, don't use preexisting
            self.find_preexisting()

        if args.graph is not None:
            self.dependency_graph(args.graph)

        self.process_images()

        if args.actions_taken is not None:
            self.write_actions_file(args.actions_taken)

    def _docker_connect(self):
        """ Connect to docker daemon """

        try:
            self.dc = DockerClient()
        except requests.ConnectionError:
            LOG.debug("Docker connection not available")
            sys.exit(1)

        if self.dc.ping():
            LOG.debug("Docker server is responding")
        else:
            LOG.error("Unable to ping docker server")
            sys.exit(1)

    def find_preexisting(self):
        """ find images that already exist in Docker and mark """

        if self.dc:
            LOG.debug("Evaluating already built/fetched Docker images")

            # get list of images from docker
            pe_images = self.dc.images()

            for pe_image in pe_images:
                raw_tags = pe_image['RepoTags']

                if raw_tags:
                    LOG.info("Preexisting Image - ID: %s, tags: %s" %
                             (pe_image['Id'], ",".join(raw_tags)))

                    has_build_tag = False
                    for tag in raw_tags:
                        if build_tag in tag:
                            LOG.debug(" image has build_tag: %s" % build_tag)
                            has_build_tag = True

                    base_name = raw_tags[0].split(":")[0]
                    image = self.find_image(base_name)

                    # only evaluate images in the list of desired images
                    if image is not None:

                        good_labels = image.compare_labels(pe_image['Labels'])

                        if good_labels:
                            if has_build_tag:
                                LOG.info(" Image %s has up-to-date labels and"
                                         " build_tag" % pe_image['Id'])
                            else:
                                LOG.info(" Image %s has up-to-date labels but"
                                         " missing build_tag. Tagging image"
                                         " with build_tag: %s" %
                                         (pe_image['Id'], build_tag))

                                self.dc.tag(pe_image['Id'], image.name,
                                            tag=build_tag)

                            self.preexisting.append({
                                    'id': pe_image['Id'],
                                    'tags': raw_tags,
                                    'base': image.name.split(":")[0],
                                })

                            image.image_id = pe_image['Id']
                            image.status = DI_EXISTS

                        else:  # doesn't have good labels
                            if has_build_tag:
                                LOG.info(" Image %s has obsolete labels and"
                                         " build_tag, remove" % pe_image['Id'])

                                # remove build_tag from image
                                name_bt = "%s:%s" % (base_name, build_tag)
                                self.dc.remove_image(name_bt, False, True)

                            else:
                                LOG.info(" Image %s has obsolete labels, lacks"
                                         " build_tag, ignore" % pe_image['Id'])

                            self.obsolete.append({
                                    'id': pe_image['Id'],
                                    'tags': raw_tags,
                                })

    def find_image(self, image_name):
        """ return image object matching name """
        LOG.debug(" attempting to find image for: %s" % image_name)

        for image in self.images:
            if image.same_name(image_name):
                LOG.debug(" found a match: %s" % image.raw_name)
                return image
        return None

    def create_dependency(self):
        """ set parent/child links for images """

        # List of lists of parents images. Done in two steps for clarity
        lol_of_parents = [img.parent_names for img in self.images
                          if img.parent_names is not []]

        # flat list of all parent image names, with dupes
        parents_with_dupes = [parent for parent_sublist in lol_of_parents
                              for parent in parent_sublist]

        # remove duplicates
        parents = list(set(parents_with_dupes))

        LOG.info("All parent images: %s" % ", ".join(parents))

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
                    LOG.debug(" Internal parent: %s" % image.name)
                    break

            if not internal_parent:  # parent is external
                LOG.debug(" External parent: %s" % parent_name)
                external_parents.append(parent_name)

        # add unique external parents to image list
        for e_p_name in set(external_parents):
            LOG.debug(" Creating external parent image object: %s" % e_p_name)
            img_o = DockerImage(e_p_name)
            self.images.append(img_o)

        # now that all images (including parents) are in list, associate them
        for image in filter(lambda img: img.parent_names is not [],
                            self.images):

            LOG.debug("Associating image: %s" % image.name)

            for parent_name in image.parent_names:

                parent = self.find_image(parent_name)
                image.parents.append(parent)

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
            if image.parents is not None:
                for parent in image.parents:
                    LOG.debug("Adding parent labels from %s to child %s" %
                              (parent.name, image.name))

                    # don't create component labels for same repo as image
                    repo_list = [image.repo_name]
                    image.labels.update(parent.child_labels(repo_list))

    def dependency_graph(self, graph_fn):
        """ save a DOT dependency graph to a file """

        graph_fn_abs = os.path.abspath(graph_fn)

        LOG.info("Saving DOT dependency graph to: %s" % graph_fn_abs)

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

            if image.parents is not None:
                for parent in image.parents:
                    name_p = parent.raw_name.replace(':', '\n')
                    dg.edge(name_p, name_g)

            if image.components is not None:
                for component in image.components:
                    name_c = "component - %s" % component['repo_name']
                    if name_c not in component_nodes:
                        dg.node(name_c)
                        component_nodes.append(name_c)
                    dg.edge(name_c, name_g, "", {'style': 'dashed'})

        with open(graph_fn_abs, 'w') as g_fh:
            g_fh.write(dg.source)

    def write_actions_file(self, actions_fn):

        actions_fn_abs = os.path.abspath(actions_fn)

        LOG.info("Saving actions as YAML to: %s" % actions_fn_abs)

        actions = {
                "ib_pulled": self.pulled,
                "ib_built": self.built,
                "ib_preexisting_images": self.preexisting,
                "ib_obsolete_images": self.obsolete,
                "ib_failed_pull": self.failed_pull,
                "ib_obsolete_pull": self.obsolete_pull,
                "ib_failed_build": self.failed_build,
                }

        with open(actions_fn_abs, 'w') as a_fh:
            yaml.safe_dump(actions, a_fh)
            LOG.debug(yaml.safe_dump(actions))

    def process_images(self):

        """ determine whether to build/fetch images """
        # upstream images (have no parents), must be fetched
        must_fetch_a = filter(lambda img: not img.parents, self.images)

        for image in must_fetch_a:
            if image.status is not DI_EXISTS:
                image.status = DI_FETCH

        # images that can be built or fetched (have parents)
        b_or_f_a = filter(lambda img: img.parents, self.images)

        for image in b_or_f_a:
            if not image.parents_clean() or args.build:
                # must be built if not clean
                image.status = DI_BUILD
            elif image.status is not DI_EXISTS:
                # try to fetch if clean and doesn't exist
                image.status = DI_FETCH
            # otherwise, image is clean and exists (image.status == DI_EXISTS)

        c_and_e_a = filter(lambda img: img.status is DI_EXISTS, self.images)
        LOG.info("Preexisting and clean images: %s" %
                 ", ".join(c.name for c in c_and_e_a))

        upstream_a = filter(lambda img: (img.status is DI_FETCH and
                                         not img.parents), self.images)
        LOG.info("Upstream images that must be fetched: %s" %
                 ", ".join(u.raw_name for u in upstream_a))

        fetch_a = filter(lambda img: (img.status is DI_FETCH and
                                      img.parents), self.images)
        LOG.info("Clean, buildable images to attempt to fetch: %s" %
                 ", ".join(f.raw_name for f in fetch_a))

        build_a = filter(lambda img: img.status is DI_BUILD, self.images)
        LOG.info("Buildable images, due to unclean context or parents: %s" %
                 ", ".join(b.raw_name for b in build_a))

        # OK to fetch upstream in any case as they should reduce number of
        # layers pulled/built later

        for image in upstream_a:
            if not self._fetch_image(image):
                LOG.error("Unable to fetch upstream image: %s" %
                          image.raw_name)
                sys.exit(1)

        # fetch if not forcing the build of all images
        if not args.build:
            fetch_sort = sorted(fetch_a, key=(lambda img: len(img.children)),
                                reverse=True)

            for image in fetch_sort:
                if not self._fetch_image(image):
                    # if didn't fetch, build
                    image.status = DI_BUILD

        while True:
            buildable_images = self.get_buildable()

            if buildable_images and args.pull:
                LOG.error("Images must be built, but --pull is specified")
                exit(1)

            if buildable_images:
                for image in buildable_images:
                    self._build_image(image)
            else:
                LOG.debug("No more images to build, ending build loop")
                break

    def get_buildable(self):
        """ Returns list of images that can be built"""

        buildable = []

        for image in filter(lambda img: img.status is DI_BUILD, self.images):
            for parent in image.parents:
                if parent.status is DI_EXISTS:
                    if image not in buildable:  # build once if two parents
                        buildable.append(image)

        LOG.debug("Buildable images: %s" %
                  ', '.join(image.name for image in buildable))

        return buildable

    def tag_image(self, image):
        """ Applies tags to an image """

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

                    # sometimes Docker's JSON is dirty, per:
                    # https://github.com/docker/docker-py/pull/1081/
                    stat_s = stat_json.strip()
                    stat_list = stat_s.split("\r\n")

                    for s_j in stat_list:
                        stat_d = json.loads(s_j)

                        if 'stream' in stat_d:
                            for stat_l in stat_d['stream'].split('\n'):
                                LOG.debug(stat_l)

                        if 'status' in stat_d:
                            for stat_l in stat_d['status'].split('\n'):
                                noisy = ["Extracting", "Downloading",
                                         "Waiting", "Download complete",
                                         "Pulling fs layer", "Pull complete",
                                         "Verifying Checksum",
                                         "Already exists"]
                                if stat_l in noisy:
                                    LOG.debug(stat_l)
                                else:
                                    LOG.info(stat_l)

                        if 'error' in stat_d:
                            LOG.error(stat_d['error'])
                            sys.exit(1)

            except (DockerErrors.NotFound, DockerErrors.ImageNotFound) as e:
                LOG.warning("Image could not be pulled: %s , %s" %
                            (e.errno, e.strerror))

                self.failed_pull.append({
                        "tags": [image.raw_name, ],
                    })

                if not image.parents:
                    LOG.error("Pulled image required to build, not available!")
                    sys.exit(1)

                return False

            except:
                LOG.exception("Error pulling docker image")

                self.failed_pull.append({
                        "tags": [image.raw_name, ],
                    })

                return False

            # obtain the image_id by inspecting the pulled image. Seems unusual
            # that the Docker API `pull` method doesn't provide it when the
            # `build` method does
            pulled_image = self.dc.inspect_image(image.raw_name)

            # check to make sure that image that was downloaded has the labels
            # that we expect it to have, otherwise return false, trigger build
            if not image.compare_labels(
                        pulled_image['ContainerConfig']['Labels']):
                LOG.info("Tried fetching image %s, but labels didn't match" %
                         image.raw_name)

                self.obsolete_pull.append({
                        "id": pulled_image['Id'],
                        "tags": pulled_image['RepoTags'],
                    })
                return False

            image.image_id = pulled_image['Id']
            LOG.info("Fetched image %s, id: %s" %
                     (image.raw_name, image.image_id))

            self.pulled.append({
                    "id": pulled_image['Id'],
                    "tags": pulled_image['RepoTags'],
                    "base": image.name.split(":")[0],
                })

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
                LOG.debug("Buildarg - %s : %s" % (key, val))

            bl_path = ""
            start_time = datetime.datetime.utcnow()

            if(args.build_log_dir):
                bl_name = "%s_%s" % (start_time.strftime("%Y%m%dT%H%M%SZ"),
                                     re.sub(r'\W', '_', image.name))
                bl_path = os.path.abspath(
                            os.path.join(args.build_log_dir, bl_name))

                LOG.info("Build log: %s" % bl_path)
                bl_fh = open(bl_path, 'w+', 0)  # 0 = unbuffered writes
            else:
                bl_fh = None

            try:
                LOG.info("Building image: %s" % image)

                for stat_d in self.dc.build(tag=build_tag,
                                            buildargs=buildargs,
                                            nocache=args.build,
                                            custom_context=True,
                                            fileobj=context_tar,
                                            dockerfile=dockerfile,
                                            rm=True,
                                            forcerm=True,
                                            pull=False,
                                            stream=True,
                                            decode=True):

                    if 'stream' in stat_d:

                        if bl_fh:
                            bl_fh.write(stat_d['stream'].encode('utf-8'))

                        for stat_l in stat_d['stream'].split('\n'):
                            if(stat_l):
                                LOG.debug(stat_l)
                        if stat_d['stream'].startswith("Successfully built "):
                            siid = stat_d['stream'].split(' ')[2]
                            short_image_id = siid.strip()
                            LOG.debug("Short Image ID: %s" % short_image_id)

                    if 'status' in stat_d:
                        for stat_l in stat_d['status'].split('\n'):
                            if(stat_l):
                                LOG.info(stat_l)

                    if 'error' in stat_d:
                        LOG.error(stat_d['error'])
                        image.status = DI_ERROR
                        sys.exit(1)

            except:
                LOG.exception("Error building docker image")

                self.failed_build.append({
                        "tags": [build_tag, ],
                    })

                return

            finally:
                if(bl_fh):
                    bl_fh.close()

            # the image ID given by output isn't the full SHA256 id, so find
            # and set it to the full one
            built_image = self.dc.inspect_image(short_image_id)
            image.image_id = built_image['Id']

            end_time = datetime.datetime.utcnow()
            duration = end_time - start_time  # duration is a timedelta

            LOG.info("Built Image: %s, duration: %s, id: %s" %
                     (image.name, duration, image.image_id))

            self.built.append({
                    "id": image.image_id,
                    "tags": [build_tag, ],
                    "push_name": image.raw_name,
                    "build_log": bl_path,
                    "duration": duration.total_seconds(),
                    "base": image.name.split(":")[0],
                })

            self.tag_image(image)
            image.status = DI_EXISTS


if __name__ == "__main__":
    parse_args()
    load_config()

    # only include docker module if not a dry run
    if not args.dry_run:
        try:
            import requests
            from distutils.version import LooseVersion
            from docker import __version__ as docker_version

            # handle the docker-py v1 to v2 API differences
            if LooseVersion(docker_version) >= LooseVersion('2.0.0'):
                from docker import APIClient as DockerClient
            else:
                LOG.error("Unsupported python docker module - "
                          "remove docker-py 1.x, install docker 2.x")
                sys.exit(1)

            from docker import utils as DockerUtils
            from docker import errors as DockerErrors

        except ImportError:
            LOG.error("Unable to load python docker module (dry run?)")
            sys.exit(1)

    rm = RepoManifest()
    db = DockerBuilder(rm)
