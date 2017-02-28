#!/usr/bin/env bash
# cord-bootstrap.sh
# Bootstraps environment and downloads CORD repos
# deluxe makefile enabled special edition

set -e -u

# start time, used to name logfiles
START_T=$(date -u "+%Y%m%d%H%M%SZ")

# Path to 'cord' directory
CORDDIR="${CORDDIR:-${HOME}/cord}"

# Commands
MAKECMD="${MAKECMD:-make -j4}"

# CORD versioning
REPO_BRANCH="${REPO_BRANCH:-master}"
VERSION_STRING="${VERSION_STRING:-CORD Devel}"

# Functions
function run_stage {
    echo "==> "$1": Starting"
    $1
    echo "==> "$1": Complete"
}

function bootstrap_vagrant() {

  if [ ! -x "/usr/bin/vagrant" ]
  then
    sudo apt-get update
    echo "Installing vagrant and associated tools..."
    VAGRANT_SHA256SUM="faff6befacc7eed3978b4b71f0dbb9c135c01d8a4d13236bda2f9ed53482d2c4"  # version 1.9.3
    curl -o /tmp/vagrant.deb https://releases.hashicorp.com/vagrant/1.9.3/vagrant_1.9.3_x86_64.deb
    echo "$VAGRANT_SHA256SUM  /tmp/vagrant.deb" | sha256sum -c -
    sudo dpkg -i /tmp/vagrant.deb
    sudo apt-get -y install qemu-kvm libvirt-bin libvirt-dev curl nfs-kernel-server git build-essential \
                            software-properties-common apt-transport-https python-dev python-pip sshpass ruby2.0
    sudo adduser $USER libvirtd
    sudo pip install pyparsing python-logstash gitpython graphviz

    run_stage cloudlab_setup

    echo "Installing vagrant plugins..."
    # FIXME: fix for vagrant-libvirt dependency issue that arose on 2017-04-28 - zdw
    # vagrant plugin list | grep vagrant-libvirt || vagrant plugin install vagrant-libvirt --plugin-version 0.0.35
    if ! vagrant plugin list | grep vagrant-libvirt
    then
      git clone -b remove_xmlrpc_dep https://github.com/zdw/vagrant-libvirt.git ${HOME}/vagrant-libvirt
      cd ~/vagrant-libvirt
      gem2.0 build vagrant-libvirt.gemspec
      vagrant plugin install vagrant-libvirt-0.0.35.gem
      cd ~
    fi
    vagrant plugin list | grep vagrant-mutate || vagrant plugin install vagrant-mutate

    add_box ubuntu/trusty64
  fi
}

function add_box() {
  vagrant box list | grep $1 | grep virtualbox || vagrant box add $1
  vagrant box list | grep $1 | grep libvirt || vagrant mutate $1 libvirt --input-provider virtualbox
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

function bootstrap_repo() {

  if [ ! -x "/usr/local/bin/repo" ]
  then
    echo "Installing repo..."
    REPO_SHA256SUM="e147f0392686c40cfd7d5e6f332c6ee74c4eab4d24e2694b3b0a0c037bf51dc5" # not versioned...
    curl -o /tmp/repo https://storage.googleapis.com/git-repo-downloads/repo
    echo "$REPO_SHA256SUM  /tmp/repo" | sha256sum -c -
    sudo mv /tmp/repo /usr/local/bin/repo
    sudo chmod a+x /usr/local/bin/repo
  fi

  if [ ! -d "$CORDDIR" ]
  then
    echo "Downloading CORD/XOS..."

    if [ ! -e "~/.gitconfig" ]
    then
      echo "No ~/.gitconfig, setting testing defaults"
      git config --global user.name 'Test User'
      git config --global user.email 'test@null.com'
      git config --global color.ui false
    fi

    # make sure we can find gerrit.opencord.org as DNS failures will fail the build
    dig +short gerrit.opencord.org || (echo "ERROR: gerrit.opencord.org can't be looked up in DNS" && exit 1)

    mkdir $CORDDIR && cd $CORDDIR
    repo init -u https://gerrit.opencord.org/manifest -b $REPO_BRANCH
    repo sync

    # check out gerrit branches using repo
    for gerrit_branch in ${GERRIT_BRANCHES[@]}; do
      echo "Checking out gerrit changeset: $gerrit_branch"
      repo download ${gerrit_branch/:/ }
    done
  fi
}

function bootstrap_ansible() {

  if [ ! -x "/usr/bin/ansible" ]
  then
    echo "Installing Ansible..."
    sudo apt-add-repository -y ppa:ansible/ansible  # latest supported version
    sudo apt-get update
    sudo apt-get install -y ansible python-netaddr
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
GERRIT_BRANCHES=()
MAKE_TARGETS=()
DOCKER=0

while getopts "b:dht:v" opt; do
  case ${opt} in
    b ) GERRIT_BRANCHES+=("$OPTARG")
      ;;
    d ) DOCKER=1
      ;;
    h ) echo "Usage:"
      echo "    $0 -b <project:changeset/revision>  Checkout a changesets from gerrit. Can"
      echo "                      be used multiple times."
      echo "    $0 -d             Install docker for local scenario"
      echo "    $0 -h             Display this help message"
      echo "    $0 -t <target>    After bootstrap, run '$MAKECMD <target>' in cord/build/"
      echo "                      target. Can be used multiple times."
      echo "    $0 -v             Print CORD version and exit"
      exit 0
      ;;
    t ) MAKE_TARGETS+=("$OPTARG")
      ;;
    v ) echo "$VERSION_STRING ($REPO_BRANCH branch)"
      exit 0
      ;;
    \? ) echo "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done

echo ""
echo "Preparing for CORD version: $VERSION_STRING ($REPO_BRANCH branch)"
echo ""

run_stage bootstrap_vagrant
run_stage bootstrap_ansible
run_stage bootstrap_repo

if [[ $DOCKER -ne 0 ]]
then
  run_stage bootstrap_docker
fi

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
