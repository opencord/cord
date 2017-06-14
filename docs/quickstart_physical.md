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
- Compute nodes fabric interfaces (typically 40G or 10G) are named *eth0* and *eth1*.
- Compute nodes POD management interfaces (typically 1G) are named *eth2* and *eth3*.
- Compute node *n* is connected to the management TOR switch on port *n*,
egressing from the compute node at *eth2*.
- Compute node *n* is connected to its primary leaf, egressing at *eth0* and terminating on the leaf at port *n*.
- Compute node *n* is connected to its secondary leaf, egressing at *eth1* and
terminating on the leaf at port *n*.
- *eth3* on the head node is the uplink from the POD to the Internet.

The following assumptions are made about the phyical CORD POD being deployed:
- The leaf - spine switches are Accton 6712s
- The compute nodes are using 40G Intel NIC cards
- The compute node that is to be designated the *head node* has
**Ubuntu 14.04 LTS** installed. In addition, the user should have **password-less sudo permission**.

**Prerequisite: Vagrant is installed and operational.**
**Note:** *This quick start guide has only been tested against Vagrant and
VirtualBox, specially on MacOS.*

## Bootstrap the Head Node
The head node is the key to the physical deployment of a CORD POD. The
automated deployment of the physical POD is designed such that the head node is
manually deployed, with the aid of automation tools, such as Ansible and from
this head node the rest of the POD deployment is automated.

The head node is deployed from a host outside the CORD POD (OtP).

## Install Repo

Make sure you have a bin directory in your home directory and that it is
included in your path:

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
repo init -u https://gerrit.opencord.org/manifest -b master
```
**NOTE:** _In the example above the OpenCORD version clones was the `master`
branch of the source tree. If a different version is desired then `master`
should be replaced with the name of the desired version, `cord-2.0` for
example._

Fetch the opencord source code
```
repo sync
```

### Complete
When this is complete, a listing (`ls`) of this directory should yield output
similar to:
```
ls -F
build/         component/     incubator/     onos-apps/     orchestration/ test/
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
cd build
vagrant up corddev
```
**NOTE:** *The VM will consume 2G RAM and about 12G disk space. Make sure it can obtain
sufficient resources. It may takes several minutes for the first command
`vagrant up corddev` to complete as it will include creating the VM as well as
downloading and installing various software packages.*

### Complete

Once the Vagrant VM is created and provisioned, you will see output ending
with:
```
==> corddev: PLAY RECAP *********************************************************************
==> corddev: localhost                  : ok=29   changed=25   unreachable=0    failed=0
```
The important thing is that the *unreachable* and *failed* counts are both zero.

## Connect to the Development Machine
To connect to the development machine the following vagrant command can be used.
```
vagrant ssh corddev
```

Once connected to the Vagrant machine, you can find the deployment artifacts
in the `/cord` directory on the VM.
```
cd /cord/build
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
**NOTE:** *The first time you run `./gradlew` it will download the `gradle`
binary from the Internet and install it locally. This is a one time operation,
but may be time consuming depending on the speed of your Internet connection.*

