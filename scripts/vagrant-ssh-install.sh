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

# vagrant-ssh-install.sh
# Checks to see if vagrant SSH key configuration is installed.

set -e -u -o pipefail

VAGRANT_SSH_CONFIG="$1"

SSH_INCLUDE="Include ${VAGRANT_SSH_CONFIG}"
SSH_WILDCARD="$2"

USER_SSH_DIR="${HOME}/.ssh"
USER_SSH_CONFIG="$USER_SSH_DIR/config"

# check if we have a new enough version of SSH to deal with "Include" directive
# per: https://www.openssh.com/txt/release-7.3
if `ssh -V 2>&1 | perl -ne '/OpenSSH_([\d\.]{3})/ && \$1 >= 7.3 ? exit 0 : exit 1'`
then
  # ssh is >= 7.3, supports "Include"
  if [ -e $USER_SSH_CONFIG ]
  then
    if grep -F "$SSH_WILDCARD" $USER_SSH_CONFIG
    then
      echo "SSH configured to import Vagrant SSH config, done!"
    else
      echo "SSH not configured to import Vagrant SSH config."
      echo "Please add this line to the *TOP* your $USER_SSH_CONFIG file:"
      echo ""
      echo "$SSH_WILDCARD"
      echo ""
      echo "Then reattempt the build."
      exit 1
    fi
  else
    echo "User SSH config file doesn't exist at $USER_SSH_CONFIG"
    echo "Creating a minimal $USER_SSH_CONFIG file that imports $SSH_WILDCARD"
    mkdir -p "$USER_SSH_DIR"
    echo "$SSH_WILDCARD" > $USER_SSH_CONFIG
    echo "Done!"
  fi
else
  # ssh is < 7.3, doesn't support "Include"
  if [ -e $USER_SSH_CONFIG ]
  then
    echo "User SSH config file exists at $USER_SSH_CONFIG"
    echo "SSH is an older than 7.3, unable to Include ssh config file with Vagrant config."
    if cmp -s "$VAGRANT_SSH_CONFIG" "$USER_SSH_CONFIG"
    then
      echo "Contents of $VAGRANT_SSH_CONFIG and $USER_SSH_CONFIG are identical. Done!"
    else
      echo "Add the contents of $VAGRANT_SSH_CONFIG to $USER_SSH_CONFIG manually,"
      echo "replacing any previous similar entries, then reattempt the build."
      exit 1
    fi
  else
    echo "User SSH config file doesn't exist at $USER_SSH_CONFIG"
    echo "SSH is an older than 7.3, unable to Include Vagrant config,"
    echo "so copying $VAGRANT_SSH_CONFIG to $USER_SSH_CONFIG"
    mkdir -p "$USER_SSH_DIR"
    cp $VAGRANT_SSH_CONFIG $USER_SSH_CONFIG
    echo "Done!"
  fi
fi

