#!/usr/bin/env bash

set -e

CORDDIR=~/opencord
VMDIR=/cord/build/
CONFIG=config/cord_in_a_box.yml
SSHCONFIG=~/.ssh/config

function cleanup_from_previous_test() {
  echo "## Cleanup ##"

  if [ -d $CORDDIR/build ]
  then
    echo "Destroying all Vagrant VMs"
    cd $CORDDIR/build
    sudo su $USER -c 'vagrant destroy'
  fi

  echo "Removing $CORDDIR"
  cd ~
  rm -rf $CORDDIR
}

function bootstrap() {
  cd ~
  sudo apt-get update
  [ -e vagrant_1.8.5_x86_64.deb ] || wget https://releases.hashicorp.com/vagrant/1.8.5/vagrant_1.8.5_x86_64.deb
  dpkg -l vagrant || sudo dpkg -i vagrant_1.8.5_x86_64.deb
  sudo apt-get -y install qemu-kvm libvirt-bin libvirt-dev curl nfs-kernel-server git build-essential

  [ -e ~/.ssh/id_rsa ] || ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa

  sudo adduser $USER libvirtd

  sudo curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo
  sudo chmod a+x /usr/local/bin/repo

  if [ ! -d "$CORDDIR" ]
  then
    mkdir $CORDDIR && cd $CORDDIR
    git config --global user.name 'Test User'
    git config --global user.email 'test@null.com'
    git config --global color.ui false

    repo init -u https://gerrit.opencord.org/manifest -b master -g build,onos,orchestration
    repo sync

    # check out gerrit branches using repo
    for gerrit_branch in ${GERRIT_BRANCHES[@]}; do
      echo "checking out opencord gerrit branch: $gerrit_branch"
      repo download ${gerrit_branch/:/ }
    done
  fi

  cd $CORDDIR/build
  vagrant plugin list | grep vagrant-libvirt || vagrant plugin install vagrant-libvirt --plugin-version 0.0.35
  vagrant plugin list | grep vagrant-mutate || vagrant plugin install vagrant-mutate
  vagrant box list ubuntu/trusty64 | grep virtualbox || vagrant box add ubuntu/trusty64
  vagrant box list ubuntu/trusty64 | grep libvirt || vagrant mutate ubuntu/trusty64 libvirt --input-provider virtualbox
}

function cloudlab_setup() {
  if [ -e /usr/testbed/bin/mkextrafs ]
  then
    sudo mkdir -p /mnt/extra

    # Sometimes this command fails on the first try
    sudo /usr/testbed/bin/mkextrafs -r /dev/sdb -qf "/mnt/extra/" || sudo /usr/testbed/bin/mkextrafs -r /dev/sdb -qf "/mnt/extra/"

    # Check that the mount succeeded (sometimes mkextrafs succeeds but device not mounted)
    mount | grep sdb || (echo "ERROR: mkextrafs failed, exiting!" && exit 1)

    # we'll replace /var/lib/libvirt/images with a symlink below
    [ -d /var/lib/libvirt/images/ ] && [ ! -h /var/lib/libvirt/images ] && sudo rmdir /var/lib/libvirt/images

    sudo mkdir -p /mnt/extra/libvirt_images
    if [ ! -e /var/lib/libvirt/images ]
    then
      sudo ln -s /mnt/extra/libvirt_images /var/lib/libvirt/images
    fi
  fi
}

function vagrant_vms_up() {
  cd $CORDDIR/build

  sudo su $USER -c 'vagrant up corddev prod --provider libvirt'

  # This is a workaround for a weird issue with ARP cache timeout breaking 'vagrant ssh'
  # It allows SSH'ing to the machine via 'ssh corddev'
  sudo su $USER -c "vagrant ssh-config corddev prod > $SSHCONFIG"

  scp ~/.ssh/id_rsa* corddev:.ssh
  ssh corddev "chmod go-r ~/.ssh/id_rsa"
}

function install_head_node() {
  cd $CORDDIR/build

  # SSH config saved earlier allows us to connect to VM without running 'vagrant'
  ssh corddev "cd /cord/build; ./gradlew fetch"
  ssh corddev "cd /cord/build; ./gradlew buildImages"
  ssh corddev "cd /cord/build; ping -c 3 prod; ./gradlew -PdeployConfig=$VMDIR/$CONFIG -PtargetReg=10.100.198.201:5000 publish"
  ssh corddev "cd /cord/build; ./gradlew -PdeployConfig=$VMDIR/$CONFIG deploy"
}

