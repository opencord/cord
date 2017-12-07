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

If you've run into trouble or want to know more about the CORD build process,
please see [Troubleshooting and Build Internals](troubleshooting.md).

## Configuring your Development Environment

CORD has a unified development and deployment environment which uses the
following tools:

 - [Ansible](https://docs.ansible.com/ansible/intro_installation.html)
 - [Repo](https://source.android.com/source/downloading#installing-repo)

And either:

 - [Docker](https://www.docker.com/community-edition), for *local* build
   scenarios
 - [Vagrant](https://www.vagrantup.com/downloads.html), for all other
   scenarios

You can manually install these on your development system - see [Getting the
Source Code](getting_the_code.md) for a more detailed instructions for checking
out the CORD source tree.

### cord-bootstrap.sh script

If you're working on an Ubuntu 14.04 system (CloudLab or another test
environment), you can use the `cord-bootstrap.sh` script to install these tools
and check out the CORD source tree to `~/cord`. This hasn't been tested on
other versions or distributions.

<pre><code>
curl -o ~/cord-bootstrap.sh https://raw.githubusercontent.com/opencord/cord/{{ book.branch }}/scripts/cord-bootstrap.sh
chmod +x cord-bootstrap.sh
</code></pre>

The bootstrap script has the following options:

```
Usage for ./cord-bootstrap.sh:
  -d                           Install Docker for local scenario.
  -h                           Display this help message.
  -p <project:change/revision> Download a patch from gerrit. Can be repeated.
  -t <target>                  Run 'make -j4 <target>' in cord/build/. Can be repeated.
  -v                           Install Vagrant for mock/virtual/physical scenarios.
```

Using the `-v` option is required to install Vagrant for running a [Virtual Pod
(CiaB)](install_virtual.md), whereas `-d` is required to install Docker for a
[Local Workflow](xos/dev/workflow_local.md).

The `-p` option downloads a patch from gerrit, and the syntax for this is
`<project path>:<changeset>/<revision>`.  It can be used multiple
time. For example:

```
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

```
You are not in the group: libvirtd, please logout/login.
You are not in the group: docker, please logout/login.
```

In such cases, please logout and login to the system to gain the proper group
membership.  Another way to tell if you're in the right groups:

```
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

The top level configuration for a build is the *POD config* file, which is a
YAML file stored in
[build/podconfig](https://github.com/opencord/cord/tree/master/podconfig) that
contains a list of variables that control how the build proceeds, and can
override the configuration of the rest of the build. 

A minimal POD Config file must define two variables:

`cord_scenario` - the name of the *scenario* to use, which is defined in a
directory under [build/scenarios](https://github.com/opencord/cord/tree/master/scenarios).

`cord_profile` - the name of a *profile* to use, defined as a YAML file in
[build/platform-install/profile_manifests](https://github.com/opencord/platform-install/tree/master/profile_manifests).

The included POD configs are generally named `<profile>-<scenario>.yml`. 

POD configs are used during a build by passing them with the `PODCONFIG`
variable to `make` - ex: `make PODCONFIG=rcord-virtual.yml config`

### Profiles

The set of services that XOS on-boards into CORD -- the  _Service Graph_, and
other per-profile configuration for a CORD deployment.  These are located in
[build/platform-install/profile_manifests](https://github.com/opencord/platform-install/tree/master/profile_manifests).

### Scenarios

Scenarios define the physical or virtual environment that CORD will be
installed into, a default mapping of ansible groups to nodes, the set of Docker
images that can be built, and software and platform features are installed onto
those nodes. Scenarios are subdirectories of the
[build/scenarios](https://github.com/opencord/cord/tree/master/scenarios)
directory, and consist of a `config.yaml` file and possibly VM's specified in a
`Vagrantfile`.

The current set of scenarios: 

- `local`: Minimal set of containers running locally on the development host
- `mock`: Creates a single Vagrant VM with containers and DNS set up, without
  synchronizers
- `single`: Creates a single Vagrant VM with containers and DNS set up, with
  synchronizers and optional ElasticStack/ONOS
- `cord`: Physical or virtual multi-node CORD pod, with MaaS and OpenStack
- `opencloud`: Physical or virtual multi-node OpenCloud pod, with OpenStack

The scenario is specified in the POD config.
