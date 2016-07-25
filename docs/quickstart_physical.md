# CORD Quick Start Guide using Physical Nodes

This guide is meant to enable the user to utilize the artifacts of this
repository to to deploy CORD on to a physical hardware rack. The artifacts in
this repository will deploy CORD against a standard physical rack wired
according to the **best practices** as defined in this document.

**NOTE:** *If you are new to CORD, you should start by bringing up a development
POD on a single physical server to get familiar with the CORD deployment
process.  Instructions to do so are in [quickstart.md](./quickstart.md).*

## Physical configuration
![Physical Hardware Connectivity](images/physical.png)

As depicted in the diagram above the base model for the CORD POD deployment
contains:
- 4 OF switches comprising the leaf - spine fabric utilized for data traffic
- 4 compute nodes with with 2 40G ports and 2 1G ports
- 1 top of rack (TOR) switch utilized for management communications

The best practices in terms of connecting the components of the CORD POD
include:
- Leaf nodes are connected to the spines nodes starting at the highest port
number on the leaf.
- For a given leaf node, its connection to the spine nodes terminate on the
same port number on each spine.
- Leaf *n* connections to spine nodes terminate at port *n* on each spine
node.
- Leaf spine switches are connected into the management TOR starting from the
highest port number.
- Compute nodes 40G interfaces are named *eth0* and *eth1*.
- Compute nodes 10G interfaces are named *eth2* and *eth3*.
- Compute node *n* is connected to the management TOR switch on port *n*,
egressing from the compute node at *eth2*.
- Compute node *n* is connected to its primary leaf, egressing at *eth0* and terminating on the leaf at port *n*.
- Compute node *n* is connected to its secondary leaf, egressing at *eth1* and
terminating on the leaf at port *n*.
- *eth3* on the head node is the uplink from the POD to the Internet.

The following assumptions are made about the phyical CORD POD being deployed:
- The leaf - spine switchs are Accton 6712s
- The compute nodes are using 40G Intel NIC cards
- The compute node that is to be designated the *head node* has
Ubuntu 14.04 LTS installed.

**Prerequisite: Vagrant is installed and operationally.**
**Note:** *This quick start guide has only been tested against Vagrant and
VirtualBox, specially on MacOS.*

## Bootstrap the Head Node
The head node is the key to the physical deployment of a CORD POD. The
automated deployment of the physical POD is designed such that the head node is
manually deployed, with the aid of automation tools, such as Ansible and from
this head node the rest of the POD deployment is automated.

The head node can be deployed either from a node outside the CORD POD or by
deploying from the head to the head node. The procedure in each scenario is
slightly different because during the bootstrapping of the head node it is
possible that the interfaces needed to be renamed and the system to be
rebooted. This guide assumes that the head node is being bootstrapped from a
host outside of the POD (OtP).

## Clone the Repository
To clone the repository, on your OtP build host issue the `git` command:
```
git clone http://gerrit.opencord.org/cord
```

### Complete
When this is complete, a listing (`ls`) of this directory should yield output
similar to:
```
ls
LICENSE.txt        ansible/           components/        gradle/            gradlew.bat        utils/
README.md          build.gradle       config/            gradle.properties  scripts/
Vagrantfile        buildSrc/          docs/              gradlew*           settings.gradle
```
## Create the Development Machine