### Complete
Once the fetch command has successfully been run, this step is complete. After
this command completes you should be able to see the Docker images that were
downloaded using the `docker images` command on the development machine:
```
docker images
REPOSITORY                  TAG                 IMAGE ID            CREATED             SIZE
REPOSITORY                 TAG                 IMAGE ID            CREATED             SIZE
xosproject/xos-postgres    candidate           c17f15922d35        20 hours ago        348MB
xosproject/xos-postgres    latest              c17f15922d35        20 hours ago        348MB
nginx                      candidate           958a7ae9e569        3 days ago          109MB
nginx                      latest              958a7ae9e569        3 days ago          109MB
xosproject/xos-base        candidate           4a6b75a0f05a        6 days ago          932MB
xosproject/xos-base        latest              4a6b75a0f05a        6 days ago          932MB
python                     2.7-alpine          3dd614730c9c        7 days ago          72MB
onosproject/onos           <none>              e41f6f8b2570        2 weeks ago         948MB
gliderlabs/consul-server   candidate           7ef15b0d1bdb        4 months ago        29.2MB
gliderlabs/consul-server   latest              7ef15b0d1bdb        4 months ago        29.2MB
node                       <none>              c09e81cac06c        4 months ago        650MB
redis                      <none>              74b99a81add5        7 months ago        183MB
consul                     <none>              62f109a3299c        11 months ago       41.1MB
swarm                      <none>              47dc182ea74b        13 months ago       19.3MB
nginx                      <none>              3c69047c6034        13 months ago       183MB
gliderlabs/registrator     candidate           3b59190c6c80        13 months ago       23.8MB
gliderlabs/registrator     latest              3b59190c6c80        13 months ago       23.8MB
xosproject/vsg             <none>              dd026689aff3        13 months ago       336MB
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
   - cord-ip-allocator - (directory: `ip-allocator`) daemon on the head node used
   to allocate IP address for the fabric interfaces.
   - cord-dhcp-harvester - (directory: `harvester`) run on the head node to
   facilitate CORD / DHCP / DNS integration so that all hosts can be resolved
   via DNS
   - opencord/mavenrepo - custom CORD maven repository image to support
   ONOS application loading from a local repository
   - cord-test/nose - container from which cord tester test cases originate and
   validate traffic through the CORD infrastructure
   - cord-test/quagga - BGP virtual router to support uplink from CORD fabric
   network to Internet
   - cord-test/radius - Radius server to support cord-tester capability

The images can be built by using the following command.
```
./gradlew buildImages
```
**NOTE:** *The first time you run `./gradlew` it will download the `gradle`
binary from the Internet and install it locally. This is a one time operation,
but may be time consuming depending on the speed of your Internet connection.*

### Complete
Once the `buildImages` command successfully runs this task is complete. The
CORD artifacts have been built and the Docker images can be viewed by using the
`docker images` command on the development machine.
```
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.ID}}'
REPOSITORY                  TAG                 SIZE                IMAGE ID
xosproject/xos-ui                        candidate           943MB               23a2e5523279
xosproject/exampleservice-synchronizer   candidate           940MB               b7cd75514f65
xosproject/fabric-synchronizer           candidate           940MB               2b183b0504fd
xosproject/vtr-synchronizer              candidate           940MB               f2955d88bf63
xosproject/vsg-synchronizer              candidate           940MB               680b400ba627
xosproject/vrouter-synchronizer          candidate           940MB               332cb7817586
xosproject/onos-synchronizer             candidate           940MB               12fe520e29ae
xosproject/openstack-synchronizer        candidate           940MB               6a2e9b56ecba
xosproject/vtn-synchronizer              candidate           940MB               5edf77bcd615
xosproject/gui-extension-rcord           candidate           1.02GB              0cf6c1defba5
xosproject/gui-extension-vtr             candidate           1.02GB              c78d602c5359
xosproject/xos-corebuilder               candidate           932MB               c73eab2918c2
xosproject/xos-gui-extension-builder     candidate           1.02GB              78fe07e95ba9
xosproject/xos-gui                       candidate           652MB               e57d903b9766
xosproject/xos-ws                        candidate           682MB               39cefcaa50bc
xosproject/xos-synchronizer-base         candidate           940MB               a914ae0d1aba
xosproject/xos-client                    candidate           940MB               667948589bc9
xosproject/chameleon                     candidate           936MB               cdb9d6996401
xosproject/xos                           candidate           942MB               11f37fd19b0d
xosproject/xos-postgres                  candidate           345MB               f038a31b50be
opencord/mavenrepo                       latest              271MB               2df1c4d790bf
cord-maas-switchq                        candidate           14MB                8a44d3070ffd
cord-maas-switchq                        build               252MB               77d7967c14e4
cord-provisioner                         candidate           96.7MB              de87aa48ffc4
cord-provisioner                         build               250MB               beff949ff60b
cord-dhcp-harvester                      candidate           18.8MB              79780c133469
cord-dhcp-harvester                      build               254MB               c7950fc044dd
config-generator                         candidate           12.2MB              37a51b0acdb2
config-generator                         build               249MB               3d1f1faaf5e1
cord-maas-automation                     candidate           13.6MB              2af5474082d4
cord-maas-automation                     build               251MB               420d5328dc11
cord-ip-allocator                        candidate           12.1MB              6d8aed37cb91
cord-ip-allocator                        build               249MB               7235cbd3d771
ubuntu                                   14.04.5             188MB               132b7427a3b4
xosproject/xos-postgres                  latest              348MB               c17f15922d35
golang                                   1.7-alpine          241MB               e40088237856
nginx                                    latest              109MB               958a7ae9e569
xosproject/xos-base                      candidate           932MB               4a6b75a0f05a
xosproject/xos-base                      latest              932MB               4a6b75a0f05a
python                                   2.7-alpine          72MB                3dd614730c9c
alpine                                   3.5                 3.99MB              75b63e430bd1
onosproject/onos                         <none>              948MB               e41f6f8b2570
node                                     7.9.0               665MB               90223b3d894e
gliderlabs/consul-server                 candidate           29.2MB              7ef15b0d1bdb
gliderlabs/consul-server                 latest              29.2MB              7ef15b0d1bdb
node                                     <none>              650MB               c09e81cac06c
redis                                    <none>              183MB               74b99a81add5
consul                                   <none>              41.1MB              62f109a3299c
swarm                                    <none>              19.3MB              47dc182ea74b
nginx                                    candidate           183MB               3c69047c6034
gliderlabs/registrator                   candidate           23.8MB              3b59190c6c80
gliderlabs/registrator                   latest              23.8MB              3b59190c6c80
xosproject/vsg                           <none>              336MB               dd026689aff3
```

**NOTE:** *Not all the above Docker images were built by the `buildImages`
command. Some of them, list golang, are used as a base for other Docker
images.*

## Deployment Configuration File
The commands to deploy the POD can be customized via a *deployment configuration
file*. The file is in [YAML](http://yaml.org/) format.

To construct a configuration file for your physical POD, copy the
sample deployment configuration found in `config/sample.yml` and modify the
values to fit your physical deployment. Descriptions of the values can be
found in the sample file.

## Publish
Publishing consists of *pushing* the build docker images to the Docker
repository on the target head node. This step can take a while as it has to
transfer all the image from the development machine to the target head node.
This step is started with the following command:
```
./gradlew -PdeployConfig=config/podX.yml publish
```

### Complete

Once the `publish` command successfully runs this task is complete. When this
step is complete a Docker registry and Docker registry mirror. It can be
verified that these are running by using the `docker ps` command.
```
docker ps --format 'table {{.ID}}\t{{.Image}}\t{{.Command}}\t{{.CreatedAt}}'
CONTAINER ID        IMAGE               COMMAND                  CREATED AT
c8dd48fc9d18        registry:2.4.0      "/bin/registry serve "   2016-12-02 11:49:12 -0800 PST
e983d2e43760        registry:2.4.0      "/bin/registry serve "   2016-12-02 11:49:12 -0800 PST
```

We can also query the docker registry on the head node. We should be able to
observe a list of docker images.

_Note: the example below uses the commands `curl` and `jq`
to retrieve data and pretty print JSON. If you system doesn't have `curl` or
`jq` installed it can be installed using `sudo apt-get install -y curl jq`._

```
curl -sS http://head-node-ip-address:5000/v2/_catalog | jq .
{
  "repositories": [
    "config-generator",
    "consul",
    "cord-dhcp-harvester",
    "cord-ip-allocator",
    "cord-maas-automation",
    "cord-maas-switchq",
    "cord-provisioner",
    "gliderlabs/consul-server",
    "gliderlabs/registrator",
    "mavenrepo",
    "nginx",
    "node",
    "onosproject/onos",
    "redis",
    "swarm",
    "xosproject/chameleon",
    "xosproject/exampleservice-synchronizer",
    "xosproject/fabric-synchronizer",
    "xosproject/gui-extension-rcord",
    "xosproject/gui-extension-vtr",
    "xosproject/onos-synchronizer",
    "xosproject/openstack-synchronizer",
    "xosproject/vrouter-synchronizer",
    "xosproject/vsg",
    "xosproject/vsg-synchronizer",
    "xosproject/vtn-synchronizer",
    "xosproject/vtr-synchronizer",
    "xosproject/xos",
    "xosproject/xos-client",
    "xosproject/xos-corebuilder",
    "xosproject/xos-gui",
    "xosproject/xos-postgres",
    "xosproject/xos-synchronizer-base",
    "xosproject/xos-ui",
    "xosproject/xos-ws"
  ]
}
}
```

## Deploy Bare Metal Provisioning Capabilities
There are three parts to deploying bare metal: deploying the head node PXE
server (`MAAS`), PXE booting a compute node, and post deployment provisioning
of the compute node. These tasks are accomplished utilizing additionally
Vagrant machines as well as executing `gradle` tasks in the Vagrant
development machine. This task also provisions XOS. XOS provides service
provisioning and orchestration for the CORD POD.

### Deploy MAAS and XOS
Canonical MAAS provides the PXE and other bare metal provisioning services for
CORD and will be deployed on the head node.
```
./gradlew -PdeployConfig=config/podX.yml deploy
```

This task can take some time so be patient. It should complete without errors,
so if an error is encountered, something has gone Horribly Wrong(tm).  See the
[Getting Help](#getting-help) section.

### Complete

This step is complete when the command successfully runs. The Web UI for MAAS
can be viewed by browsing to the target machine using a URL of the form
`http://head-node-ip-address/MAAS`. To login to the web page, use
`cord` for username. If you have set a password in the deployment configuration
password use that, else the password used can be found in your build directory
under `<base>/build/maas/passwords/maas_user.txt`.

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

