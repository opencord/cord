# CORD Quick Start Guide using Virtual Machine Nodes

[*This description is for bringing up a CORD POD on virtual
machines on a single physical host. The purpose of this solution
is to give the user an experience of bring up a CORD on bare
metal.*]

This tutorial walks you through the steps to bring up a CORD "POD"
on a single server using multiple virtual machines which
represent the physical nodes of a production deployment.

Specifically, the tutorial covers the following:

1. Bring up a build environment
1. Fetch and build the binary artifacts
1. Deploy the software to the target *seed* server
1. Bring up and auto configure / provision compute nodes and
switches in the POD
1. Run some tests on the platform
1. Clean up

### What you need (Prerequisites)

You will need a build machine (can be your developer laptop) and a target
server.

Build host:

* Mac OS X, Linux, or Windows with a 64-bit OS
* Git (2.5.4 or later) - [TODO add pointers and/or instructions]
* Vagrant (1.8.1 or later) - [TODO add pointers and/or instructions]
* Access to the Internet (at least through the fetch phase)
* SSH access to the target server

### Bring up and Use the CORD Build Environment

On the build host, clone the CORD integration repository and switch into its
top directory:

For now you can clone the repository anonymously:

```
git clone https://gerrit.opencord.org/cord
cd cord
```

If -- for whatever reason -- you decide to clone the repo as a private
repository using ssh, then you should add your private key to your local ssh
forwarding agent, because we will clone additional CORD repositories within
the Vagrant environment using the same git access mode, and this will require
your local agent to know your identity:

```
ssh-add ~/.ssh/id_rsa
```

Bring up the standardized CORD build and development environment (VM) and the
VM that will play the role of the head end in the sample CORD POD. This will
take a few minutes, depending on your connection speed:

```
vagrant up corddev prod
```

Login to the build environment:

```
vagrant ssh corddev -- -L 8080:localhost:80
```

Switch to the CORD integration directory, which is shared from your host:

```
cd /cord
```

### Fetch and Build the CORD Artifacts

Pre-fetch all pre-requisites needed to build all components for CORD. This is
the step that takes the longest time as a large number of images and files
need to be downloaded.

```
./gradlew fetch
```
> *What this does:*
>
> This command pulls the Docker registry image down from the
> Internet as well as performs a `git submodule update
> --recursive` on the source tree to pull down from the GIT
> repositories all the sub projects referenced by the `cord`
> repository.

_NOTE: The first time you run `./gradlew` it will download from the Internet
the `gradle` binary and install it locally. This is a one time operation._

Time to build artifacts needed for deployment:

```
./gradlew buildImages
```
> *What this does:*
>
> This command visits each submodule in the project and
> build any Docker images that are part of the project. These
> Docker images are stored in the local Docker daemon's
> data area.

Prime the target server so that it is minimally ready to
receive the images. This includes starting a *Docker
Registry* on the target server (`prod`).

### Prepare the Target Server and Push Images to Target Server

```
./gradlew prime
```
> *What this does:*
>
> This uses and Ansible playbook to install docker on the
> target server as well as start a docker registry on that
> server.

Let's publish all artifacts to the staging registry (Docker registry). Here we
must specify the IP address of the target server (`prod`).

```
./gradlew -PtargetReg=10.100.198.201:5000 publish
```
> *What this does:*
>
> This command pushes all the images that have been built to
> the registry specified using the `-PtargetReg` command line
> option. The address used above, `10.100.198.201:5000`,
> refers to the `prod` VM created at the start of this guide
> using `vagrant up`.

### Deploy and Configure Bare Metal Services on Target Server

Deploy the head node software to the the target server (`prod`).

**NOTE:** The default MAAS deployment does not support power management for
virtual box based hosts. As part of the MAAS installation support was added for
power management, but it does require some additional configuration. This
additional configuration is detailed in the #virtual-box-power-management
section below, but is mentioned here because when deploying the head node an
additional parameter must be set. This parameter specifies the username on the
host machine that should be used when SSHing from the head node to the host
machine to remotely execute the `vboxmanage` command. This is typically the
username used when logging into your laptop or desktop development machine.
This should be specified in the `config/default.yml` file as the
`power_helper_user` value, this values defaults to `cord`.
```
./gradlew Deploy
```
> *What this does:*
>
> This command uses and Ansible playbook to configure networking
> on the target server and then installs Canonical's MAAS (Metal
> as a Service) software on the target server. This software
> provides PXE boot, DHCP, DNS, and HTTP image download for the
> CORD POD.
>
> After installing the base software component, the Ansible
> playbook configures the MAAS server including default users
> and DHCP/DNS, as well as starts the boot image downloaded
> from the Internet.
>
> Lastly, after the software is configure, the Ansible script
> starts several Docker containers that help manage automation
> of the POD's host and switch resources as they become
> available.