The development environment is required for the tasks in this repository.
This environment leverages [Vagrant](https://www.vagrantup.com/docs/getting-started/)
to install the tools required to build and deploy the CORD software.

To create the development machine the following  Vagrant command can be
used. This will create an Ubuntu 14.04 LTS based virtual machine and install
some basic required packages, such as Docker, Docker Compose, and
Oracle Java 8.
```
vagrant up corddev
```
**NOTE:** *It may takes several minutes for the first command `vagrant up
corddev` to complete as it will include creating the VM as well as downloading
and installing various software packages.*

### Complete

Once the Vagrant VM is created and provisioned, you will see output ending
with:
```
==> corddev: PLAY RECAP *********************************************************************
==> corddev: localhost                  : ok=29   changed=25   unreachable=0    failed=0
==> corddev: Configuring cache buckets...
```

## Connect to the Development Machine
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
in the Vagrant machine that will automatically download and install `gradle`.
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

### Complete
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
The commands to deploy the POD can be customized via a *deployment configuration
file*. The file is in [YAML](http://yaml.org/).

To construct a configuration file for yoru physical POD you should copy the
sample deployment configuration found in `config/sample.yml` and modify the
values to fit your physical deployment.

## Prime the Target server
The target server is the server that will assume the role of the head node in
the cord POD. Priming this server consists of deploying some base software that
is required to deploy the base software, such as a docker registry. Having the
docker registry on the target server allows the deployment process to push
images to the target server that are used in the reset of the process, thus
making the head node a self contained deployment.
```
./gradlew -PdeployConfig=config/podX.yml prime
```

### Complete
Once the `prime` command successfully runs this task is complete. When this
step is complete a Docker registry and Docker registry mirror. It can be
verified that these are running by using the `docker ps` command.
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
./gradlew -PtargetReg=<head-node-ip-address>:5000 publish
```

### Complete
Once the `publish` command successfully runs this task is complete. When this
step is complete it can be verified by performing a query on the target
server's Docker registry using the following command on the development
machine.
```
curl -sS http://head-node-ip-address:5000/v2/_catalog | jq .
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
can be viewed by browsing to the target machine using a URL of the form
`http://head-node-ip-address/MAAS`.

After the `deployBase` command install `MAAS`, it initiates the download of
an Ubuntu 14.04 boot image that will be used to boot the other POD servers.
This download can take some time and the process cannot continue until the
download is complete. The status of the download can be verified through
the UI by visiting the URL `http://head-node-ip-address/MAAS/images/`,
or via the command line from head node via the following commands:
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

## Booting Compute Nodes

### Network configuration
The proposed configuration for a CORD POD is has the following network configuration on the head node:

   - eth0 / eth1 - 40G interfaces, not relevant for the test environment.
   - eth2 - the interface on which the head node supports PXE boots and is an internally interface to which all
   the compute nodes connected
   - eth3 - WAN link. the head node will NAT from eth2 to eth3
   - mgmtbr - Not associated with a physical network and used to connect in the VM created by the openstack
   install that is part of XOS

The Ansible scripts configure MAAS to support DHCP/DNS/PXE on the eth2 and mgmtbr interfaces.

Once it has been verified that the ubuntu boot image has been downloaded the
compute nodes may be PXE booted.

**Note:** *In order to ensure that the compute node PXE boot the bios settings
may have to be adjusted. Additionally, the remote power management on the
compute nodes must be enabled.*

The compute node will boot, register with MAAS, and then be shut off. After this
is complete an entry for the node will be in the MAAS UI at
`http://head-node-ip-address/MAAS/#/nodes`. It will be given a random hostname
made up, in the Canonical way, of a adjective and an noun, such as
`popular-feast.cord.lab`. *The name will be different for every deployment.* The
new node will be in the `New` state.

As the machines boot they should be automatically transitioned from `New`
through the states of `Commissioning` and `Acquired` to `Deployed`.

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

# Booting OpenFlow switches
Once the compute nodes have begun their boot process you may also boot the
switches that support the leaf spine fabric. These switches should ONIE install
boot and download their boot image from MAAS.

### Complete
This step is complete when the command completes successfully. You can verify
the provisioning of the false switch by querying the provisioning service
using curl.
```
curl -sS http://$(docker inspect --format '{{.NetworkSettings.Networks.maas_default.IPAddress}}' provisioner):4243/provision/ | jq '[.[] | { "status": .status, "name": .request.Info.name, "message": .message}]'
[
  {
    "message": "",
    "name": "leaf-1",
    "status": 2
  },
  {
    "message": "",
    "name": "leaf-2",
    "status": 2
  },
  {
    "message": "",
    "name": "spine-1",
    "status": 2
  },
  {
    "message": "",
    "name": "spine-2",
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
