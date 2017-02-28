#!/usr/bin/env python

# repoimagebuilder.py
# rebuilds/fetches docker container images per their git status in repo
# in addition to docker, needs `sudo apt-get install python-git`

import argparse
import git
import logging
import os
# import pprint
import string
import sys
import re
import xml.etree.ElementTree as ET
import yaml

global args
global conf


def setup_logging():
    log = logging.getLogger(__name__)
    lh = logging.StreamHandler(sys.stdout)
    lh.setFormatter(logging.Formatter("%(levelname)s:%(message)s"))
    log.addHandler(lh)
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
                       help="Force build all internal containers")

    group.add_argument('-f', '--fetch_force',
                       action="store_true",
                       help="Only fetch containers, fail if build required")

    parser.add_argument('-d', '--dry_run',
                        action="store_true",
                        help="Don't build/fetch anything")

    parser.add_argument('-p', '--push',
                        action="store_true",
                        help="push to docker registry")

    parser.add_argument('-r', '--repo_root',
                        default="..",
                        action="store",
                        help="repo root directory")

    parser.add_argument('-v', '--verbosity',
                        action='count', default=1,
                        help="Repeat to increase log level")

    args = parser.parse_args()

    if args.verbosity == 1:
        LOG.setLevel(logging.INFO)
    elif args.verbosity > 1:
        LOG.setLevel(logging.DEBUG)


def load_config():
    global args
    global conf

    try:
        conf = yaml.safe_load(args.container_list)
    except yaml.YAMLError as e:
        LOG.exception("Problem loading container list file: ", e)
        sys.exit(1)


class RepoParser():

    def __init__(self):
        global args
        global conf

        self.manifest_xml = {}
        self.repos = {}

        self.manifest_file = os.path.join(args.repo_root, ".repo/manifest.xml")

        try:
            tree = ET.parse(self.manifest_file)
            self.manifest_xml = tree.getroot()
        except Exception as e:
            LOG.exception("Error loading repo manifest:", e)
            sys.exit(1)

        for project in self.manifest_xml.iter('project'):
            repo_name = project.attrib['name']
            rel_path = project.attrib['path']
            full_path = os.path.abspath(os.path.join(args.repo_root,
                                        project.attrib['path']))

            if os.path.isdir(full_path):
                self.repos[repo_name] = {
                    "full_path": full_path,
                    "rel_path": rel_path,
                    }
            else:
                LOG.debug("Repo in manifest but not checked out: %s" %
                          repo_name)

        for repo_name in self.repos.keys():
            try:
                LOG.debug("Repo - %s, path: %s" %
                          (repo_name, self.repos[repo_name]["full_path"]))

                c_repo = git.Repo(self.repos[repo_name]["full_path"])

                self.repos[repo_name]['repo'] = c_repo
                LOG.debug(" head commit: %s" % c_repo.head.commit)

                clean = not c_repo.is_dirty(untracked_files=True)
                LOG.debug(" clean: %s" % clean)
                self.repos[repo_name]['clean'] = clean

                # list of untracked files (expensive operation)
                untracked = c_repo.untracked_files
                self.repos[repo_name]['untracked'] = untracked
                for u_file in untracked:
                    LOG.debug("  Untracked: %s" % u_file)

            except Exception as e:
                LOG.exception("Error with git repo")
                sys.exit(1)

    def path_clean(self, repo_name, path):

        clean = True
        repo = self.repos[repo_name]['repo']

        # diff between branch head and working tree (None)
        branch_head = repo.commit(conf['branch'])
        diff = branch_head.diff(None, paths=path)

        LOG.debug("  build context path: %s" % path)

        if diff:
            clean = False

        for diff_obj in diff:
            LOG.debug("  Change: %s" % diff_obj)

        # null path for compare using .startswith()
        if path == ".":
            path = ""

        for u_file in self.repos[repo_name]['untracked']:
            if u_file.startswith(path):
                LOG.debug("  Untracked file in context: %s" % u_file)
                clean = False

        return clean

    def get_repo(self, repo_name):
        return self.repos[repo_name]