At this point you can view the MAAS web UI by visiting the following URL
```
http://localhost:8080/MAAS
```

To authenticate to the UI you can use the user name `cord` with
the password `cord`.

Browse around the UI and get familiar with MAAS via documentation at
`http://maas.io`

**NOTE**: Before moving on the the next step it is import to ensure that MAAS
has completed the download and processing of the operating system images
required to PXE boot additional servers. This can be done either by viewing the
`Images` tab in the MAAS UI or by the following commands run on the target
(head) node.
```
sudo apt-get install -y jq
APIKEY=$(sudo maas-region-admin apikey --user=cord)
maas login cord http://localhost/MAAS/api/1.0 $APIKEY
maas cord boot-resources read | jq 'map(select(.type != "Synced"))'
```

It the output of of the above commands is not a empty list, `[]`, then
the images have not yet been completely downloaded. depending on your
network speed this could take several minutes. Please wait and then
attempt the last command again until the returned list is empty, `[]`.
When the list is empty you can proceed.

### Create and Boot Compute Nodes
To create a compute node you use the following vagrant command. This command
will create a VM that PXE boots to the interface on which the MAAS server is
listening. **This task is executed on your host machine and not in the
development virtual machine.**
```
vagrant up compute_node1
```

Vagrant will create a UI, which will popup on your screen, so that the PXE boot
process of the compute node can be visually monitored. After an initial PXE
boot of the compute node it will automatically be shutdown.

The compute node Vagrant machine it s bit different that most Vagrant machine
because it is not created with a user account to which Vagrant can connect,
which is the normal behavior of Vagrant. Instead the Vagrant files is
configured with a _dummy_ `communicator` which will fail causing the following
error to be displayed, but the compute node Vagrant machine will still have
been created correctly.
```
The requested communicator 'none' could not be found.
Please verify the name is correct and try again.
```

The compute node VM will boot, register with MAAS, and then be shut off. After
this is complete an entry for the node will be in the MAAS UI at
`http://localhost:8888/MAAS/#/nodes`. It will be given a random hostname made
up, in the Canonical way, of a adjective and an noun, such as
`popular-feast.cord.lab`. _The name will be different for everyone._ The new
node will be in the `New` state.

If you have properly configured power management for virtualbox (see below)
the host will be automatically transitioned from `New` through the start of
`Commissioning` and `Acquired` to `Deployed`.

The `Vagrant` file defines 3 compute node machines you can start using the
process as defined above. The three machines can be started using the commands
```
vagrant up compute_node1
vagrant up compute_node2
vagrant up compute_node3
```
> *What this does:*
>
> As each compute node is booted, it downloads and installs an Ubuntu OS images
> and is automated through the MAAS deployment workflow. This is the same
> workflow that will be executed if the hosts were not virtual hosts. During
> this process the hosts will be rebooted several times.
>
> After a host has reached the `Deployed` state in MAAS an additional
> provisioning step will be executed that customizes the compute node for
> use in a CORD POD. This step includes updating the network configuration of
> the compute node as well as deploying some standard software, such as
> `Docker`.

### Create and Boot Example (False) Switch
Included with the virtual compute nodes is an additional vagrant machine VM
that can be used to test the provisioning of a switch. This VM is configured so
that the CORD POD automation will assume it is a switch and run additional
provisioning on this *false* switch to deploy software and utility scripts.
**This task is executed on your host machine and not in the development virtual
machine.**

The following command can be used to start the *false* switch.
```
vagrant up switch
```

#### Virtual Box Power Management
Virtual box power management is implemented via helper scripts that SSH to the virtual box host and
execute `vboxmanage` commands. For this to work The scripts must be configured with a username and host
to utilize when SSHing and that account must allow SSH from the head node guest to the host using
SSH keys such that no password entry is required.

To enable SSH key based login, assuming that VirtualBox is running on a Linux based system, you can copy
the MAAS ssh public key from `/var/lib/maas/.ssh/id_rsa.pub` on the head known to your accounts `authorized_keys`
files. You can verify that this is working by issuing the following commands from your host machine:
```
vagrant ssh headnode
sudo su - maas
ssh yourusername@host_ip_address
```

If you are able to accomplish these commands the VirtualBox power management should operate correctly.
