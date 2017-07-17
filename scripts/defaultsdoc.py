#!/usr/bin/env python
# defaultsdoc.py - documentation for ansible default vaules

import yaml
import os
import sys
import pprint
import re
import fnmatch
import jinja2
import argparse

parser = argparse.ArgumentParser()

parser.add_argument('-p', '--playbook_dir', default='../platform-install/',
                    action='store', required=False,
                    help="path to base playbook directory")

parser.add_argument('-d', '--descriptions', default='descriptions.md',
                    action='store', required=False,
                    help="markdown file with descriptions")

parser.add_argument('-t', '--template', default='defaults.md.j2',
                    action='store', required=False,
                    help="jinja2 template to fill with defaults")

parser.add_argument('-o', '--output', default='defaults.md',
                    action='store', required=False,
                    help="output file")

args = parser.parse_args()

role_defs = []
profile_defs = []
group_defs = []

def_docs = {}

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
    try:
        rd_fullpath = os.path.abspath(os.path.join(args.playbook_dir, rd))
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
                    def_docs[key]['reflist'].append(rd)
                else:
                    print " %s has different default > %s : %s" % (rd, key, val) 
                    sys.exit(1)
            else:
                def_docs[key] = {
                        'defval': val,
                        'defval_pp': yaml.dump(val, indent=2, allow_unicode=True, default_flow_style=False),
                        'description': "",
                        'reflist': [rd],
                        }

descriptions = {}

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
     

for d_name, d_text in descriptions.iteritems():
    if d_name in def_docs:
        def_docs[d_name]['description'] = d_text
    else:
        def_docs[d_name] = {
                        'defval': "No Default",
                        'description': d_text,
                        'reflist': {}, 
                        }

print "## Defaults"
for key in sorted(def_docs):
    print " %s: %s" % (key, def_docs[key]['defval'])
    print "  Used in:"
    for ref in sorted(def_docs[key]['reflist']):
        print "   %s" % ref

j2env = jinja2.Environment(
    loader = jinja2.FileSystemLoader('.')
)

template = j2env.get_template('defaults.md.j2')

print template.render(def_docs=def_docs)


