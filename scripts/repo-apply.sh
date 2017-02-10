#!/bin/sh
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
