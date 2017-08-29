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

# vagrant-ssh-config.sh
# Checks to see if vagrant SSH key loading is set up properly.

VAGRANT_SSH_CONFIG=$1
SSH_IMPORT='import ${VAGRANT_SSH_CONFIG}'
USER_SSH_CONFIG='~/.ssh/config'

if [ -e $USER_SSH_CONFIG ]
  if grep "^$SSH_IMPORT" $USER_SSH_CONFIG
    echo "SSH configured to import Vagrant SSH config, done."
  else
    echo "SSH not configured to import Vagrant SSH config."
    echo "Please add this line to your $USER_SSH_CONFIG file:"
    echo ""
    echo "$SSH_IMPORT"
    echo ""
    echo "Then reattempt your build"
    exit 1
  fi
else
  echo "User SSH config file doesn't exist at $USER_SSH_CONFIG"
  echo "Creating a minimal $USER_SSH_CONFIG file that imports $VAGRANT_SSH_CONFIG"
  echo $SSH_IMPORT > $USER_SSH_CONFIG
fi

 
