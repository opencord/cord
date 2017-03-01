#!/usr/bin/env bash

set -e -x

CORDDIR=~/cord
VMDIR=/cord/build/
CONFIG=config/cord_in_a_box.yml
SSHCONFIG=~/.ssh/config

# For CORD version
REPO_BRANCH="master"
VERSION_STRING="CiaB development version"

function finish {
    EXIT=$?
    set +x
    python $CORDDIR/build/elk-logger/mixpanel FINISH-$EXIT --finish
}

function add_box() {
  vagrant box list | grep $1 | grep virtualbox || vagrant box add $1
  vagrant box list | grep $1 | grep libvirt || vagrant mutate $1 libvirt --input-provider virtualbox
}

function run_stage {
    cd $CORDDIR
    python build/elk-logger/mixpanel $1-start

    echo "==> "$1": Starting"
    $1
    echo "==> "$1": Complete"

    cd $CORDDIR
    python build/elk-logger/mixpanel $1-end
}

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
  echo "Generating build id"
  dd bs=18 count=1 if=/dev/urandom | base64 | tr +/ _. > /tmp/cord-build
  cd ~
  sudo apt-get update
  [ -e vagrant_1.8.5_x86_64.deb ] || wget https://releases.hashicorp.com/vagrant/1.8.5/vagrant_1.8.5_x86_64.deb
  dpkg -l vagrant || sudo dpkg -i vagrant_1.8.5_x86_64.deb
  sudo apt-get -y install qemu-kvm libvirt-bin libvirt-dev curl nfs-kernel-server git build-essential python-pip
  sudo pip install pyparsing python-logstash mixpanel

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

    repo init -u https://gerrit.opencord.org/manifest -b $REPO_BRANCH -g build,onos,orchestration,voltha
    repo sync

    # check out gerrit branches using repo
    for gerrit_branch in ${GERRIT_BRANCHES[@]}; do
      echo "checking out opencord gerrit branch: $gerrit_branch"
      repo download ${gerrit_branch/:/ }
    done
  fi

  exec > >(tee -i $CORDDIR/install.out)
  exec 2>&1

  cd $CORDDIR/build
  vagrant plugin list | grep vagrant-libvirt || vagrant plugin install vagrant-libvirt --plugin-version 0.0.35
  vagrant plugin list | grep vagrant-mutate || vagrant plugin install vagrant-mutate
  add_box ubuntu/trusty64

  # Start tracking failures from this point
  trap finish EXIT

}

