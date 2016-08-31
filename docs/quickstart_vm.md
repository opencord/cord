# CORD Quick Start Guide using Virtual Machine Nodes

[*This description is for bringing up a CORD POD on virtual
machines on a single physical host. The purpose of this solution
is to give the user an experience of bring up a CORD on bare
metal.*]

This guide is meant to enable the user to quickly exercise the capabilities
provided by the artifacts of this repository. There are three high level tasks
that can be exercised:
   - Create development environment
   - Build and Publish Docker images that support bare metal provisioning
   - Deploy the bare metal provisioning capabilities to a virtual machine (head
       node) and PXE boot a compute node

**Prerequisite: Vagrant is installed and operationally.**
**Note:** *This quick start guide has only been tested against Vagrant and
VirtualBox, specially on MacOS.*

## Create Development Environment
The development environment is required for the other tasks in this repository.
The other tasks could technically be done outside this Vagrant based development
environment, but it would be left to the user to ensure connectivity and
required tools are installed. It is far easier to leverage the Vagrant based
environment.

## Install Repo

Make sure you have a bin directory in your home directory and that it is included in your path:

```
mkdir ~/bin
PATH=~/bin:$PATH
```

(of course you can put repo wherever you want)

Download the Repo tool and ensure that it is executable:

```
curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo
chmod a+x ~/bin/repo
```

## Clone the Repository
To clone the repository, on your OtP build host issue the `git` command:
```
mkdir opencord && cd opencord
repo init -u https://gerrit.opencord.org/manifest -b master -g build,onos
```

Fetch the opencord source code
```
repo sync
```

### Complete
When this is complete, a listing (`ls`) of this directory should yield output
similar to:
```
ls
build		onos-apps
```

### Create Development Machine and Head Node Production Server
To create the development machine the following single Vagrant command can be
used. This will create an Ubuntu 14.04 LTS based virtual machine and install
some basic required packages, such as Docker, Docker Compose, and
Oracle Java 8.
```
cd build
vagrant up corddev
```
**NOTE:** *It may have several minutes for the first command `vagrant up
corddev` to complete as it will include creating the VM as well as downloading
and installing various software packages.*

To create the VM that represents the POD head node the following vagrant
command can be used. This will create a basic Ubuntu 14.04 LTS server with
no additional software installed.
```
vagrant up prod
```

### Connect to the Development Machine
To connect to the development machine the following vagrant command can be used.
```
vagrant ssh corddev
```

Once connected to the Vagrant machine, you can find the deployment artifacts
in the `/cord` directory on the VM.
```
cd /cord
```

