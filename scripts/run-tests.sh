#!/usr/bin/env bash

set -e

CORDDIR=~/cord
VMDIR=/opt/cord/build/
CONFIG=config/cord_in_a_box.yml
SSHCONFIG=~/.ssh/config

function run_e2e_test () {
  cd $CORDDIR/build

  # User has been added to the lbvirtd group, but su $USER to be safe
  ssh corddev "cd $VMDIR; ./gradlew -PdeployConfig=$VMDIR/$CONFIG postDeployTests"
}

run_e2e_test

exit 0
