#!/bin/sh

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

## Script to patch up diff reated by `repo diff`

# from https://groups.google.com/d/msg/repo-discuss/43juvD1qGIQ/7maptZVcEjsJ
if [ -z "$1" ] || [ ! -e "$1" ]; then
    echo "Usages: $0 <repo_diff_file>";
    exit 0;
fi

rm -fr _tmp_splits*
cat $1 | csplit -qf '' -b "_tmp_splits.%d.diff" - '/^project.*\/$/' '{*}' 

working_dir=`pwd`

for proj_diff in `ls _tmp_splits.*.diff`
do 
    chg_dir=`cat $proj_diff | grep '^project.*\/$' | cut -d " " -f 2`
    echo "FILE: $proj_diff $chg_dir"
    if [ -e $chg_dir ]; then
        ( cd $chg_dir; \
            cat $working_dir/$proj_diff | grep -v '^project.*\/$' | patch -Np1;);
    else
        echo "$0: Project directory $chg_dir don't exists.";
    fi
done
