# Operating CORD in China

Different community members reported problems operating CORD in China. This section provides a practical guide and some suggestions on how to install the main platform, the use cases, as well as how to manage them after their setup.

# Install the CORD platform (4+)
The guide explains how to install the CORD platform in China, providing some specific suggestions and customizations.

> Note: the guide assumes you've already read the main [CORD installation guide](install_physical.md), that you've understood the hardware and software requirements, and that you're well aware of how the standard installation process works.

## Update Ubuntu repositories
We know that the default Ubuntu repositories are quite slow in China. The following repository should work faster:

```
https://mirrors.tuna.tsinghua.edu.cn/help/ubuntu/
```

Update your Ubuntu repository, both on the development machine and on the head node.

## Prepare the dev node machine

By default, CORD uses an [automated script](quickstarts.md#pod-quickstarts) to prepare the development machine. Unfortunately, the script won't work in China, since the standard Vagrant repositories are not reachable.

As a work-around, you can execute some manual commands. Copy and paste to your dev node the following:

Install essential software
```
sudo apt-get update &&
sudo apt-get -y install apt-transport-https build-essential curl git python-dev python-netaddr python-pip software-properties-common sshpass qemu-kvm libvirt-bin libvirt-dev nfs-kernel-server &&
```

Install Ansible and related software
```
sudo apt-add-repository -y ppa:ansible/ansible &&
sudo apt-get update &&
sudo apt-get install -y ansible &&
sudo pip install gitpython graphviz
```

Install Vagrant and related plugins
```
curl -o /tmp/vagrant.deb https://releases.hashicorp.com/vagrant/1.9.3/ vagrant_1.9.3_x86_64.deb &&
sudo dpkg -i /tmp/vagrant.deb &&
vagrant plugin list | grep -q vagrant-libvirt || vagrant plugin install vagrant-libvirt --plugin-version 0.0.35 &&
vagrant plugin list | grep -q vagrant-mutate || vagrant plugin install vagrant-mutate &&
vagrant plugin list | grep -q vagrant-hosts || vagrant plugin install vagrant-hosts &&
```

Download Vagrant VMs and mutate it to be used with Libvirt
```
wget https://github.com/opencord/platform-install/releases/download/vms/trusty-server-cloudimg-amd64-vagrant-disk1.box &&
vagrant box add ubuntu/trusty64 trusty-server-cloudimg-amd64-vagrant-disk1.box &&
vagrant mutate ubuntu/trusty64 libvirt --input-provider virtualbox
```

Install repo
```
curl -o /tmp/repo 'https://gerrit.opencord.org/gitweb?p=repo.git;a=blob_plain;f=repo;hb=refs/heads/stable' &&
echo "$REPO_SHA256SUM  /tmp/repo" | sha256sum -c - &&
sudo mv /tmp/repo /usr/local/bin/repo &&
sudo chmod a+x /usr/local/bin/repo
```

> Note: *repo* is a tool from Google, that CORD uses to automatically manage multiple git repositories used in the project together. The original version of repo connects to Google at every initialization to download some software. This special version will let you connect to ONF instead at every initialization.

## Download the CORD software

Before it wasn't possible to download directly the CORD repository using repo, since the tool was trying to connect at every initialization to Google to check for updates.
With the custom version (see above) this is not anymore an issue. You can now download the code as anyone else!

To download the code, follow the steps below:
```
git config --global user.name 'Test User' &&
git config --global user.email 'test@null.com' &&
git config --global color.ui false &&
repo init -u https://gerrit.opencord.org/manifest -b master
repo sync
```

> Warning: please, note that master is just an example. You can replace it with the branch you prefer.

From now on in the guide, the cord directory just extracted will be referenced as CORD_ROOT. The CORD_ROOT directory should be ~/cord.

## Replace google.com address with opennetworking.org
The repository has been generally cleaned-up from references to Google to avoid issues. Anyway, there are still some portions of code referring to it. We suggest you to look carefully in the entire repositories and replace any google.com occurrence with opennetworking.org (or any other preferred address).

## Replace Google DNS
Google DNS won't work over there. Unfortunately, it is still the default for all CORD services. Look in the entire repository for all the occurrences of 8.8.8.8, 8.8.8.4, or 8.8.4.4, and replace them with your preferred DNS server.

## Replace Maven mirror
Maven is used to build ONOS apps. The default Maven mirror doesn't work. In CORD_ROOT/onos-apps/settings.xml, add:

```
<mirror>
    <id>nexus-aliyun</id>
    <mirrorOf>*</mirrorOf>
    <name>Nexus aliyun</name>
    <url>http://maven.aliyun.com/nexus/content/groups/public</url>
</mirror>
```

## Replace Docker mirror
The default Docker mirror won't work. Docker just opened a new mirror in China, which should be used instead.

Reference guide can be found at: <https://www.docker-cn.com/registry-mirror>
Set the option ```--registry-mirror=https://registry.docker-cn.com``` in the following files:
* CORD_ROOT/build/ansible/roles/docker/templates/docker.cfg
* CORD_ROOT/build/maas/roles/compute-node/tasks/main.yml

## Replace NPM mirrors

Add a line ```npm config set registry https://registry.npm.taobao.org``` just before the “npm install” command is invoked, in the following files:
* CORD_ROOT/orchestration/xos-gui/Dockerfile
* CORD_ROOT/orchestration/xos-gui/Dockerfile.xos-gui-extension- builder

Create a file named ```npmrc``` in ```CORD_ROOT/orchestration/xos-gui/``` and add the following content:

```
registry = https://registry.npm.taobao.org
sass-binary-site = http://npm.taobao.org/mirrors/node-sass
phantomjs_cdnurl = https://npm.taobao.org/dist/phantomjs
```

Add the line ```COPY ${CODE_SOURCE}/npmrc /root/.npmrc``` to the following files, before the ```npm install``` command is invoked, and after the ```CODE_SOURCE``` variable is defined:
* CORD_ROOT/orchestration/xos-gui/Dockerfile
* CORD_ROOT/orchestration/xos-gui/Dockerfile.xos-gui-extension-builder

## Fix Google Maps for China
This is specific to ```E-CORD```, which uses Google Maps to visualize where Central Offices are located. Default Google Maps APIs are not available from China.
To fix this, replace

```
<div map-lazy-load="https://maps.googleapis.com/maps/api/js?key={API_KEY}">
```

with

```
<div map-lazy-load="http://maps.google.cn/maps/api/js?key={API_KEY}">
```

in

```
CORD_ROOT/orchestration/xos_services/vnaas/xos/gui/src/app/components/vnaasMap.component.html
```

## You're all set!

You're finally ready to deploy CORD following the standard installation procedure described [here](install_physical.md)!

# Developing for CORD

Now that repo issues have been solved, you can start developing for CORD also from China, and go through the default developer workflow described [here](develop.md). Happy coding!

# Mailing lists

CORD mailing lists are hosted on Google, but this doesn't mean you can't send and receive emails!

Mailing lists are:
* <cord-discuss@opencord.org>
* <cord-dev@opencord.org>

You don't need to join the mailing list to be able to write to it, but you need that in order to receive automated updates.
To subscribe to a mailing list, so to see emails from the rest of the community, send a blank email to ```NAME_OF_THE_ML+subscribe@opencord.org```, for example <cord-dev+subscribe@opencord.org>.
