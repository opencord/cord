#!/usr/bin/env bash

set -e

CORDDIR=~/opencord
VMDIR=/cord/build/
CONFIG=config/cord_in_a_box.yml
SSHCONFIG=~/.ssh/config

function cleanup_from_previous_test() {
  set +e

  echo "## Cleanup ##"

  echo "Shutting down all Vagrant VMs"
  cd $CORDDIR/build
  vagrant destroy

  echo "Destroying juju environment"
  juju destroy-environment --force -y manual

  VMS=$( sudo uvt-kvm list )
  for VM in $VMS
  do
    echo "Destroying $VM"
    sudo uvt-kvm destroy $VM
  done

  echo "Cleaning up files"
  rm -rf ~/.juju
  rm -f ~/.ssh/known_hosts
  rm -rf ~/platform-install
  rm -rf ~/cord_apps
  rm -rf ~/.ansible_async

  echo "Removing MAAS"
  [ -e  /usr/local/bin/remove-maas-components ] && /usr/local/bin/remove-maas-components

  echo "Remove apt-cacher-ng"
  sudo apt-get remove -y apt-cacher-ng
  sudo rm -f /etc/apt/apt.conf.d/02apt-cacher-ng

  echo "Removing mgmtbr"
  ifconfig mgmtbr && sudo ip link set dev mgmtbr down && sudo brctl delbr mgmtbr

  echo "Removing Juju packages"
  sudo apt-get remove --purge -y $(dpkg --get-selections | grep "juju\|nova\|neutron\|keystone\|glance" | awk '{print $1}')
  sudo apt-get autoremove -y

  rm -rf $CORDDIR

  set -e
}

function bootstrap() {
  cd ~
  sudo apt-get update
  [ -e vagrant_1.8.5_x86_64.deb ] || wget https://releases.hashicorp.com/vagrant/1.8.5/vagrant_1.8.5_x86_64.deb
  sudo dpkg -i vagrant_1.8.5_x86_64.deb
  sudo apt-get -y install qemu-kvm libvirt-bin libvirt-dev curl nfs-kernel-server git build-essential

  [ -e ~/.ssh/id_rsa ] || ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
  cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

  # Log into the local node once to get host key
  ssh -o StrictHostKeyChecking=no localhost "ls > /dev/null"

  USER=$(whoami)
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

    cd $CORDDIR/build
    sed -i "s/user: 'ubuntu'/user: \"$USER\"/" $CONFIG

    # Set external interface in config file
    IFACE=$(route | grep default | awk '{print $8}' )
    SRC="'eth0'"
    DST="'"$IFACE"'"
    sed -i "s/$SRC/$DST/" $CONFIG
  fi

  cd $CORDDIR/build
  vagrant plugin install vagrant-libvirt --plugin-version 0.0.35
  vagrant plugin install vagrant-mutate
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
    sudo mkdir -p /mnt/extra/docker
    sudo mkdir -p /mnt/extra/docker-registry
    [ ! -e /var/lib/libvirt/images ] && sudo ln -s /mnt/extra/libvirt_images /var/lib/libvirt/images
    [ ! -e /var/lib/docker ] && sudo ln -s /mnt/extra/docker /var/lib/docker
    [ ! -e /docker-registry ] && sudo ln -s /mnt/extra/docker-registry /docker-registry

    cd $CORDDIR/build
    SRC="#- 'on_cloudlab=True'"
    DST="- 'on_cloudlab=True'"
    sed -i "s/$SRC/$DST/" config/cord_in_a_box.yml
  fi
}

function unfortunate_hacks() {
  cd $CORDDIR/build

  # Allow compute nodes to PXE boot from mgmtbr
  sed -i "s/@type='udp']/@type='udp' or @type='bridge']/" \
    ~/.vagrant.d/gems/gems/vagrant-libvirt-0.0.35/lib/vagrant-libvirt/action/set_boot_order.rb
}

function corddev_up() {
  cd $CORDDIR/build

  sudo su $USER -c 'vagrant up corddev --provider libvirt'

  # This is a workaround for a weird issue with ARP cache timeout breaking 'vagrant ssh'
  # It allows SSH'ing to the machine via 'ssh corddev'
  sudo su $USER -c "grep corddev $SSHCONFIG || vagrant ssh-config corddev >> $SSHCONFIG"
}

