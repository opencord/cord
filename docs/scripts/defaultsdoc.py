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
import pprint
import re
import sys
import yaml

# logging setup
sh = logging.StreamHandler(sys.stderr)
sh.setFormatter(logging.Formatter(logging.BASIC_FORMAT))

LOG = logging.getLogger("defaultsdoc.py")
LOG.addHandler(sh)

# parse args
parser = argparse.ArgumentParser()

parser.add_argument('-p', '--playbook_dir', default='../platform-install/',
                    action='store', required=False,
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

role_defs = []
profile_defs = []
group_defs = []

# frontmatter section is any text at the top of the descriptions.md file, and
# comes before all other sections
def_docs = {'frontmatter':{'description':''}}

# find all the files to be processed
for dirpath, dirnames, filenames in os.walk(args.playbook_dir):
    basepath = re.sub(args.playbook_dir, '', dirpath)
    for filename in filenames :
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
        rd_fh = open(rd_fullpath, 'r')
        rd_vars = yaml.safe_load(rd_fh)
        rd_fh.close()
    except yaml.YAMLError:
        LOG.exception("Problem loading file: %s" % rd)
        sys.exit(1)

    if rd_vars:
        for key, val in rd_vars.iteritems():
            if key in def_docs:
                if def_docs[key]['defval'] == val:
                    def_docs[key]['reflist'].append(rd_partialpath)
                else:
                    LOG.error(" %s has different default > %s : %s" % (rd, key, val))
            else:
                to_print = { key:val }
                pp = yaml.dump(to_print, indent=4, allow_unicode=True, default_flow_style=False)

                def_docs[key] = {
                        'defval': val,
                        'defval_pp': pp,
                        'description': "",
                        'reflist': [rd_partialpath],
                        }

descriptions = {}

# read in descriptions file
with open(args.descriptions, 'r') as descfile:
    desc_name = 'frontmatter'
    desc_lines = ''

    for d_l in descfile:

        # see if this is a header line at beginning of docs
        desc_header = re.match(r"##\s+([\w_]+)", d_l)

        if desc_header:
            # add previous description to dict
            descriptions[desc_name] = desc_lines

            # set this as the next name, wipe out lines
            desc_name = desc_header.group(1)
            desc_lines = ''
        else:
            desc_lines += d_l

    descriptions[desc_name] = desc_lines


# add descriptions to def_docs
for d_name, d_text in descriptions.iteritems():
    if d_name in def_docs:
        def_docs[d_name]['description'] = d_text
    else:
        LOG.error("Description exists for '%s' but doesn't exist in defaults" % d_name)

# check for missing descriptions
for key in sorted(def_docs):
    if not def_docs[key]['description']:
        LOG.error("No description found for '%s'" % key)

# Add to template and write to output file
j2env = jinja2.Environment(
    loader = jinja2.FileSystemLoader('.')
)

template = j2env.get_template(args.template)

with open(args.output, 'w') as f:
    f.write(template.render(def_docs=def_docs))

