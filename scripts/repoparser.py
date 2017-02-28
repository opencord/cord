#!/usr/bin/env python

import common

import os
import git
import sys
import datetime
import xml.etree.ElementTree as ET

LOG = common.setup_logging()


class RepoParser():

    def __init__(self):

        self.manifest_xml = {}
        self.repos = {}

        self.manifest_file = os.path.join(common.args.repo_root,
                                          ".repo/manifest.xml")

        try:
            tree = ET.parse(self.manifest_file)
            self.manifest_xml = tree.getroot()
        except Exception as e:
            LOG.exception("Error loading repo manifest:", e)
            sys.exit(1)

        # Find the remote URL for these repos
        remote = self.manifest_xml.find('remote')
        self.remote = remote.attrib['review']

        for project in self.manifest_xml.iter('project'):
            repo_name = project.attrib['name']
            rel_path = project.attrib['path']
            full_path = os.path.abspath(os.path.join(common.args.repo_root,
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

                self.repos[repo_name]['git_url'] = "%s%s" % (self.remote,
                                                             repo_name)

                self.repos[repo_name]['commit_hash'] = \
                    c_repo.head.commit.hexsha

                LOG.debug(" head commit: %s" %
                          self.repos[repo_name]['commit_hash'])

                commit_dt = datetime.utcfromtimestamp(
                                c_repo.head.commit.committed_date)
                self.repos[repo_name]['commit_date'] = \
                    datetime.strftime("%Y-%m-%dT%H:%M:%SZ", commit_dt)

                LOG.debug(" commit date: %s" %
                          self.repos[repo_name]['commit_date'])

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
        branch_head = repo.commit(common.conf['branch'])
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