Browse around the UI and get familiar with MAAS via documentation at
`http://maas.io`

The deployment of XOS includes a deployment of Open Stack.

## Booting Compute Nodes

### Network configuration
The CORD POD uses two core network interfaces, `fabric` and `mgmtbr`. The
`fabric` interface will be used to bond all interfaces meant to be used for CORD
data traffic and the `mgmtbr` will be used to bridge all interfaces used for POD
management (signaling) traffic.

An additional interface of import on the head node is the external interface, or
the interface through which the management net accesses upstream servers; such
as the Internet.

How physical interfaces are identified and mapped to either the `fabric` or
`mgmtbr` interface is a combination of their name, NIC driver, and/or bus type.

By default any interface that has a module or kernel driver of `tun`, `bridge`,
`bonding`, or `veth` will be ignored when selecting devices for the `fabric` and
`mgmtbr` interfaces. As will any interface that is not associated with a bus
type or has a bus type of `N/A` or `tap`. For your specific deployment you can
verify the interface information using the `ethtool -i <name>` command on the
linux prompt.

All other interfaces that are not ignored will be considered for selection to
either the `fabric` or `mbmtbr` interface. By default, any interface that has a
module or kernel driver of `i40e` or `mlx4_en` will be selected to the `fabric`
interface and all others will be selected to the `mgmtbr` interface.