function cloudlab_setup() {

  # The watchdog will sometimes reset groups, turn it off
  if [ -e /usr/local/etc/emulab/watchdog ]
  then
    sudo /usr/bin/perl -w /usr/local/etc/emulab/watchdog stop
    sudo mv /usr/local/etc/emulab/watchdog /usr/local/etc/emulab/watchdog-disabled
  fi

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

function elk_up() {
  cd $CORDDIR/build

  sudo su $USER -c 'vagrant up elastic --provider libvirt'

  # This is a workaround for a weird issue with ARP cache timeout breaking 'vagrant ssh'
  # It allows SSH'ing to the machine via 'ssh corddev'
  sudo su $USER -c "vagrant ssh-config elastic > $SSHCONFIG"

  cd $CORDDIR
  if [ ! -f /tmp/elk-patch-applied ]; then
    touch /tmp/elk-patch-applied
    sh build/scripts/repo-apply.sh build/elk-logger/elk-ciab.diff
  fi

  sudo chmod +x build/elk-logger/logstash_tail
  build/elk-logger/logstash_tail --file install.out --hostport 10.100.198.222:5617 & 
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
  ssh corddev "cd /cord/build; ./gradlew -PdeployConfig=$VMDIR/$CONFIG fetch"
  ssh corddev "cd /cord/build; ./gradlew -PdeployConfig=$VMDIR/$CONFIG buildImages"
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

function turn_off_learning () {
  NET=$1
  BRIDGE=`sudo virsh net-info $NET|grep "Bridge:"|awk '{print $2}'`
  sudo brctl setageing $BRIDGE 0
  sudo brctl stp $BRIDGE off
}

function leaf_spine_up() {
  cd $CORDDIR/build

  if [[ $FABRIC -ne 0 ]]
  then
      sudo su $USER -c "FABRIC=$FABRIC vagrant up leaf-1 leaf-2 spine-1 spine-2 --provider libvirt"
  else
      # Linux bridging seems to be having issues with two spine switches
      sudo su $USER -c "FABRIC=$FABRIC vagrant up leaf-1 leaf-2 spine-1 --provider libvirt"
  fi

  # Turn off MAC learning on "links" -- i.e., bridges created by libvirt.
  # Without this, sometimes packets are dropped because the bridges
  # think they are not local -- this needs further investigation.
  # A better solution might be to replace the bridges with UDP tunnels, but this
  # is not supported with the version of libvirt available on Ubuntu 14.04.
  turn_off_learning head-node-leaf-1
  turn_off_learning compute-node-1-leaf-1
  turn_off_learning compute-node-2-leaf-2
  turn_off_learning compute-node-3-leaf-2
  turn_off_learning leaf-1-spine-1
  turn_off_learning leaf-1-spine-2
  turn_off_learning leaf-2-spine-1
  turn_off_learning leaf-2-spine-2
}

function add_compute_node() {
  echo add_compute_node: $1 $2

  cd $CORDDIR/build
  sudo su $USER -c "vagrant up $1 --provider libvirt"

  # Set up power cycling for the compute node and wait for it to be provisioned
  ssh prod "cd /cord/build/ansible; ansible-playbook maas-provision.yml --extra-vars \"maas_user=maas vagrant_name=$2\""

  echo ""
  echo "$1 is fully provisioned!"
}

function initialize_fabric() {
  echo "Initializing fabric"
  ssh prod "cd /cord/build/platform-install; ansible-playbook -i /etc/maas/ansible/pod-inventory cord-refresh-fabric.yml"

  echo "Fabric ping test"
  ssh prod "cd /cord/build/platform-install; ansible-playbook -i /etc/maas/ansible/pod-inventory cord-fabric-pingtest.yml"
}

function run_e2e_test () {
  cd $CORDDIR/build

  # User has been added to the lbvirtd group, but su $USER to be safe
  ssh corddev "cd /cord/build; ./gradlew -PdeployConfig=$VMDIR/$CONFIG postDeployTests"
}

function run_diagnostics() {
  ssh corddev "cd /cord/build; ./gradlew -PdeployConfig=$VMDIR/$CONFIG PIrunDiag"
}

# Parse options
GERRIT_BRANCHES=
RUN_TEST=0
SETUP_ONLY=0
DIAGNOSTICS=0
CLEANUP=0
FABRIC=0
#By default, cord-in-a-box creates 1 compute node. If more than one compute is
#needed, use -n option
NUM_COMPUTE_NODES=1

while getopts "b:cdfhn:stv" opt; do
  case ${opt} in
    b ) GERRIT_BRANCHES+=("$OPTARG")
      ;;
    c ) CLEANUP=1
      ;;
    d ) DIAGNOSTICS=1
      ;;
    f ) FABRIC=1
      ;;
    h ) echo "Usage:"
      echo "    $0                install OpenStack and prep XOS and ONOS VMs [default]"
      echo "    $0 -b <project:changeset/revision>  checkout a changesets from gerrit. Can"
      echo "                      be used multiple times."
      echo "    $0 -c             cleanup from previous test"
      echo "    $0 -d             run diagnostic collector"
      echo "    $0 -f             use ONOS fabric (EXPERIMENTAL)"
      echo "    $0 -h             display this help message"
      echo "    $0 -n #           number of compute nodes to setup. Currently max 2 nodes can be supported"
      echo "    $0 -s             run initial setup phase only (don't start building CORD)"
      echo "    $0 -t             do install, bring up cord-pod configuration, run E2E test"
      echo "    $0 -v             print CiaB version and exit"
      exit 0
      ;;
    n ) NUM_COMPUTE_NODES=$OPTARG
      ;;
    s ) SETUP_ONLY=1
      ;;
    t ) RUN_TEST=1
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
  cleanup_from_previous_test
fi

echo ""
echo "Preparing to install $VERSION_STRING ($REPO_BRANCH branch)"
echo ""

bootstrap
run_stage cloudlab_setup
run_stage elk_up
run_stage vagrant_vms_up

if [[ $SETUP_ONLY -ne 0 ]]
then
  echo "Finished build environment setup, exiting..."
  exit 0
fi

run_stage install_head_node
run_stage set_up_maas_user
run_stage leaf_spine_up

if [[ $NUM_COMPUTE_NODES -gt 3 ]]
then
   echo "currently max only three compute nodes can be supported..."
   NUM_COMPUTE_NODES=3
fi

echo "==> Adding compute nodes: Starting"
for i in `seq 1 $NUM_COMPUTE_NODES`;
do
   echo adding the compute node: compute-node-$i
   add_compute_node compute-node-$i build_compute-node-$i
done
echo "==> Adding compute nodes: Complete"

# run diagnostics both before/after the fabric/e2e tests
if [[ $DIAGNOSTICS -eq 1 ]]
then
  run_diagnostics
fi


if [[ $FABRIC -ne 0 ]]
then
  run_stage initialize_fabric
fi

if [[ $RUN_TEST -eq 1 ]]
then
  run_stage run_e2e_test
fi

if [[ $DIAGNOSTICS -eq 1 ]]
then
  run_stage run_diagnostics
fi

exit 0