### Gradle
[Gradle](https://gradle.org/) is the build tool that is used to help
orchestrate the build and deployment of a POD. A *launch* script is included
in the vagrant machine that will automatically download and install `gradle`.
The script is called `gradlew` and the download / install will be invoked on
the first use of this script; thus the first use may take a little longer
than subsequent invocations and requires a connection to the internet.

### Complete
Once you have created and connected to the development environment this task is
complete. The `cord` repository files can be found on the development machine
under `/cord`. This directory is mounted from the host machine so changes
made to files in this directory will be reflected on the host machine and
vice-versa.

## Fetch
The fetching phase of the deployment pulls Docker images from the public
repository down to the local machine as well as clones any `git` submodules
that are part of the project. This phase can be initiated with the following
command:
```
./gradlew fetch
```

### complete
Once the fetch command has successfully been run, this step is complete. After
this command completes you should be able to see the Docker images that were
downloaded using the `docker images` command on the development machine:
```
docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
python              2.7-alpine          836fa7aed31d        5 days ago          56.45 MB
consul              <none>              62f109a3299c        2 weeks ago         41.05 MB
registry            2.4.0               8b162eee2794        9 weeks ago         171.1 MB
abh1nav/dockerui    latest              6e4d05915b2a        19 months ago       469.5 MB
```

## Build Images
Bare metal provisioning leverages utilities built and packaged as Docker
container images. These utilities are:

   - cord-maas-bootstrap - (directory: `bootstrap`) run at MAAS installation
   time to customize the MAAS instance via REST interfaces
   - cord-maas-automation - (directory: `automation`) daemon on the head node to
   automate PXE booted servers through the MAAS bare metal deployment work flow
   - cord-maas-switchq - (directory: `switchq`) daemon on the head
   node that watches for new switches being added to the POD and triggers
   provisioning when a switch is identified (via the OUI on MAC address).
   - cord-maas-provisioner - (directory: `provisioner`) daemon on the head node
   to managing the execution of ansible playbooks against switches and compute
   nodes as they are added to the POD.
   - cord-ip-allocator - (directr: `ip-allocator`) daemon on the head node used
   to allocate IP address for the fabric interfaces.
   - cord-dhcp-harvester - (directory: `harvester`) run on the head node to
   facilitate CORD / DHCP / DNS integration so that all hosts can be resolved
   via DNS
   - opencord/mavenrepo
   - cord-test/nose
   - cord-test/quagga
   - cord-test/radius
   - onosproject/onos

The images can be built by using the following command. This will build all
the images.
```
./gradlew buildImages
```

**NOTE:** *The first time you run `./gradlew` it will download from the Internet
the `gradle` binary and install it locally. This is a one time operation.*

### Complete
Once the `buildImages` command successfully runs this task is complete. The
CORD artifacts have been built and the Docker images can be viewed by using the
`docker images` command on the development machine.
```
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.ID}}'
REPOSITORY               TAG                 SIZE                IMAGE ID
cord-maas-switchq        latest              781 MB              4736cc8c4f71
cord-provisioner         latest              814.6 MB            50ab479e4b52
cord-dhcp-harvester      latest              60.67 MB            88f900d74f19
cord-maas-bootstrap      latest              367.5 MB            19bde768c786
cord-maas-automation     latest              366.8 MB            1e2ab7242060
cord-ip-allocator        latest              324.3 MB            f8f2849107f6
opencord/mavenrepo       latest              434.2 MB            9d1ad7214262
cord-test/nose           latest              1.028 GB            67b996f2ad19
cord-test/quagga         latest              454.4 MB            b46f7dd20bdf
cord-test/radius         latest              312.1 MB            e09d78aef295
onosproject/onos         <none>              825.6 MB            309088c647cf
python                   2.7-alpine          56.45 MB            836fa7aed31d
golang                   1.6-alpine          282.9 MB            d688f409d292
golang                   alpine              282.9 MB            d688f409d292
ubuntu                   14.04               196.6 MB            38c759202e30
consul                   <none>              41.05 MB            62f109a3299c
nginx                    latest              182.7 MB            0d409d33b27e
registry                 2.4.0               171.1 MB            8b162eee2794
swarm                    <none>              19.32 MB            47dc182ea74b
nginx                    <none>              182.7 MB            3c69047c6034
hbouvier/docker-radius   latest              280.9 MB            5d5d3c0a91b0
abh1nav/dockerui         latest              469.5 MB            6e4d05915b2a
```
**NOTE:** *Not all the above Docker images were built by the `buildImages`
command. Some of them, list golang, are used as a base for other Docker
images; and some, like `abh1nav/dockerui` were downloaded when the development
machine was created with `vagrant up`.*

## Deployment Configuration File
The commands to deploy the POD can be customized via a *deployment
configuration file*. The file is in [YAML](http://yaml.org/). For
the purposes of the quick start using vagrant VMs for the POD nodes a
deployment configuration file has been provide in
[`config/default.yml`](config/default.yml). This default configuration
specifies the target server as the vagrant machine named `prod` that was
created earlier.

## Prime the Target server
The target server is the server that will assume the role of the head node in
the cord POD. Priming this server consists of deploying some base software that
is required to deploy the base software, such as a docker registry. Having the
docker registry on the target server allows the deployment process to push
images to the target server that are used in the reset of the process, thus
making the head node a self contained deployment.
```
./gradlew prime
```

### Complete
Once the `prime` command successfully runs this task is complete. When this
step is complete a Docker registry and Docker registry mirror. It can be
verified that these are running by using the `docker ps` command on the
producation head node VM.
```
docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Command}}\t{{.CreatedAt}}'
CONTAINER ID        IMAGE               COMMAND                  CREATED AT
5f1cbebe7e61        registry:2.4.0      "/bin/registry serve "   2016-07-13 17:03:08 +0000 UTC
6d3a911e5323        registry:2.4.0      "/bin/registry serve "   2016-07-13 17:03:08 +0000 UTC
```

## Publish
Publishing consists of *pushing* the build docker images to the Docker
repository on the target head node. This step can take a while as it has to
transfer all the image from the development machine to the target head node.
This step is started with the following command:
```
./gradlew -PtargetReg=10.100.198.201:5000 publish
```

### Complete
Once the `publish` command successfully runs this task is complete. When this
step is complete it can be verified by performing a query on the target
server's Docker registry using the following command on the development
machine.
```
curl -sS http://10.100.198.201:5000/v2/_catalog | jq .
{
  "repositories": [
    "consul",
    "cord-dhcp-harvester",
    "cord-ip-allocator",
    "cord-maas-automation",
    "cord-maas-bootstrap",
    "cord-maas-switchq",
    "cord-provisioner",
    "mavenrepo",
    "nginx",
    "onosproject/onos",
    "swarm"
  ]
}
```

## Deploy Bare Metal Provisioning Capabilities
There are three parts to deploying bare metal: deploying the head node PXE
server (`MAAS`), PXE booting a compute node, and post deployment provisioning
of the compute node. These tasks are accomplished utilizing additionally
Vagrant machines as well as executing `gradle` tasks in the Vagrant
development machine.

### VirtualBox Power Management
The default MAAS deployment does not support power management for virtual box
based hosts. As part of the MAAS installation support was added for power
management, but it does require some additional configuration. This additional
configuration is detailed at the end of this document, but is mentioned here
because when deploying the head node an additional parameter must be set. This
parameter specifies the username on the host machine that should be used when
SSHing from the head node to the host machine to remotely execute the
`vboxmanage` command. This is typically the username used when logging into your
laptop or desktop development machine. This value is set by editing the
`config/default.yml` file and replacing the default value of
`seedServer.power_helper_user` with the approriate username. The default value
is `cord`

### Deploy MAAS
Canonical MAAS provides the PXE and other bare metal provisioning services for
CORD and will be deployed on the head node.
```
./gradlew deployBase
```

This task can take some time so be patient. It should complete without errors,
so if an error is encountered something went horrible wrong (tm).

### Complete
This step is complete when the command successfully runs. The Web UI for MAAS
can be viewed by browsing to the vagrant machine named `prod`. Because this
machine is on a host internal network it can't be directly reached from the
host machine, typically your laptop. In order to expose the UI, from the VM host
machine you will issue the following command:
```
vagrant ssh prod -- -L 8080:localhost:80
```
This command will create a SSH tunnel from the VM host machine to the head
node so that from the VM host you can view the MAAS UI by visiting the URL
`http://localhost:8080/MAAS`. The default authentication credentials are a
username of `cord` and a password of `cord`.

After the `deployBase` command install `MAAS`, it initiates the download of
an Ubuntu 14.04 boot image that will be used to boot the other POD servers.
This download can take some time and the process cannot continue until the
download is complete. The status of the download can be verified through
the UI by visiting the URL `http://localhost:8888/MAAS/images/`, or via the
command line from head node via the following commands:
```
APIKEY=$(sudo maas-region-admin apikey --user=cord)
maas login cord http://localhost/MAAS/api/1.0 "$APIKEY"
maas cord boot-resources read | jq 'map(select(.type != "Synced"))'
```

It the output of of the above commands is not a empty list, `[]`, then the
images have not yet been completely downloaded. depending on your network speed
this could take several minutes. Please wait and then attempt the last command
again until the returned list is empty, `[]`. When the list is empty you can
proceed.

Browse around the UI and get familiar with MAAS via documentation at `http://maas.io`

## Deploy XOS
XOS provides service provisioning and orchestration for the CORD POD. To deploy
XOS to the head node use the following command:
```
./gradlew deployPlatform
```

This task can take some time so be patient. It should complete without errors,
so if an error is encountered something went horrible wrong (tm).

### Complete
This step is complete when the command successfully runs. The deployment of XOS
includes a deployment of Open Stack.

## Create and Boot Compute Node
The sample vagrant VM based POD is configured to support the creation of 3
compute nodes. These nodes will PXE boot from the head node and are created
using the `vagrant up` command as follows:
```
vagrant up compute_node1
vagrant up compute_node2
vagrant up compute_node3
```
**NOTE:** *This task is executed on your host machine and not in the
development virtual machine*

When starting the compute node VMs the console (UI) for each will be displayed
so you are able to watch the boot process if you like.

As vagrant starts these machines, you will see the following error:
```
==> compute_node1: Waiting for machine to boot. This may take a few minutes...
The requested communicator 'none' could not be found.
Please verify the name is correct and try again.
```

This error is normal and is because vagrant attempts to `SSH` to a server
after it is started. However, because the process is PXE booting these servers
this is not possible. To work around (with) vagrant the vagrant `communicator`
setting for each of the compute nodes is set to "none", thus vagrant complains,
but the machines will PXE boot.

The compute node VM will boot, register with MAAS, and then be shut off. After
this is complete an entry for the node will be in the MAAS UI at
`http://localhost:8888/MAAS/#/nodes`. It will be given a random hostname made
up, in the Canonical way, of a adjective and an noun, such as
`popular-feast.cord.lab`. *The name will be different for every deployment.*
The new node will be in the `New` state.

If you have properly configured power management for virtualbox (see below) the
host will be automatically transitioned from `New` through the states of
`Commissioning` and `Acquired` to `Deployed`.

### Post Deployment Provisioning of the Compute Node
Once the node is in the `Deployed` state, it will be provisioned for use in a
CORD POD by the execution of an `Ansible` playbook.

### Complete
Once the compute node is in the `Deployed` state and post deployment provisioning on the compute node is
complete, this task is complete.

Logs of the post deployment provisioning of the compute nodes can be found
in `/etc/maas/ansible/logs` on the head node.

Assitionally, the post deployment provisioning of the compute nodes can be
queried from the provision service using curl
```
curl -sS http://$(docker inspect --format '{{.NetworkSettings.Networks.maas_default.IPAddress}}' provisioner):4243/provision/ | jq '[.[] | { "status": .status, "name": .request.Info.name}]'
[
  {
    "message": "",
    "name": "steel-ghost.cord.lab",
    "status": 2
  },
  {
    "message": "",
    "name": "feline-shirt.cord.lab",
    "status": 2
  },
  {
    "message": "",
    "name": "yellow-plot.cord.lab",
    "status": 2
  }
]
```
In the above a "status" of 2 means that the provisioning is complete. The
other values that status might hold are:
   - `0` - Pending, the request has been accepted by the provisioner but not yet
   started
   - `1` - Running, the request is being processed and the node is being
   provisioned
   - `2` - Complete, the provisioning has been completed successfully
   - `3` - Failed, the provisioning has failed and the `message` will be
   populated with the exit message from provisioning.

## Create and Boot False switch
The VM based deployment includes the definition of a vagrant machine that will
exercise some of the automation used to boot OpenFlow switches in the CORD POD.
It accomplishes this by forcing the MAC address on the vagrant VM to be a MAC
that is recognized as a supported OpenFlow switch.

The POD automation will thus perform post provisioning on the this VM to
download and install software to the device. This vagrant VM can be created
with the following command:
```
vagrant up switch
```

### Complete
This step is complete when the command completes successfully. You can verify
the provisioning of the false switch by querying the provisioning service
using curl.
```
curl -sS http://$(docker inspect --format '{{.NetworkSettings.Networks.maas_default.IPAddress}}' provisioner):4243/provision/cc:37:ab:00:00:01 | jq '[{ "status": .status, "name": .request.Info.name, "message": .message}]'
[
  {
    "message": "",
    "name": "fakeswitch",
    "status": 2
  }
]
```
In the above a "status" of 2 means that the provisioning is complete. The
other values that status might hold are:
   - `0` - Pending, the request has been accepted by the provisioner but not yet
   started
   - `1` - Running, the request is being processed and the node is being
   provisioned
   - `2` - Complete, the provisioning has been completed successfully
   - `3` - Failed, the provisioning has failed and the `message` will be
   populated with the exit message from provisioning.

#### Virtual Box Power Management
Virtual box power management is implemented via helper scripts that SSH to the
virtual box host and execute `vboxmanage` commands. For this to work The scripts
must be configured with a username and host to utilize when SSHing and that
account must allow SSH from the head node guest to the host using SSH keys such
that no password entry is required.

To enable SSH key based login, assuming that VirtualBox is running on a Linux
based system, you can copy the MAAS ssh public key from
`/var/lib/maas/.ssh/id_rsa.pub` on the head known to your accounts
`authorized_keys` files. You can verify that this is working by issuing the
following commands from your host machine:
```
vagrant ssh headnode
sudo su - maas
ssh yourusername@host_ip_address
```

If you are able to accomplish these commands the VirtualBox power management should operate correctly.