function install_head_node() {
  cd $CORDDIR/build

  # Network setup to install physical server as head node
  BRIDGE=$( route -n | grep 10.100.198.0 | awk '{print $8}' )
  ip addr list dev $BRIDGE | grep 10.100.198.201 || sudo ip addr add dev $BRIDGE 10.100.198.201
  ifconfig mgmtbr || sudo brctl addbr mgmtbr
  sudo ifconfig mgmtbr 10.1.0.1/24 up

  # SSH config saved earlier allows us to connect to VM without running 'vagrant'
  scp ~/.ssh/id_rsa* corddev:.ssh
  ssh corddev "cd /cord/build; ./gradlew fetch"
  ssh corddev "cd /cord/build; ./gradlew buildImages"
  ssh corddev "cd /cord/build; ./gradlew -PdeployConfig=$VMDIR/$CONFIG -PtargetReg=10.100.198.201:5000 publish"
  ssh corddev "cd /cord/build; ./gradlew -PdeployConfig=$VMDIR/$CONFIG deploy"

  # SSH config was overwritten by the deploy step
  # Will go away when head node runs in 'prod' VM
  sudo su $USER -c "grep corddev $SSHCONFIG || vagrant ssh-config corddev >> $SSHCONFIG"
}

function set_up_maas_user() {
  # Set up MAAS user to restart nodes via libvirt
  sudo mkdir -p /home/maas
  sudo chown maas:maas /home/maas
  sudo chsh -s /bin/bash maas
  sudo adduser maas libvirtd

  sudo su maas -c 'cp ~/.ssh/id_rsa.pub ~/.ssh/authorized_keys'
}

function add_compute_node() {
  cd $CORDDIR/build
  sudo su $USER -c 'vagrant up compute_node --provider libvirt'

  # Change MAC address of bridge to match cord-pod service profile
  # This change won't survive a reboot
  BRIDGE=$( route -n | grep 10.6.1.0 | awk '{print $8}' )
  sudo ifconfig $BRIDGE hw ether 02:42:0a:06:01:01

  # Add gateway IP addresses to $BRIDGE for vsg and exampleservice tests
  # This change won't survive a reboot
  sudo ip address add 10.6.1.129 dev $BRIDGE
  sudo ip address add 10.6.1.193 dev $BRIDGE

  # Sign into MAAS
  KEY=$(sudo maas-region-admin apikey --username=cord)
  maas login cord http://localhost/MAAS/api/1.0 $KEY

  NODEID=$(maas cord nodes list|jq -r '.[] | select(.status == 0).system_id')
  until [ "$NODEID" ]; do
    echo "Waiting for the compute node to transition to NEW state"
    sleep 15
    NODEID=$(maas cord nodes list|jq -r '.[] | select(.status == 0).system_id')
  done

  # Add remote power state
  maas cord node update $NODEID power_type="virsh" \
    power_parameters_power_address="qemu+ssh://maas@localhost/system" \
    power_parameters_power_id="build_compute_node"

  STATUS=$(sudo /usr/local/bin/get-node-prov-state |jq ".[] | select(.id == \"$NODEID\").status")
  until [ "$STATUS" == "2" ]; do
    if [ "$STATUS" == "3" ]; then
      echo "*** [WARNING] Possible error in node provisioning process"
      echo "*** [WARNING] Check /etc/maas/ansible/logs/$NODEID.log"
    fi
    echo "Waiting for the compute node to be fully provisioned"
    sleep 60
    STATUS=$(sudo /usr/local/bin/get-node-prov-state |jq ".[] | select(.id == \"$NODEID\").status")
  done

  echo ""
  echo "compute_node is fully provisioned!"
}

function run_e2e_test () {
  cd $CORDDIR/build

  # User has been added to the libvirtd group, but su $USER to be safe
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

while getopts "b:cdhst" opt; do
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
      echo "    $0 -s             run initial setup phase only (don't start building CORD)"
      echo "    $0 -t             do install, bring up cord-pod configuration, run E2E test"
      exit 0
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

set -e

bootstrap
cloudlab_setup
unfortunate_hacks
corddev_up

if [[ $SETUP_ONLY -ne 0 ]]
then
  echo "Finished build environment setup, exiting..."
  exit 0
fi

install_head_node
set_up_maas_user
add_compute_node

if [[ $RUN_TEST -eq 1 ]]
then
  run_e2e_test
fi

if [[ $DIAGNOSTICS -eq 1 ]]
then
  run_diagnostics
fi

exit 0
