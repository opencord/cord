#!/bin/bash
#
# Copyright 2012 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

set -e

echo "Installing Ansible using PIP..."
apt-get install -y software-properties-common python-netaddr apt-transport-https
#apt-add-repository ppa:ansible/ansible
apt-get update
#apt-get install -y ansible
apt-get -y install python-dev libffi-dev python-pip libssl-dev sshpass
pip install ansible==2.2.2.0
mkdir -p /etc/ansible
cp /cord/build/ansible/ansible.cfg /etc/ansible/ansible.cfg
