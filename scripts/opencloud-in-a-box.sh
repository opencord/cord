#!/usr/bin/env bash
# opencloud-in-a-box.sh

set -e -x

# start time, used to name logfiles
START_T=$(date -u "+%Y%m%d_%H%M%SZ")

# Paths
CORDDIR=~/cord
CONFIG=${CORDDIR}/config/opencloud_in_a_box.yml
SSHCONFIG=~/.ssh/config
VAGRANT_CWD=${CORDDIR}/build/targets/opencloud-in-a-box

# CORD versioning
REPO_BRANCH="cord-3.0"
VERSION_STRING="OpenCloud based on CORD 3.0 release"

function add_box() {
  echo "Downloading image: $1"
  vagrant box list | grep $1 | grep virtualbox || vagrant box add $1
  vagrant box list | grep $1 | grep libvirt || vagrant mutate $1 libvirt --input-provider virtualbox
}

function run_stage {
    echo "==> "$1": Starting"
    $1
    echo "==> "$1": Complete"
}

function cleanup_from_previous_test() {
  echo "## Cleanup ##"

  if [ -d $CORDDIR/build ]
  then
    echo "Destroying all Vagrant VMs"
    cd $CORDDIR/build
    sudo VAGRANT_CWD=$VAGRANT_CWD vagrant destroy
  fi

  echo "Removing $CORDDIR"
  cd ~
  rm -rf $CORDDIR
}

function bootstrap() {

  if [ ! -x "/usr/bin/ansible" ]
  then
    echo "Installing Ansible..."
    sudo apt-get update
    sudo apt-get install -y software-properties-common apt-transport-https
    #sudo apt-add-repository -y ppa:ansible/ansible  # latest supported version
    sudo apt-get -y install python-dev libffi-dev python-pip libssl-dev sshpass
    sudo pip install ansible==2.2.2.0
    sudo apt-get update
    sudo apt-get install -y python-netaddr
  fi

  if [ ! -x "/usr/local/bin/repo" ]
  then
    echo "Installing repo..."
    REPO_SHA256SUM="e147f0392686c40cfd7d5e6f332c6ee74c4eab4d24e2694b3b0a0c037bf51dc5" # not versioned...
    curl -o /tmp/repo https://storage.googleapis.com/git-repo-downloads/repo
    echo "$REPO_SHA256SUM  /tmp/repo" | sha256sum -c -
    sudo mv /tmp/repo /usr/local/bin/repo
    sudo chmod a+x /usr/local/bin/repo
  fi

  if [ ! -x "/usr/bin/vagrant" ]
  then
    echo "Installing vagrant and associated tools..."
    VAGRANT_SHA256SUM="52ebd6aa798582681d0f1e008982c709136eeccd668a8e8be4d48a1f632de7b8"  # version 1.9.2
    curl -o /tmp/vagrant.deb https://releases.hashicorp.com/vagrant/1.9.2/vagrant_1.9.2_x86_64.deb
    echo "$VAGRANT_SHA256SUM  /tmp/vagrant.deb" | sha256sum -c -
    sudo dpkg -i /tmp/vagrant.deb
    sudo apt-get -y install qemu-kvm libvirt-bin libvirt-dev curl nfs-kernel-server git build-essential python-pip
    sudo adduser $USER libvirtd
    sudo pip install pyparsing python-logstash

    run_stage cloudlab_setup

    echo "Installing vagrant plugins..."
    vagrant plugin list | grep vagrant-libvirt || vagrant plugin install vagrant-libvirt --plugin-version 0.0.35
    vagrant plugin list | grep vagrant-mutate || vagrant plugin install vagrant-mutate

    add_box ubuntu/trusty64
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
    repo init -u https://gerrit.opencord.org/manifest -b $REPO_BRANCH -g build,onos,orchestration,voltha
    repo sync

    # check out gerrit branches using repo
    for gerrit_branch in ${GERRIT_BRANCHES[@]}; do
      echo "Checking out opencord gerrit branch: $gerrit_branch"
      repo download ${gerrit_branch/:/ }
    done
  fi
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

function vagrant_vms_up() {

  # vagrant-libvirt 0.0.35 fails with libvirt networks created by others
  # echo "Configuring libvirt networking..."
  # cd ${CORDDIR}/build/ansible
  # ansible-playbook opencloud-in-a-box-playbook.yml

  echo "Bringing up OpenCloud-in-a-Box Vagrant VM's..."
  cd $CORDDIR/build
  sudo VAGRANT_CWD=$VAGRANT_CWD vagrant up head1 compute1 compute2 --provider libvirt

  # This is a workaround for a weird issue with ARP cache timeout breaking 'vagrant ssh'
  # It allows SSH'ing to the machine via 'ssh <machinename>'
  echo "Configuring SSH for VM's..."
  sudo VAGRANT_CWD=$VAGRANT_CWD vagrant ssh-config head1 compute1 compute2 > $SSHCONFIG

  sudo chown -R ${USER} ${VAGRANT_CWD}/.vagrant
}

function opencloud_buildhost_prep() {

  echo "Preparing build tools..."
  cd ${CORDDIR}/build/platform-install
  ansible-playbook -i inventory/opencloud opencloud-prep-playbook.yml
}

# Parse options
GERRIT_BRANCHES=
RUN_TEST=0
SETUP_ONLY=0
CLEANUP=0

while getopts "b:chsv" opt; do
  case ${opt} in
    b ) GERRIT_BRANCHES+=("$OPTARG")
      ;;
    c ) CLEANUP=1
      ;;
    h ) echo "Usage:"
      echo "    $0                install OpenCloud-in-a-Box [default]"
      echo "    $0 -b <project:changeset/revision>  checkout a changesets from gerrit. Can"
      echo "                      be used multiple times."
      echo "    $0 -c             cleanup from previous test"
      echo "    $0 -h             display this help message"
      echo "    $0 -s             run initial setup phase only (don't start building CORD)"
      echo "    $0 -v             print CiaB version and exit"
      exit 0
      ;;
    s ) SETUP_ONLY=1
      ;;
    v ) echo "$VERSION_STRING ($REPO_BRANCH branch)"
      exit 0
      ;;
    \? ) echo "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done

# What to do
if [[ $CLEANUP -eq 1 ]]
then
  run_stage cleanup_from_previous_test
fi

echo ""
echo "Preparing to install $VERSION_STRING ($REPO_BRANCH branch)"
echo ""

run_stage bootstrap


if [[ $SETUP_ONLY -ne 0 ]]
then
  echo "Finished build environment setup, exiting..."
  exit 0
fi

run_stage vagrant_vms_up
run_stage opencloud_buildhost_prep

exit 0