function set_up_maas_user() {
  # Set up MAAS user on server to restart nodes via libvirt
  grep maas /etc/passwd || sudo useradd -m maas
  sudo adduser maas libvirtd

  # Copy generated public key to maas user's authorized_keys
  sudo su maas -c "mkdir -p ~/.ssh"
  sudo cp $HOME/.ssh/id_rsa.pub ~maas/.ssh/authorized_keys
  sudo chown maas:maas ~maas/.ssh/authorized_keys

  # Copy generated private key to maas user's home dir in prod VM
  scp $HOME/.ssh/id_rsa prod:/tmp
  ssh prod "sudo mkdir -p ~maas/.ssh"
  ssh prod "sudo cp /tmp/id_rsa ~maas/.ssh/id_rsa"
  ssh prod "sudo chown -R maas:maas ~maas/.ssh"
}

function add_compute_node() {
  echo add_compute_node: $1 $2

  cd $CORDDIR/build
  sudo su $USER -c "vagrant up $1 --provider libvirt"

  # Change MAC address of bridge to match cord-pod service profile
  # This change won't survive a reboot
  BRIDGE=$( route -n | grep 10.6.1.0 | awk '{print $8}' )
  sudo ifconfig $BRIDGE hw ether 02:42:0a:06:01:01

  ip addr list | grep 10.6.1.129 || sudo ip address add 10.6.1.129 dev $BRIDGE
  ip addr list | grep 10.6.1.193 || sudo ip address add 10.6.1.193 dev $BRIDGE

  # Set up power cycling for the compute node and wait for it to be provisioned
  ssh prod "cd /cord/build/ansible; ansible-playbook maas-provision.yml --extra-vars \"maas_user=maas vagrant_name=$2\""

  echo ""
  echo "compute_node is fully provisioned!"
}

function run_e2e_test () {
  cd $CORDDIR/build

  # User has been added to the lbvirtd group, but su $USER to be safe
  ssh corddev "cd /cord/build; ./gradlew -PdeployConfig=$VMDIR/$CONFIG postDeployTests"
}

function run_diagnostics() {
  echo "*** COLLECTING DIAGNOSTIC INFO NOT CURRENTLY IMPLEMENTED"
  # Need to fix up inventory to collect info from compute nodes
  # Using juju-ansible is one possibility
  #echo "*** COLLECTING DIAGNOSTIC INFO - check ~/diag-* on the head node"
  #ansible-playbook -i $INVENTORY cord-diag-playbook.yml
}

# Parse options
GERRIT_BRANCHES=
RUN_TEST=0
SETUP_ONLY=0
DIAGNOSTICS=0
CLEANUP=0
#By default, cord-in-a-box creates 1 compute node. If more than one compute is
#needed, use -n option
NUM_COMPUTE_NODES=1

while getopts "b:cdhn:st" opt; do
  case ${opt} in
    b ) GERRIT_BRANCHES+=("$OPTARG")
      ;;
    c ) CLEANUP=1
      ;;
    d ) DIAGNOSTICS=1
      ;;
    h ) echo "Usage:"
      echo "    $0                install OpenStack and prep XOS and ONOS VMs [default]"
      echo "    $0 -b <project:changeset/revision>  checkout a changesets from gerrit. Can"
      echo "                      be used multiple times."
      echo "    $0 -c             cleanup from previous test"
      echo "    $0 -d             run diagnostic collector"
      echo "    $0 -h             display this help message"
      echo "    $0 -n             number of compute nodes to setup. currently max 2 nodes can be supported"
      echo "    $0 -s             run initial setup phase only (don't start building CORD)"
      echo "    $0 -t             do install, bring up cord-pod configuration, run E2E test"
      exit 0
      ;;
    n ) NUM_COMPUTE_NODES=$OPTARG
      ;;
    s ) SETUP_ONLY=1
      ;;
    t ) RUN_TEST=1
      ;;
    \? ) echo "Invalid option: -$OPTARG"
      exit 1
      ;;
  esac
done

# What to do
if [[ $CLEANUP -eq 1 ]]
then
  cleanup_from_previous_test
fi

bootstrap
cloudlab_setup
vagrant_vms_up

if [[ $SETUP_ONLY -ne 0 ]]
then
  echo "Finished build environment setup, exiting..."
  exit 0
fi

install_head_node
set_up_maas_user

#Limiting the maximum number of compute nodes that can be supported to 2. If
#more than 2 compute nodes are needed, this script need to be enhanced to set
#the environment variable NUM_COMPUTE_NODES before invoking the Vagrant commands
if [[ $NUM_COMPUTE_NODES -gt 2 ]]
then
   echo "currently max only two compute nodes can be supported..."
   NUM_COMPUTE_NODES=2
fi

for i in `seq 1 $NUM_COMPUTE_NODES`;
do
   echo adding the compute node: compute-node-$i
   add_compute_node compute_node-$i build_compute_node-$i
done

if [[ $RUN_TEST -eq 1 ]]
then
  run_e2e_test
fi

if [[ $DIAGNOSTICS -eq 1 ]]
then
  run_diagnostics
fi

exit 0