As the `fabric` interface is a `bond` the first interface, sorted alpha
numerically by name, will be used as the primary interface.

For the management network an interface bond, `mgmtbond`, is created to provide
redundant network for the physical interfaces. The bridge, `mgmtbr`, associates
this bond interface and various other virtual interfaces together to enable
management communication between compute nodes, containers, and virtual machines
that make up the management software for CORD.

#### Customizing Network Configuration
The network configuration can be customized to your deployment using a set of
variables that can be set in your deployment configuration file, e.g.
`podX.yml`. There is a set of include, exclude, and ignore variables that
operation on the interface name, module type, and bus type. By setting values on
these variables it is fairly easy to customize the network settings.

The options are processed as following:

1. If a given interface matches an ignore option, it is not available to be selected into either the `fabric` or `mgmtbr` interface and will not be modified in the `/etc/network/interface`.
1. If no include criteria are specified and the given interfaces matches then exclude criteria then the interface will be set as `manual` configuration in the `/etc/network/interface` file and will not be `auto` activated
1. If no include criteria are specified and the given interface does _NOT_ match the exclude criteria then this interface will be included in either the `frabric` or `mgmtbr` interface
1. If include criteria are specified and the given interface does not match the criteria then the interface will be ignored and its configuration will _NOT_ be modified
1. If include criteria are specified and the given interface matches the criteria then if the given interface also matches the exclude criteria then this interface will be set as `manual` configuration in the `/etc/network/interface` file and will not be `auto` activated
1. If include criteria are specified and the given interface matches the criteria and if it does _NOT_ match the exclude criteria then this interface will be included in either the `frabric` or `mgmtbr` interface

By default, the only criteria that are specified is the _fabric include module
types_ and they are set to `i40e,mlx4_en` (_NOTE: the list is now comma
separated and not vertical bar (`|`) separated._)

If the _fabric include module types_ is specified and the _management exclude
module types_ are not specified, then by default the _fabric include module
types_ are used as the _management exclude module types_. This ensures that by
default the `fabric` and the `mgmtbr` do not intersect on interface module
types.

If an external interface is specified in the deployment configuration, this
interface will be added to the _farbric_ and _management_ _ignore names_ list.

Each of the criteria is specified as a comma separated list of regular
expressions. Default

To set the variables you can use the `seedServer.extraVars` section in the
deployment config file as follows:

```
seedServer:
  extraVars:
    - 'fabric_include_names=<name1>,<name2>'
    - 'fabric_include_module_types=<mod1>,<mod2>'
    - 'fabric_include_bus_types=<bus1>,<bus2>'
    - 'fabric_exclude_names=<name1>,<name2>'
    - 'fabric_exclude_module_types=<mod1>,<mod2>'
    - 'fabric_exclude_bus_types=<bus1>,<bus2>'
    - 'fabric_ignore_names=<name1>,<name2>'
    - 'fabric_ignore_module_types=<mod1>,<mod2>'
    - 'fabric_ignore_bus_types=<bus1>,<bus2>'
    - 'management_include_names=<name1>,<name2>'
    - 'management_include_module_types=<mod1>,<mod2>'
    - 'management_include_bus_types=<bus1>,<bus2>'
    - 'management_exclude_names=<name1>,<name2>'
    - 'management_exclude_module_types=<mod1>,<mod2>'
    - 'management_exclude_bus_types=<bus1>,<bus2>'
    - 'management_ignore_names=<name1>,<name2>'
    - 'management_ignore_module_types=<mod1>,<mod2>'
    - 'management_ignore_bus_types=<bus1>,<bus2>'
```

