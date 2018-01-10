#!/usr/bin/env bash
#
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

# cord-bootstrap.sh
# Bootstraps a dev system for CORD, downloads source

set -e -u -o pipefail

# start time, used to name logfiles
START_T=$(date -u "+%Y%m%d%H%M%SZ")

# Location of 'cord' directory checked out on the local system
CORDDIR="${CORDDIR:-${HOME}/cord}"

# Commands
MAKECMD="${MAKECMD:-make -j4}"

# CORD versioning
REPO_BRANCH="${REPO_BRANCH:-master}"

# Tool/OS versioning
HOST_RELEASE=`lsb_release -c -s`

if [ ${HOST_RELEASE} = "trusty" ]; then
  VAGRANT_LIBVIRT_VERSION="0.0.35"
else
  VAGRANT_LIBVIRT_VERSION="0.0.40"
fi

# Functions
function run_stage {
    echo "==> "$1": Starting"
    $1
    echo "==> "$1": Complete"
}

function bootstrap_ansible() {

  if [ ! -x "/usr/bin/ansible" ]
  then
    echo "Installing Ansible..."
    sudo apt-get update
    sudo apt-get -y install apt-transport-https build-essential curl git python-dev \
                            python-netaddr python-pip software-properties-common sshpass
    sudo pip install gitpython graphviz "Jinja2>=2.9"
    sudo apt-add-repository -y ppa:ansible/ansible  # latest supported version
    sudo apt-get update
    sudo apt-get install -y ansible
  fi
}

function bootstrap_repo() {

  if [ ! -x "/usr/local/bin/repo" ]
  then
    echo "Installing repo..."
    # v1.23, per https://source.android.com/source/downloading
    REPO_SHA256SUM="394d93ac7261d59db58afa49bb5f88386fea8518792491ee3db8baab49c3ecda"
    curl -o /tmp/repo 'https://gerrit.opencord.org/gitweb?p=repo.git;a=blob_plain;f=repo;hb=refs/heads/stable'
    echo "$REPO_SHA256SUM  /tmp/repo" | sha256sum -c -
    sudo mv /tmp/repo /usr/local/bin/repo
    sudo chmod a+x /usr/local/bin/repo
  fi

  if [ ! -d "$CORDDIR/build" ]
  then
    # make sure we can find gerrit.opencord.org as DNS failures will fail the build
    dig +short gerrit.opencord.org || (echo "ERROR: gerrit.opencord.org can't be looked up in DNS" && exit 1)

    echo "Downloading CORD/XOS, branch:'${REPO_BRANCH}'..."

    if [ ! -e "${HOME}/.gitconfig" ]
    then
      echo "No ${HOME}/.gitconfig, setting testing defaults"
      git config --global user.name 'Test User'
      git config --global user.email 'test@null.com'
      git config --global color.ui false
    fi

    mkdir -p $CORDDIR && cd $CORDDIR
    repo init -u https://gerrit.opencord.org/manifest -b $REPO_BRANCH
    repo sync

    # download gerrit patches using repo
    if [[ ! -z ${GERRIT_PATCHES[@]-} ]]
    then
      for gerrit_patch in "${GERRIT_PATCHES[@]-}"
      do
        echo "Checking out gerrit changeset: '$gerrit_patch'"
        repo download ${gerrit_patch/:/ }
      done
    fi
  fi
}

function bootstrap_vagrant() {

  if [ ! -x "/usr/bin/vagrant" ]
  then
    echo "Installing vagrant and associated tools..."
    sudo apt-get -y install qemu-kvm libvirt-bin libvirt-dev nfs-kernel-server
    sudo adduser $USER libvirtd

    VAGRANT_SHA256SUM="2f9498a83b3d650fcfcfe0ec7971070fcd3803fad6470cf7da871caf2564d84f"  # version 2.0.1
    curl -o /tmp/vagrant.deb https://releases.hashicorp.com/vagrant/2.0.1/vagrant_2.0.1_x86_64.deb
    echo "$VAGRANT_SHA256SUM  /tmp/vagrant.deb" | sha256sum -c -
    sudo dpkg -i /tmp/vagrant.deb
  fi

  run_stage cloudlab_setup

  echo "Installing vagrant plugins if needed..."
  vagrant plugin list | grep -q vagrant-libvirt || vagrant plugin install vagrant-libvirt --plugin-version ${VAGRANT_LIBVIRT_VERSION}
  vagrant plugin list | grep -q vagrant-hosts || vagrant plugin install vagrant-hosts
  vagrant plugin list | grep -q vagrant-mutate || vagrant plugin install vagrant-mutate

  echo "Obtaining libvirt image of Ubuntu"

  if [[ $XENIAL -eq 1 ]]; then
    UBUNTU_VERSION=${UBUNTU_VERSION:-bento/ubuntu-16.04}
  else
    UBUNTU_VERSION=${UBUNTU_VERSION:-ubuntu/trusty64}
  fi

  vagrant box list | grep ${UBUNTU_VERSION} | grep virtualbox || vagrant box add --provider virtualbox ${UBUNTU_VERSION}
  vagrant box list | grep ${UBUNTU_VERSION} | grep libvirt || vagrant mutate ${UBUNTU_VERSION} libvirt --input-provider virtualbox
}

