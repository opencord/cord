#!/usr/bin/env python

# repoimagebuilder.py
# rebuilds/fetches docker container images per their git status in repo
# in addition to docker, needs `sudo apt-get install python-git`

import argparse
# import docker
import git
# import json
import logging
import os
# import pprint
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

    parser.add_argument('-r', '--repo_root',
                        default="..",
                        action="store",
                        help="repo root directory")

    parser.add_argument('-j', '--json_out',
                        action="store_true",
                        help="Print JSON output at end of run")

    parser.add_argument('-v', '--verbosity',
                        action='count', default=0,
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
            self.repos[repo_name] = {
                    "full_path": full_path,
                    "rel_path": rel_path,
                    }

        for repo_name in self.repos.keys():
            try:
                c_repo = git.Repo(self.repos[repo_name]["full_path"])

                self.repos[repo_name]['repo'] = c_repo
                LOG.debug("Repo - %s, head commit: %s" %
                          (repo_name, c_repo.head.commit))

                dirty = c_repo.is_dirty(untracked_files=True)
                LOG.debug(" Dirty: %s" % dirty)
                self.repos[repo_name]['dirty'] = dirty

                diff = c_repo.head.commit.diff(conf['branch'])

                if diff:
                    self.repos[repo_name]['onbranch'] = False
                    LOG.debug(" Differences from %s:" % conf['branch'])
                    for diff_obj in diff:
                        LOG.debug("  Change: %s" % diff_obj)
                else:
                    self.repos[repo_name]['onbranch'] = True

            except Exception as e:
                LOG.exception("Error with git repo")
                sys.exit(1)

    def path_is_dirty(self, repo_name, path):

        repo = self.repos[repo_name]['repo']

        diff_p = repo.head.commit.diff(conf['branch'], path)

        if diff_p:
            return True

        for u_file in repo.untracked_files.iteritems():
            if u_file.startswith(path):
                return True

        return False

    def get_repo(self, repo_name):
        return self.repos[repo_name]


class DockerImageList():

    def __init__(self, repo_parser):

        self.rp = repo_parser
        self.image_list = conf['repo_docker_images']

        for image in self.image_list:
            LOG.debug(image['name'])

        self._find_parent_images()

    def _find_parent_images(self):

        for image in self.image_list:

            repo_path = self.rp.get_repo(image['repo'])['full_path']

            df_path = os.path.join(repo_path,
                                   image.get('path', "."),
                                   image.get('dockerfile', 'Dockerfile'))

            with open(df_path) as dfh:
                df = dfh.read()

            frompatt = re.compile(r'^FROM\s+(.*)$', re.MULTILINE)
            fromline = re.search(frompatt, df)

            if fromline:
                parent_image_name = fromline.group(1)
                LOG.debug("Parent image of %s is %s" %
                          (image['name'], parent_image_name))

            else:
                LOG.error("Couldn't find a parent image in %s" % df_path)
                sys.exit(1)

    def build_docker_images():

        LOG.info(" Building docker container for ...")

#       dc = docker.from_env()
#       if dc.ping()
#           LOG.info("Docker server is responding")
#       else
#           LOG.error("Unable to ping docker server")
#           sys.exit(1)


if __name__ == "__main__":
    parse_args()
    load_config()
    rp = RepoParser()
    dil = DockerImageList(rp)

#   if args.json_out:
#       print(json.dumps(repos_d))
