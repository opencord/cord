# Building and Installing CORD

## Starting points

If this is your first encounter with CORD, we suggest you start by bringing up
an Virtual Pod, which installs CORD on a set of virtual machines running on a
single physical server: [Installing a Virtual Pod
(CORD-in-a-Box)](install_virtual.md).

You can also install CORD on a physical POD, as would be done in a production
environment, which involves first assembling a set of servers and switches, and
then pointing the build system at that target hardware: [Installing a Physical
POD](install_physical.md).

If you are interested in developing a new CORD service, working on the XOS GUI,
or performing other development tasks, see [Developing for CORD](develop.md).

If want to know more about the CORD build process, please see [Build Process
Internals](build_internals.md) and [Building Docker Images](build_images.md).

If you're having trouble installing CORD, please see
[Troubleshooting](troubleshooting.md).

## Required Tools

CORD has a unified build system for development and deployment which uses the
following tools:

- [Ansible](https://docs.ansible.com/ansible/intro_installation.html), *tested
  with v2.4*
- [Repo](https://source.android.com/source/downloading#installing-repo),
  *tested with v1.23 of repo (launcher)*

And either:

- [Docker](https://www.docker.com/community-edition), for *local* build
  scenarios, *tested with Community Edition version 17.06*
- [Vagrant](https://www.vagrantup.com/downloads.html), for all other scenarios
  *tested with version 2.0.1, requires specific plugins and modules if using
  with libvirt, see `cord-bootstrap.sh` for more details *

You can manually install these on your development system - see [Getting the
Source Code](getting_the_code.md) for a more detailed instructions for checking
out the CORD source tree.

### cord-bootstrap.sh script

If you're working on an cleanly installed Ubuntu 14.04 system, you can use the
`cord-bootstrap.sh` script to install these tools and check out the CORD source
tree to `~/cord`.

{% include "/partials/cord-bootstrap.md" %}

> NOTE: Change the `master` path component in the URL to your desired version
> branch (ex: `cord-5.0`) if required.

The bootstrap script has the following options:

``` shell
Usage for ./cord-bootstrap.sh:
  -d                           Install Docker for local scenario.
  -h                           Display this help message.
  -p <project:change/revision> Download a patch from gerrit. Can be repeated.
  -t <target>                  Run 'make -j4 <target>' in cord/build/. Can be repeated.
  -v                           Install Vagrant for mock/virtual/physical scenarios.
  -x                           Use Xenial (16.04) in Vagrant VM's.
```

Using the `-v` option is required to install Vagrant for running a [Virtual Pod
(CiaB)](install_virtual.md) or [Physical Pod](install_physical.md), whereas `-d`
is required to install Docker for a [Local Workflow](/xos/dev/workflow_local.md).

The `-p` option downloads a patch from gerrit, and the syntax for this is
`<project path>:<changeset>/<revision>`.  It can be used multiple
time. For example:

```shell
./cord-bootstrap.sh -p build/platform-install:1233/4 -p orchestration/xos:1234/2
```

checks out the `platform-install` repo with changeset 1233, patchset 4, and
`xos` repo changeset 1234, revision 2.

You can find the project path in the `repo` manifest file:
[manifest/default.xml](https://github.com/opencord/manifest/blob/master/default.xml).

You can also run make targets with the `-t` option; `-t build` is the same as
running `cd ~/cord/build ; make -j4 build` after the rest of the installations
and downloads have completed.

In some cases, you may see a message like this if you install software that
adds you to a group and you aren't already a member:

```shell
You are not in the group: libvirtd, please logout/login.
You are not in the group: docker, please logout/login.
```

In such cases, please logout and login to the system to gain the proper group
membership.  Another way to tell if you're in the right groups:

```shell
~$ groups
xos-PG0 root
~$ vagrant status
Call to virConnectOpen failed: Failed to connect socket to '/var/run/libvirt/libvirt-sock': Permission denied
~$ logout
~$ ssh node_name.cloudlab.us
~$ groups
xos-PG0 root libvirtd
```

Note that if you aren't in the right group, any patches specified by `-p` will
be downloaded, but no make targets specified by `-t` will be run - you will
need to `cd ~/cord/build` and run those targets manually.

## Configuring a Build

The CORD build process is designed to be modular and configurable with only a
handful of YAML files.

### POD Config

Each CORD *use-case* (e.g., R-CORD, M-CORD, E-CORD) has its own repository
containing configuration files for that type of POD.  All of these repositories
appear in the source tree under `orchestration/profiles/`.  For example,
R-CORD's repository is
[orchestration/profiles/rcord](https://github.com/opencord/rcord/tree/{{
  book.branch }}).

The top level configuration for a build is the *POD config* file, a YAML file
stored in each use-case repository's `podconfig` subdirectory.  Each Pod config
file contains a list of variables that control how the build proceeds, and can
override the configuration of the rest of the build.  A minimal POD config file
must define two variables:

1. `cord_profile` - the name of a [profile](#profiles) to use, defined as a
   YAML file at the top level of the use-case repository - ex:
   [mcord-ng40.yml](https://github.com/opencord/mcord/blob/{{ book.branch
   }}/mcord-ng40.yml).

2. `cord_scenario` - the name of the [scenario](#scenarios) to use, which is
   defined in a directory under
   [build/scenarios](https://github.com/opencord/cord/tree/{{ book.branch
   }}/scenarios).

The naming convention for POD configs stored in the use case repository is
`<profile>-<scenario>.yml` - ex:
[mcord-ng40-virtual.yml](https://github.com/opencord/mcord/blob/{{ book.branch
}}/podconfig/mcord-ng40-virtual.yml) builds the `virtual` scenario using the
`mcord-ng40` profile.  All such POD configs can be specified during a build
using the `PODCONFIG` variable:

