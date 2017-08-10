#!/usr/bin/env bash

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