function cloudlab_setup() {

  # Don't do anything if not a CloudLab node
  [ ! -d /usr/local/etc/emulab ] && return

  # The watchdog will sometimes reset groups, turn it off
  if [ -e /usr/local/etc/emulab/watchdog ]
  then
    sudo /usr/bin/perl -w /usr/local/etc/emulab/watchdog stop
    sudo mv /usr/local/etc/emulab/watchdog /usr/local/etc/emulab/watchdog-disabled
  fi

  # Mount extra space, if haven't already
  if [ ! -d /mnt/extra ]
  then
    sudo mkdir -p /mnt/extra

    # for NVME SSD on Utah Cloudlab, not supported by mkextrafs
    if $(df | grep -q nvme0n1p1) && [ -e /usr/testbed/bin/mkextrafs ]
    then
      # set partition type of 4th partition to Linux, ignore errors
      echo -e "t\n4\n82\np\nw\nq" | sudo fdisk /dev/nvme0n1 || true

      sudo mkfs.ext4 /dev/nvme0n1p4
      echo "/dev/nvme0n1p4 /mnt/extra/ ext4 defaults 0 0" | sudo tee -a /etc/fstab
      sudo mount /mnt/extra
      mount | grep nvme0n1p4 || (echo "ERROR: NVME mkfs/mount failed, exiting!" && exit 1)

    elif [ -e /usr/testbed/bin/mkextrafs ]  # if on Clemson/Wisconsin Cloudlab
    then
      # Sometimes this command fails on the first try
      sudo /usr/testbed/bin/mkextrafs -r /dev/sdb -qf "/mnt/extra/" || sudo /usr/testbed/bin/mkextrafs -r /dev/sdb -qf "/mnt/extra/"

      # Check that the mount succeeded (sometimes mkextrafs succeeds but device not mounted)
      mount | grep sdb || (echo "ERROR: mkextrafs failed, exiting!" && exit 1)
    fi
  fi

  # replace /var/lib/libvirt/images with a symlink
  [ -d /var/lib/libvirt/images/ ] && [ ! -h /var/lib/libvirt/images ] && sudo rmdir /var/lib/libvirt/images
  sudo mkdir -p /mnt/extra/libvirt_images

  if [ ! -e /var/lib/libvirt/images ]
  then
    sudo ln -s /mnt/extra/libvirt_images /var/lib/libvirt/images
  fi
}

function bootstrap_docker() {

  if [ ! -x "/usr/bin/docker" ]
  then
    echo "Installing Devel Tools (docker)..."
    cd ${CORDDIR}/build/platform-install
    ansible-playbook -i inventory/localhost devel-tools-playbook.yml
  fi
}

# Parse options
GERRIT_PATCHES=()
MAKE_TARGETS=()
GROUP_LIST=()
DOCKER=0
VAGRANT=0
XENIAL=0

while getopts "dhp:t:vx" opt; do
  case ${opt} in
    d ) DOCKER=1
        GROUP_LIST+=("docker")
      ;;
    h ) echo "Usage for $0:"
      echo "  -d                           Install Docker for local scenario."
      echo "  -h                           Display this help message."
      echo "  -p <project:change/revision> Download a patch from gerrit. Can be repeated."
      echo "  -t <target>                  Run '$MAKECMD <target>' in cord/build/. Can be repeated."
      echo "  -v                           Install Vagrant for mock/virtual/physical scenarios."
      echo "  -x                           Use Xenial (16.04) in Vagrant VM's."
      exit 0
      ;;
    p ) GERRIT_PATCHES+=("$OPTARG")
      ;;
    t ) MAKE_TARGETS+=("$OPTARG")
      ;;
    v ) VAGRANT=1
        GROUP_LIST+=("libvirtd")
      ;;
    x ) XENIAL=1
      ;;
    \? ) echo "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done

# Start process
run_stage bootstrap_ansible
run_stage bootstrap_repo

if [[ $VAGRANT -ne 0 ]]
then
  run_stage bootstrap_vagrant
fi

if [[ $DOCKER -ne 0 ]]
then
  run_stage bootstrap_docker
fi

# Check for group membership when needed
if [[ ! -z ${GROUP_LIST[@]-} ]]
then
  HAS_NEEDED_GROUPS=0
  for group_item in "${GROUP_LIST[@]-}"; do
    if ! $(groups | grep -q "$group_item")
    then
      echo "You are not in the group: "$group_item", please logout/login."
      HAS_NEEDED_GROUPS=1
    fi
  done

  if [[ $HAS_NEEDED_GROUPS -ne 0 ]];
  then
    exit 1
  fi
fi

# run make targets, if specified
if [[ ! -z ${MAKE_TARGETS[@]-} ]]
then
  for make_target in "${MAKE_TARGETS[@]-}"; do
    makelog=${HOME}/${START_T}_make_`echo $make_target | sed 's/[^[:alnum:]-]/_/g'`
    echo "Logging to: $makelog"
    echo "Running '$MAKECMD $make_target'" | tee -a $makelog
    cd ${CORDDIR}/build/
    $MAKECMD $make_target 2>&1 | tee -a $makelog
  done
fi

exit 0