```shell
make PODCONFIG=rcord-virtual.yml config
```

POD configs with arbitrary paths can be specified using
`PODCONFIG_PATH`.  This will override the `PODCONFIG` variable.

```shell
make PODCONFIG_PATH=./podconfig/my-pod-config.yml config
```

Additionally, if you are specifying a physical installation, you need to:

- Specify the [inventory](#inventory) in your POD Config in order to tells
  Ansible and the build system which machines you wish to install a CORD POD
  on, and which ansible inventory roles map onto them.

- Set `headnode` (and optionally `buildnode`) variables to match the inventory.

- Set `vagrant_vms` variable to only bring up VM's you need, which may be none,
  in which case you should specify the empty list: `vagrant_vms: []`.

- Add items to the [physical_node_list](build_glossary.md#physicalnodelist) for
  all nodes listed in the inventory.

The ONF internal
[pod-configs](https://gerrit.opencord.org/gitweb?p=pod-configs.git;a=tree)
repository gives many examples of physical POD Configs that are used for
testing of CORD.

### Profiles

The set of services that XOS on-boards into CORD -- the  _Service Graph_, and
other per-profile configuration for a CORD deployment.  These are checked out
by repo into the `orchestration/profiles` directory.  The current set of
profiles is:

- [R-CORD](https://github.com/opencord/rcord)
- [M-CORD](https://github.com/opencord/mcord)
- [E-CORD](https://github.com/opencord/ecord)

### Scenarios

To handle the variety of types of deployments CORD supports, including physical
deployments, development, and testing in virtual environments, the
scenario mechanism was developed to allow for a common build system.

A scenario determine:

- Which sets of components of CORD are installed during a build, by controlling
  which make targets are run, and the dependencies between them.

- A virtual-specific inventory and machine definitions used with
  [Vagrant](https://vagrantup.com), which is used for development and testing
  of the scenario with virtual machines.

- A [whitelist of docker
  images](build_images.md#adding-a-new-docker-image-to-cord) used when building
  this scenario.

Scenarios are subdirectories of the
[build/scenarios](https://github.com/opencord/cord/tree/{{ book.branch
}}/scenarios) directory, and consist of a `config.yaml` configuration file and
VM's specified in a `Vagrantfile`.

The current set of scenarios:

- `local`: Minimal set of containers running locally on the development host

- `mock`: Creates a single Vagrant VM with containers and DNS set up, without
  synchronizers

- `single`: Creates a single Vagrant VM with containers and DNS set up, with
  synchronizers and optionally ElasticStack/ONOS

- `cord`: Physical or virtual multi-node CORD pod, with MaaS and OpenStack

- `controlpod`: Physical or virtual single-node CORD control-plane only POD, with
  XOS and ONOS, suitable for some use cases such as `ecord-global`.

- `controlkube`: "Laptop sized" Kubernetes-enabled multi-node pod

- `preppedpod`: Physical or virtual multi-node CORD pod on a pre-prepared (OS
  installed) nodes, with ONOS and OpenStack, but lacking MaaS,  for use in
  environments where there is an existing provisioning system for compute
  hardware.

- `preppedkube`: "Deployment/Server sized" Kubernetes-enabled multi-node pod

How these scenarios are used for development is covered in the [Example
Worflows](workflows.md) section.

The primary mechanism that Scenarios use to modularize the build process by
enabling Makefile and creating prerequisite targets, which in turn controls
whether ansible playbooks or commands are run.  `make` is dependency based, and
the targets to create when `make build` is run is specified in the
`build_targets` list in the scenario.

Creating and extending scenarios is covered in the [Build Process
Internals](build_internals.md#creating-a-scenario).

### Inventory

A node inventory is defined in the `inventory_groups` variable, and must be set
in the scenario or overridden in the POD config.

The default inventory defined in a scenario has the settings for a virtual
install which is used in testing and development. It corresponds to the
machines in the Vagrantfile for that scenario.

The CORD build system defines 4 ansible inventory groups (`config`, `build`,
`head`, `compute`), 3 of which (all but `compute`) need to have at least one
physical or virtual node assigned.  The same node can be assigned to multiple
groups, which is one way that build modularity is achieved.

- `config`: This is where the build steps are run (where `make` and `ansible`
  execute), and where the configuration of a POD is generated. It is generally
  is set to `localhost`.
- `build`: Where the build steps are run, for building the Docker containers
  for CORD.  The node in this group is frequently the same as the `head`node.
- `head`: The traditional "head node", which hosts services for bootstrapping
  the POD.
- `compute`: Nodes for running VNFs.  This may be populated (as in the
  `preppedpod` and related scenarios) or not (in the `cord` scenario, which
  bootstraps these compute nodes with MaaS)

For all physical installations of CORD, the POD config must override the
scenario inventory. The [default physical
example](https://github.com/opencord/cord/blob/{{ book.branch
}}/podconfig/physical-example.yml) gives examples of how to do this, and
additional POD config examples can be found in the CORD QA systems [pod-config
repo](https://gerrit.opencord.org/gitweb?p=pod-configs.git;a=tree).

The inventory is specified using the `inventory_groups` dictionary in the
scenario `config.yml` or the podconfig YAML file. The format is similar to the
[Ansible YAML
inventory](http://docs.ansible.com/ansible/latest/intro_inventory.html#hosts-and-groups)
except without the `hosts` key below the groups names. Variables can optionally
be specified on a per-host basis by adding sub-keys to the host name. If the
host is listed multiple times, the same variables must be specified each time.

Here is an example inventory for a podconfig using the `preppedpod` scenario
with a physical pod - note that the build node is the same as the head node
(they have the same IP), and the variables are replicated there. The config
node is the default of `localhost`:

```yaml
inventory_groups:

  config:
    localhost:
      ansible_connection: local

  build:
    head1:
      ansible_host: 10.1.1.40
      ansible_user: cordadmin
      ansible_ssh_pass: cordpass

  head:
    head1:
      ansible_host: 10.1.1.40
      ansible_user: cordadmin
      ansible_ssh_pass: cordpass

  compute:
    compute1:
      ansible_host: 10.1.1.41
      ansible_user: cordcompute
      ansible_ssh_pass: cordpass

    compute2:
      ansible_host: 10.1.1.42
      ansible_user: cordcompute
      ansible_ssh_pass: cordpass
```