The Ansible scripts configure MAAS to support DHCP/DNS/PXE on the eth2 and
mgmtbr interfaces.

Once it has been verified that the ubuntu boot image has been downloaded the
compute nodes may be PXE booted.

**Note:** *In order to ensure that the compute node PXE boot the bios settings
may have to be adjusted. Additionally, the remote power management on the
compute nodes must be enabled.*

The compute node will boot, register with MAAS, and then be shut off. After this
is complete an entry for the node will be in the MAAS UI at
`http://head-node-ip-address/MAAS/#/nodes`. It will be given a random
hostname, in the Canonical way, of a adjective and an noun, such as
`popular-feast.cord.lab`. *The name will be different for every deployment.* The
new node will be in the `New` state.

As the machines boot they should be automatically transitioned from `New`
through the states of `Commissioning` and `Acquired` to `Deployed`.

### Post Deployment Provisioning of the Compute Node
Once the node is in the `Deployed` state, it will be provisioned for use in a
CORD POD by the execution of an `Ansible` playbook.

### Complete
Once the compute node is in the `Deployed` state and post deployment
provisioning on the compute node is complete, this task is complete.

Logs of the post deployment provisioning of the compute nodes can be found
in `/etc/maas/ansible/logs` on the head node.

Additionally, the post deployment provisioning of the compute nodes can be
queried using the command `cord prov list`
```
cord prov list
ID                                         NAME                   MAC                IP          STATUS      MESSAGE
node-c22534a2-bd0f-11e6-a36d-2c600ce3c239  steel-ghost.cord.lab   2c:60:0c:cb:00:3c  10.6.0.107  Complete
node-c238ea9c-bd0f-11e6-8206-2c600ce3c239  feline-shirt.cord.lab  2c:60:0c:e3:c4:2e  10.6.0.108  Complete
node-c25713c8-bd0f-11e6-96dd-2c600ce3c239  yellow-plot.cord.lab   2c:60:0c:cb:00:f0  10.6.0.109  Complete
```

The following status values are defined for the provisioning status:
   - `Pending`-  the request has been accepted by the provisioner but not yet
   started
   - `Processing` - the request is being processed and the node is being
   provisioned
   - `Complete` - the provisioning has been completed successfully
   - `Error` - the provisioning has failed and the `message` will be
   populated with the exit message from provisioning.