class DockerImageList():

    def __init__(self, repo_parser):

        self.rp = repo_parser
        self.dc = None  # docker client
        self.images = {}
        self.fetch_d = {}
        self.build_d = {}
        self.present_d = {}

        # create dict of images, setting defaults
        for image in conf['repo_docker_images']:

            repo_d = self.rp.get_repo(image['repo'])
            repo_path = repo_d['full_path']
            repo_commit = repo_d['repo'].head.commit

            self.images[image['name']] = {
                    "repo": image['repo'],
                    "repo_path": repo_path,
                    "commit_hash":  repo_commit,
                    "path": image.get('path', '.'),
                    "context": image.get('context', '.'),
                    "dockerfile": image.get('dockerfile', 'Dockerfile'),
                }

        self._evaluate_images()

        LOG.info("Images to fetch: %s" % ", ".join(self.fetch_d.keys()))
        LOG.info("Images to build: %s" % ", ".join(self.build_d.keys()))

        if not args.dry_run:
            self._docker_connect()

        self._process_images()

    def _evaluate_images(self):

        for image_name, image_attr in self.images.iteritems():

            LOG.debug("Evaluating image: %s" % image_name)

            # determine if build context is dirty
            self.images[image_name]['clean'] = self._context_clean(image_name)

            # construct path to Dockerfile
            df_path = os.path.join(image_attr['repo_path'],
                                   image_attr['path'],
                                   image_attr['dockerfile'])

            # read contents of Dockerfile into df
            with open(df_path) as dfh:
                df = dfh.read()

            # find FROM line to determine image parent
            frompatt = re.compile(r'^FROM\s+(.*)$', re.MULTILINE)
            fromline = re.search(frompatt, df)

            if fromline:
                parent = fromline.group(1)
                self.images[image_name]["parent"] = parent

                LOG.debug("Parent image of %s is %s" %
                          (image_name, parent))

                if parent in self.images:
                    self.images[image_name]["internal_parent"] = True
                else:
                    self.images[image_name]["internal_parent"] = False

                LOG.debug("Do we create the parent image?: %s" %
                          self.images[image_name]["internal_parent"])

            else:
                LOG.error("Couldn't find a parent image for %s in %s" %
                          (image_name, df_path))
                sys.exit(1)

        # now that we know parents/cleanliness of images,
        # decide whether to build or fetch them
        for image_name, image_attr in self.images.iteritems():

            if args.build_force:
                self.build_d[image_name] = True
                if not image_attr['internal_parent']:
                    self.fetch_d[image_attr['parent']] = True

            elif args.fetch_force:
                self.fetch_d[image_name] = True

            else:
                if image_attr['clean'] and self._parent_clean(image_name):
                    self.fetch_d[image_name] = True
                else:
                    self.build_d[image_name] = True
                    if not image_attr['internal_parent']:
                        self.fetch_d[image_attr['parent']] = True

    def _context_clean(self, image_name):

        image = self.images[image_name]
        context_path = os.path.normpath(os.path.join(image['path'],
                                                     image['context']))
        clean = self.rp.path_clean(image['repo'], context_path)

        LOG.debug("  context is clean?: %s", clean)

        return clean

    def _parent_clean(self, image_name):

        # externally parented images are clean
        if not self.images[image_name]["internal_parent"]:
            return True
        else:
            # check parental cleanliness
            parent = self.images[image_name]['parent']
            if self._parent_clean(parent) and self.images[parent]['clean']:
                return True

        return False

    def _process_images(self):

        for fetch_name in self.fetch_d.keys():

            # split tag names in images
            fetch_name_split = string.split(fetch_name, ":")

            # handle upstream images with a tag specified in the FROM line
            if len(fetch_name_split) > 1:
                self._fetch_image(fetch_name_split[0], fetch_name_split[1])
            else:
                # images that we fetch tagged w/commit hash
                if self.images.get(fetch_name, None):
                    self._fetch_image(fetch_name,
                                      self.images[fetch_name]['commit_hash'])
                # untagged upstream images
                else:
                    self._fetch_image(fetch_name, None)

        # loop on images to build until there are none left
        while len(self.build_d) > 0:
            to_build = self._get_buildable()
            self._build_image(to_build)

    def _get_buildable(self):

        # yield the first image whose parent is present
        for to_build in self.build_d.keys():
            if self.images[to_build]['parent'] in self.present_d.keys():
                return to_build

        # die if none are buildable
        LOG.error("No buildable images in set: %s" %
                  ", ".join(self.build_d.keys()))
        sys.exit(1)

    def _docker_connect(self):

        self.dc = docker.from_env()

        if self.dc.ping():
            LOG.debug("Docker server is responding")
        else:
            LOG.error("Unable to ping docker server")
            sys.exit(1)

    def _fetch_image(self, image_name, tag):

        LOG.info("Attempting to fetch docker image for %s, tag: %s" %
                 (image_name, tag))

        if self.dc:
            try:
                # pull "latest" if no tag specified, as in CLI
                if tag:
                    p_image = self.dc.pull(image_name, tag=tag)
                else:
                    p_image = self.dc.pull(image_name, tag="latest")

            except:
                LOG.exception("Error pulling docker image")

            LOG.debug("Fetched %s, id: %s" % (image_name, p_image))

        if tag:
            tagged_image_name = "%s:%s" % (image_name, tag)
        else:
            tagged_image_name = image_name

        self.present_d[tagged_image_name] = True

    def _build_image(self, image_name):

        LOG.info("Building docker image for %s" % image_name)

        if self.dc:
            image = self.images[image_name]

            path = os.path.join(image['repo_path'],
                                image['path'])
            try:
                b_image = docker.build(path=path)
            except:
                LOG.exception("Error building docker image")

            LOG.debug("Built %s, id: %s" % (image_name, b_image.id))

        self.present_d[image_name] = True
        self.build_d.pop(image_name)


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

    rp = RepoParser()
    dil = DockerImageList(rp)
