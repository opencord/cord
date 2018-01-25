#!/usr/bin/env python
# defaultsdoc.py - documentation for ansible default vaules

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

import argparse
import fnmatch
import jinja2
import logging
import os
import re
import sys
import xml.etree.ElementTree as ET
import yaml
import markedyaml

# logging setup
sh = logging.StreamHandler(sys.stderr)
sh.setFormatter(logging.Formatter(logging.BASIC_FORMAT))

LOG = logging.getLogger("defaultsdoc.py")
LOG.addHandler(sh)

# parse args
parser = argparse.ArgumentParser()

parser.add_argument('-p', '--playbook_dir', default='../platform-install/',
                    action='append', required=False,
                    help="path to base playbook directory")

parser.add_argument('-d', '--descriptions', default='scripts/descriptions.md',
                    action='store', required=False,
                    help="markdown file with descriptions")

parser.add_argument('-t', '--template', default='scripts/defaults.md.j2',
                    action='store', required=False,
                    help="jinja2 template to fill with defaults")

parser.add_argument('-o', '--output', default='defaults.md',
                    action='store', required=False,
                    help="output file")

args = parser.parse_args()

# find the branch we're on via the repo manifest
manifest_path = os.path.abspath("../../.repo/manifest.xml")
try:
    tree = ET.parse(manifest_path)
    manifest_xml = tree.getroot()
    repo_default = manifest_xml.find('default')
    repo_branch = repo_default.attrib['revision']
except Exception:
    LOG.exception("Error loading repo manifest")
    sys.exit(1)

role_defs = []
profile_defs = []
group_defs = []
def_docs = {}

# find all the files to be processed
for dirpath, dirnames, filenames in os.walk(args.playbook_dir):
    basepath = re.sub(args.playbook_dir, '', dirpath)
    for filename in filenames:
        filepath = os.path.join(basepath, filename)

        if fnmatch.fnmatch(filepath, "roles/*/defaults/*.yml"):
            role_defs.append(filepath)

        if fnmatch.fnmatch(filepath, "profile_manifests/*.yml"):
            profile_defs.append(filepath)

        if fnmatch.fnmatch(filepath, "group_vars/*.yml"):
            group_defs.append(filepath)


for rd in role_defs:
    rd_vars = {}
    # trim slash so basename grabs the final directory name
    rd_basedir = os.path.basename(args.playbook_dir[:-1])
    try:
        rd_fullpath = os.path.abspath(os.path.join(args.playbook_dir, rd))
        rd_partialpath = os.path.join(rd_basedir, rd)

        # partial URL, without line nums
        rd_url = "https://github.com/opencord/platform-install/tree/%s/%s" % (
            repo_branch, rd)

        rd_fh = open(rd_fullpath, 'r')

        # markedloader is for line #'s
        loader = markedyaml.MarkedLoader(rd_fh.read())
        marked_vars = loader.get_data()

        rd_fh.seek(0)  # go to front of file

        # yaml.safe_load is for vars in a better format
        rd_vars = yaml.safe_load(rd_fh)

        rd_fh.close()

    except yaml.YAMLError:
        LOG.exception("Problem loading file: %s" % rd)
        sys.exit(1)

    if rd_vars:

        for key, val in rd_vars.iteritems():

            # build full URL to lines. Lines numbered from zero, so +1 on them
            # to match github
            if marked_vars[key].start_mark.line == marked_vars[
                    key].end_mark.line:
                full_url = "%s#L%d" % (rd_url,
                                       marked_vars[key].start_mark.line + 1)
            else:
                full_url = "%s#L%d-L%d" % (rd_url,
                                           marked_vars[key].start_mark.line,
                                           marked_vars[key].end_mark.line)

            if key in def_docs:
                if def_docs[key]['defval'] == val:
                    def_docs[key]['reflist'].append(
                        {'path': rd_partialpath, 'link': full_url})
                else:
                    LOG.error(
                        " %s has different default > %s : %s" %
                        (rd, key, val))
            else:
                to_print = {str(key): val}
                pp = yaml.dump(
                    to_print,
                    indent=4,
                    allow_unicode=False,
                    default_flow_style=False)

                def_docs[key] = {
                    'defval': val,
                    'defval_pp': pp,
                    'description': "",
                    'reflist': [{'path': rd_partialpath, 'link': full_url}],
                }

# read in descriptions file
descriptions = {}
with open(args.descriptions, 'r') as descfile:
    desc_name = 'frontmatter'
    desc_lines = ''

    for d_l in descfile:
        # see if this is a header line at beginning of docs
        desc_header = re.match(r"##\s+([\w_]+)", d_l)

        if desc_header:
            # add previous description to dict
            descriptions[desc_name] = desc_lines.strip()

            # set this as the next name, wipe out lines
            desc_name = desc_header.group(1)
            desc_lines = ''
        else:
            desc_lines += d_l

    descriptions[desc_name] = desc_lines.strip()

# Get the frontmatter out of descriptions, and remove the header line
frontmatter = re.sub(r'^#.*\n\n', '', descriptions.pop('frontmatter', None))

# add descriptions to def_docs
for d_name, d_text in descriptions.iteritems():
    if d_name in def_docs:
        def_docs[d_name]['description'] = d_text
    else:
        LOG.error(
            "Description exists for '%s' but doesn't exist in defaults" %
            d_name)

# check for missing descriptions
for key in sorted(def_docs):
    if not def_docs[key]['description']:
        LOG.error("No description found for '%s'" % key)

# Add to template and write to output file
j2env = jinja2.Environment(
    loader=jinja2.FileSystemLoader('.')
)

template = j2env.get_template(args.template)

with open(args.output, 'w') as f:
    f.write(template.render(def_docs=def_docs, frontmatter=frontmatter))