Please refer to [Re-provision Compute Nodes and Switches
](#re-provision-compute-nodes-and-switches)
if you want to restart this process or re-provision a initialized compute node.

## Booting OpenFlow switches
Once the compute nodes have begun their boot process you may also boot the
switches that support the leaf spine fabric. These switches should ONIE install
boot and download their boot image from MAAS.

### Complete
This step is complete when the command completes successfully. You can verify
the provisioning of the switches by querying the provisioning service
using `cord prov list` which will show the status of the switches as well as
the compute nodes. Switches can be easily identified as their ID will be the
MAC address of the switch management interface.
```
cord prov list
ID                                         NAME                   MAC                IP          STATUS      MESSAGE
cc:37:ab:7c:b7:4c                          spine-1                cc:37:ab:7c:b7:4c  10.6.0.23   Complete
cc:37:ab:7c:ba:58                          leaf-2                 cc:37:ab:7c:ba:58  10.6.0.20   Complete
cc:37:ab:7c:bd:e6                          leaf-1                 cc:37:ab:7c:bd:e6  10.6.0.52   Complete
cc:37:ab:7c:bf:6c                          spine-2                cc:37:ab:7c:bf:6c  10.6.0.22   Complete
node-c22534a2-bd0f-11e6-a36d-2c600ce3c239  steel-ghost.cord.lab   2c:60:0c:cb:00:3c  10.6.0.107  Complete
node-c238ea9c-bd0f-11e6-8206-2c600ce3c239  feline-shirt.cord.lab  2c:60:0c:e3:c4:2e  10.6.0.108  Complete
node-c25713c8-bd0f-11e6-96dd-2c600ce3c239  yellow-plot.cord.lab   2c:60:0c:cb:00:f0  10.6.0.109  Complete
```
The following status values are defined for the provisioning status:
   - `Pending`-  the request has been accepted by the provisioner but not yet
   started
   - `Processing` - the request is being processed and the node is being
   provisioned
   - `Complete` - the provisioning has been completed successfully
   - `Error` - the provisioning has failed and the `message` will be
   populated with the exit message from provisioning.

Please refer to [Re-provision Compute Nodes and Switches
](#re-provision-compute-nodes-and-switches)
if you want to restart this process or re-provision a initialized switch.

## Post Deployment Configuration of XOS / ONOS VTN app

The compute node provisioning process described above (under [Booting Compute Nodes](#booting-compute-nodes)) will install the servers as OpenStack compute
nodes.  You should be able to see them on the CORD head node by running the
following commands:
```
source ~/admin-openrc.sh
nova hypervisor-list
```

You will see output like the following (showing each of the nodes you have
provisioned):
```
+----+--------------------------+
| ID | Hypervisor hostname      |
+----+--------------------------+
| 1  | sturdy-baseball.cord.lab |
+----+--------------------------+
```

This step performs a small amount of manual configuration to tell VTN how to
route external traffic, and verifies that the new nodes were added to the ONOS VTN app by XOS.

### Fabric Gateway Configuration
First, login to the CORD head node and change to the
`/opt/cord_profile` directory.

To configure the fabric gateway, you will need to edit the file
`cord-services.yaml`. You will see a section that looks like this:

```
    addresses_vsg:
      type: tosca.nodes.AddressPool
      properties:
        addresses: 10.6.1.128/26
        gateway_ip: 10.6.1.129
        gateway_mac: 02:42:0a:06:01:01
```

Edit this section so that it reflects the fabric's address block assigned to the
vSGs, as well as the gateway IP and MAC address that the vSGs should use to
reach the Internet.

Once the `cord-services.yaml` TOSCA file has been edited as
described above, push it to XOS by running the following:

```
cd /opt/cord_profile
docker-compose -p rcord exec xos_ui python /opt/xos/tosca/run.py xosadmin@opencord.org /opt/cord_profile/cord-services.yaml
```

### Complete

This step is complete once you see the correct information in the VTN app
configuration in XOS and ONOS.

To check the VTN configuration maintained by XOS:
   - Go to the "ONOS apps" page in the CORD GUI:
      - URL: `http://<head-node>/xos#/onos/onosapp/`
      - Username: `xosadmin@opencord.org`
      - Password:  (contents of `/opt/cord/build/platform-install/credentials/xosadmin@opencord.org`)
   - Select *VTN_ONOS_app* in the table
   - Verify that the *Backend status* is *1 - OK*

To check that the network configuration has been successfully pushed
to the ONOS VTN app and processed by it:

   - Log into ONOS from the head node
      - Command: `ssh -p 8102 onos@onos-cord`
      - Password: `rocks`
   - Run the `cordvtn-nodes` command
   - Verify that the information for all nodes is correct
   - Verify that the initialization status of all nodes is *COMPLETE*  This will look like the following:
```
onos> cordvtn-nodes
Hostname                      Management IP       Data IP             Data Iface     Br-int                  State
sturdy-baseball               10.1.0.14/24        10.6.1.2/24         fabric         of:0000525400d7cf3c     COMPLETE
Total 1 nodes
```
   - Run the `netcfg` command.  Verify that the updated gateway information is present under `publicGateways`:
```
        "publicGateways" : [ {
          "gatewayIp" : "10.6.1.193",
          "gatewayMac" : "02:42:0a:06:01:01"
        }, {
          "gatewayIp" : "10.6.1.129",
          "gatewayMac" : "02:42:0a:06:01:01"
        } ],

```

### Troubleshoot
If the compute node is not initialized properly (i.e. not in the COMPLETE state):
On the compute node, run
```
sudo ovs-vsctl del-br br-int
```
On the head node, run
```
ssh onos@onos-cord -p 8102
```
(password is 'rocks')
and then in the ONOS CLI, run
```
cordvtn-node-init <compute-node-name>
```
(name is something like "sturdy-baseball")

## Post Deployment Configuration of the ONOS Fabric

### Manully Configure Routes on the Compute Node `br-int` Interface
The routes on the compute node `br-int` interface need to be manually configured now.
Run the following command on compute-1 and compute-2 (nodes in 10.6.1.0/24)
```
sudo ip route add 10.6.2.0/24 via 10.6.1.254
```
Run the following command on compute-3 and compute-4 (nodes in 10.6.2.0/24)
```
sudo ip route add 10.6.1.0/24 via 10.6.2.254
```

### Modify and Apply Fabric Configuration
Configuring the switching fabric for use with CORD is documented in the
[Fabric Configuration Guide](https://wiki.opencord.org/display/CORD/Fabric+Configuration+Guide) on the OpenCORD wiki.

On the head node is a service that will generate an ONOS network configuration
for the leaf/spine network fabric. This configuration is generating by
querying ONOS for the known switches and compute nodes and producing a JSON
structure that can be `POST`ed to ONOS to implement the fabric.

The configuration generator can be invoked using the `cord generate` command.
The configuration will be generated to `stdout`.

Before generating a configuration you need to make sure that the instance of
ONOS controlling the fabric doesn't contain any stale data and has has processed
a packet from each of the switches and computes nodes. ONOS needs to process a
packet because it does not have a mechanism to discover the network, thus to be
aware of a device on the network ONOS needs to first receive a packet from it.

To remove stale data from ONOS, the ONOS CLI `wipe-out` command can be used:
```
ssh -p 8101 onos@onos-fabric wipe-out -r -j please
Warning: Permanently added '[onos-fabric]:8101,[10.6.0.1]:8101' (RSA) to the list of known hosts.
Password authentication
Password:  # password is 'rocks'
Wiping intents
Wiping hosts
Wiping Flows
Wiping groups
Wiping devices
Wiping links
Wiping UI layouts
Wiping regions
```

To ensure ONOS is aware of all the switches and the compute nodes, you must
have each switch "connect" to the controller and have each compute node ping
over its fabric interface to the controller.

If the switches are not already connected the following commands will initiate
a connection.

```shell
for s in $(cord switch list | grep -v IP | awk '{print $3}'); do
ssh -qftn root@$s ./connect -bg 2>&1  > $s.log
done
```

You can verify ONOS has recognized the devices using the following command:

```shell
ssh -p 8101 onos@onos-fabric devices
Warning: Permanently added '[onos-fabric]:8101,[10.6.0.1]:8101' (RSA) to the list of known hosts.
Password authentication
Password:     # password is 'rocks'
id=of:0000cc37ab7cb74c, available=true, role=MASTER, type=SWITCH, mfr=Broadcom Corp., hw=OF-DPA 2.0, sw=OF-DPA 2.0, serial=, driver=ofdpa, channelId=10.6.0.23:58739, managementAddress=10.6.0.23, protocol=OF_13
id=of:0000cc37ab7cba58, available=true, role=MASTER, type=SWITCH, mfr=Broadcom Corp., hw=OF-DPA 2.0, sw=OF-DPA 2.0, serial=, driver=ofdpa, channelId=10.6.0.20:33326, managementAddress=10.6.0.20, protocol=OF_13
id=of:0000cc37ab7cbde6, available=true, role=MASTER, type=SWITCH, mfr=Broadcom Corp., hw=OF-DPA 2.0, sw=OF-DPA 2.0, serial=, driver=ofdpa, channelId=10.6.0.52:37009, managementAddress=10.6.0.52, protocol=OF_13
id=of:0000cc37ab7cbf6c, available=true, role=MASTER, type=SWITCH, mfr=Broadcom Corp., hw=OF-DPA 2.0, sw=OF-DPA 2.0, serial=, driver=ofdpa, channelId=10.6.0.22:44136, managementAddress=10.6.0.22, protocol=OF_13
```

To make sure that ONOS is aware of the compute nodes the follow command will
a ping over the fabric interface on each of the compute nodes.

```shell
for h in localhost $(cord prov list | grep "^node" | awk '{print $4}'); do
ssh -qftn $h ping -c 1 -I fabric 8.8.8.8;
done
```

You can verify ONOS has recognized the devices using the following command:
```shell
ssh -p 8101 onos@onos-fabric hosts
Warning: Permanently added '[onos-fabric]:8101,[10.6.0.1]:8101' (RSA) to the list of known hosts.
Password authentication
Password:     # password is 'rocks'
id=00:16:3E:DF:89:0E/None, mac=00:16:3E:DF:89:0E, location=of:0000cc37ab7cba58/3, vlan=None, ip(s)=[10.6.0.54], configured=false
id=3C:FD:FE:9E:94:28/None, mac=3C:FD:FE:9E:94:28, location=of:0000cc37ab7cba58/4, vlan=None, ip(s)=[10.6.0.53], configured=false
id=3C:FD:FE:9E:94:30/None, mac=3C:FD:FE:9E:94:30, location=of:0000cc37ab7cbde6/1, vlan=None, ip(s)=[10.6.1.1], configured=false
id=3C:FD:FE:9E:98:69/None, mac=3C:FD:FE:9E:98:69, location=of:0000cc37ab7cbde6/2, vlan=None, ip(s)=[10.6.0.5], configured=false
```

To modify the fabric configuration for your environment, on the head node,
generate a new network configuration using the following commands:

```
cd /opt/cord_profile
cp fabric-network-cfg.json{,.$(date +%Y%m%d-%H%M%S)}
cord generate > fabric-network-cfg.json
```

Once these steps are done, delete the old configuration,
load the new configuration into XOS, and restart the apps in ONOS:
```
sudo pip install httpie
http -a onos:rocks DELETE http://onos-fabric:8181/onos/v1/network/configuration/
docker-compose -p rcord exec xos_ui python /opt/xos/tosca/run.py xosadmin@opencord.org /opt/cord_profile/fabric-service.yaml
http -a onos:rocks POST http://onos-fabric:8181/onos/v1/applications/org.onosproject.vrouter/active
http -a onos:rocks POST http://onos-fabric:8181/onos/v1/applications/org.onosproject.segmentrouting/active
```

To verify that XOS has pushed the configuration to ONOS, log into ONOS in the onos-fabric VM and run `netcfg`:
```
$ ssh -p 8101 onos@onos-fabric netcfg
Password authentication
Password:     # password is 'rocks'
{
  "hosts" : {
    "00:00:00:00:00:04/None" : {
      "basic" : {
        "ips" : [ "10.6.2.2" ],
        "location" : "of:0000000000000002/4"
      }
    },
    "00:00:00:00:00:03/None" : {
      "basic" : {
        "ips" : [ "10.6.2.1" ],
        "location" : "of:0000000000000002/3"
      }
    },
... etc.
```

### Update physical host locations in XOS

To correctly configure the fabric when VMs and containers are created on a
physical host, XOS needs to associate the `location` tag of each physical host
(from the fabric configuration) with its Node object in XOS.  This step needs to
be done after a new physical compute node is provisioned on the POD.

To update the node location in XOS, perform the following steps:

 * Login to the XOS admin GUI at `http://<head-node-ip>/admin/`
 * Navigate to `/admin/core/node/`
 * Select the node to change
 * Select the *Tags* tab for the node
 * Click on *Add another tag*
 * Fill in the following information:
   * Service: *ONOS_Fabric*
   * Name: *location*
   * Value: *(location of the node in the fabric configuration created above)*
 * Click _Save_ button at bottom.

### Connect Switches to the controller
We need to manually connect the switches to ONOS after the network config is applied.
This can be done by running following ansible script on the head node.
```
ansible-playbook /etc/maas/ansible/connect-switch.yml
```
This ansible script will automatically locate all switches in DHCP harvest and connect them to the controller.

### Complete

This step is complete when each compute node can ping the fabric IP address of all the other nodes.


## Getting Help

If it seems that something has gone wrong with your setup, there are a number of ways that you
can get	help --	in the documentation on the [OpenCORD wiki](https://wiki.opencord.org),	on the
[OpenCORD Slack channel](https://opencord.slack.com) (get an invitation [here](https://slackin.opencord.org)),
or on the [CORD-discuss mailing list](https://groups.google.com/a/opencord.org/forum/#!forum/cord-discuss).

See the	[How to	Contribute to CORD wiki page](https://wiki.opencord.org/display/CORD/How+to+Contribute+to+CORD#HowtoContributetoCORD-AskingQuestions)
for more information.

## Re-provision Compute Nodes and Switches
If you would like to re-provision a switch or a compute node the `cord prov delete`
command can be used. This command takes one or more IDs as parameters and will
delete the provisioning records for these devices. This will cause the provisioner
to re-provision them.

You can also use the argument `--all`, which will delete all known provisioning
records.

```
cord prov delete node-c22534a2-bd0f-11e6-a36d-2c600ce3c239
node-c22534a2-bd0f-11e6-a36d-2c600ce3c239 DELETED
```

```
cord prov delete --all
cc:37:ab:7c:b7:4c DELETED
cc:37:ab:7c:ba:58 DELETED
cc:37:ab:7c:bd:e6 DELETED
cc:37:ab:7c:bf:6c DELETED
node-c22534a2-bd0f-11e6-a36d-2c600ce3c239 DELETED
node-c238ea9c-bd0f-11e6-8206-2c600ce3c239 DELETED
node-c25713c8-bd0f-11e6-96dd-2c600ce3c239 DELETED
```
