#!/usr/bin/env python

# imagebuilder.py
# rebuilds/fetches docker container images per their git status in repo
# in addition to docker, needs `sudo apt-get install python-git`


import common
from repoparser import RepoParser

import argparse
import datetime
import json
import logging
import os
import re
import string
import sys
import tarfile
import tempfile
import yaml

common.init()
LOG = common.setup_logging()


def parse_args():

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

    common.args = parser.parse_args()

    if common.args.verbosity > 1:
        LOG.setLevel(logging.DEBUG)


def load_config():
    try:
        common.conf = yaml.safe_load(common.args.container_list)
    except yaml.YAMLError as e:
        LOG.exception("Problem loading container list file: ", e)
        sys.exit(1)


class ImageBuilder():

    def __init__(self, repo_parser):

        self.rp = repo_parser
        self.dc = None  # docker client
        self.images = {}
        self.fetch_d = {}
        self.build_d = {}
        self.present_d = {}

        # create dict of images, setting defaults
        for image in common.conf['repo_docker_images']:

            repo_d = self.rp.get_repo(image['repo'])

            self.images[image['name']] = {
                    "repo_name": image['repo'],
                    "repo_d": repo_d,
                    "path": image.get('path', '.'),
                    "context": image.get('context', '.'),
                    "dockerfile": image.get('dockerfile', 'Dockerfile'),
                }

        self._evaluate_images()

        LOG.info("Images to fetch: %s" % ", ".join(self.fetch_d.keys()))
        LOG.info("Images to build: %s" % ", ".join(self.build_d.keys()))

        if not common.args.dry_run:
            self._docker_connect()

        self._process_images()

    def _evaluate_images(self):

        for image_name, image_attr in self.images.iteritems():

            LOG.debug("Evaluating image: %s" % image_name)

            # determine if build context is dirty
            self.images[image_name]['clean'] = self._context_clean(image_name)

            # construct path to Dockerfile
            df_path = os.path.join(image_attr['repo_d']['full_path'],
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

            if common.args.build_force:
                self.build_d[image_name] = True
                if not image_attr['internal_parent']:
                    self.fetch_d[image_attr['parent']] = True

            elif common.args.fetch_force:
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
        clean = self.rp.path_clean(image['repo_name'], context_path)

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
                    pulltag = tag
                else:
                    pulltag = "latest"

                # pp = pprint.PrettyPrinter(indent=4)

                for stat_json in self.dc.pull(image_name,
                                              stream=True,
                                              tag=pulltag):

                    stat_d = json.loads(stat_json)

                    # pp.pprint(stat_d)

                    if 'stream' in stat_d:
                        for stat_l in stat_d['stream'].split('\n'):
                            LOG.debug(stat_l)

                    if 'status' in stat_d:
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

        self.present_d[tagged_image_name] = True

    def _tar_context(self, context_path):

        LOG.info("Creating context tarball of path: %s" % context_path)

        t_fh = tempfile.NamedTemporaryFile()
        t = tarfile.open(mode='w', fileobj=t_fh, dereference=True)

        # see docker-py source for context
        for path in sorted(
                docker.utils.exclude_paths(context_path, ['.git'])):
            t.add(os.path.join(context_path, path),
                  arcname=path,
                  recursive=False)

        t.list()  # prints all files in tarball

        t.close()
        t_fh.seek(0)

        return t_fh

    def _build_image(self, image_name):

        LOG.info("Building docker image for %s" % image_name)

        if self.dc:
            image = self.images[image_name]

            context_path = os.path.normpath(
                               os.path.join(image['repo_d']['full_path'],
                                            image['path'],
                                            image['context']))

            # handle dockerfiles with supplied contexts
            if image['context'] is ".":
                dockerfile = image['dockerfile']
            else:
                dockerfile = os.path.normpath(
                                 os.path.join(image['path'],
                                              image['dockerfile']))

            LOG.info("Dockerfile path: %s" % dockerfile)

            context_tar = self._tar_context(context_path)

            time_now = datetime.datetime.utcnow()
            build_date = time_now.strftime("%Y-%m-%dT%H:%M:%SZ")

            buildargs = {
                "org.label-schema.schema-version": "1.0",
                "org.label-schema.name": image_name,
                "org.label-schema.build-date": build_date,
                "org.label-schema.vcs-url": image['repo_d']['git_url'],
                "org.opencord.vcs-commit-date":
                    image['repo_d']['commit_date'],
            }

            # cleanliness here is based on repo, not restricted to context,
            # which may not be efficient...
            if image['repo_d']['clean']:
                buildargs["org.label-schema.version"] = common.conf['branch']
                buildargs["org.label-schema.vcs-ref"] = \
                    image['repo_d']['commit_hash']
            else:
                buildargs["org.label-schema.version"] = "unclean"

            for key, val in buildargs.iteritems():
                LOG.info("Buildarg - %s : %s" % (key, val))

            try:
                LOG.info("Building %s with docker" % image_name)
                for stat_d in self.dc.build(tag=image_name,
                                            buildargs=buildargs,
                                            custom_context=True,
                                            fileobj=context_tar,
                                            dockerfile=dockerfile,
                                            rm=True,
                                            forcerm=True,
                                            pull=False,
                                            stream=True,
                                            decode=True):

                    # stat_d = json.loads(stat_json)

                    if 'stream' in stat_d:
                        for stat_l in stat_d['stream'].split('\n'):
                            if(stat_l):
                                LOG.debug(stat_l)

                    if 'status' in stat_d:
                        for stat_l in stat_d['status'].split('\n'):
                            if(stat_l):
                                LOG.info(stat_l)

                    if 'error' in stat_d:
                        LOG.error(stat_d['error'])
                        sys.exit(1)

            except:
                LOG.exception("Error building docker image")

            LOG.debug("Built %s" % (image_name))

        self.present_d[image_name] = True
        self.build_d.pop(image_name)


if __name__ == "__main__":
    parse_args()
    load_config()

    # only include docker module if not a dry run
    if not common.args.dry_run:
        try:
            import docker
        except ImportError:
            LOG.error("Unable to load python docker module (-d ?)")
            sys.exit(1)

    rp = RepoParser()
    dil = ImageBuilder(rp)
