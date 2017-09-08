# Build System Internals

The following describes the internals of the build system, which (in
brief) walks through the following four steps:

* Setup your build environment. On a bare Ubuntu 14.04 system, this can be
done by running `scripts/cord-bootstrap.sh` or manually.

* Pick a POD Config, such as `rcord-mock.yml` from the `podconfig` directory.

* Run `make PODCONFIG=podconfig.yml config` (see `podconfig` directory for
   filenames) to generate a configuration into the `genconfig/` directory.

* Run `make build` to build CORD.

## Setup the Build Environment

### Bootstrap Script

The script `scripts/cord-bootstrap.sh` bootstraps an Ubuntu
14.04 system (such as a CloudLab node) by installing the proper tools and
checkout the codebase with repo.

It can be downloaded via:

<pre><code>curl -o ~/cord-bootstrap.sh https://raw.githubusercontent.com/opencord/cord/{{ book.branch }}/scripts/cord-bootstrap.sh
chmod +x cord-bootstrap.sh</code></pre>

The bootstrap script has the following useful options:

```
Usage for ./cord-bootstrap.sh:
  -d                           Install Docker for local scenario.
  -h                           Display this help message.
  -p <project:change/revision> Download a patch from gerrit. Can be repeated.
  -t <target>                  Run 'make -j4 <target>' in cord/build/. Can be repeated.
  -v                           Install Vagrant for mock/virtual/physical scenarios.
```

The `-p` option downloads a patch from gerrit, and the syntax for this is
`<project path>:<changeset>/<revision>`.  It can be used multiple
time. For example:

```
./cord-bootstrap.sh -p build/platform-install:1233/4 -p orchestration/xos:1234/2
```

checks out the `platform-install` repo with changeset 1233, patchset 4, and
`xos` repo changeset 1234, revision 2.

You can find the project path in the `repo` manifest file: [manifest/default.xml](https://gerrit.opencord.org/gitweb?p=manifest.git;a=blob;f=default.xml).

In some cases, you may see a message like this if you install software that
adds you to a group and you aren't already a member:

```
You are not in the group: libvirtd, please logout/login.
You are not in the group: docker, please logout/login.
```

In such cases, please logout and login to the system to gain the proper group
membership. Note that any patches specified will be downloaded, but no make
targets will be run if you're not in the right groups.

#### Examples: cord-boostrap.sh

Download source code and prep for a local build by installing Docker

```
./cord-bootstrap.sh -d
```

An `rcord-local` config is built from the {{ book.branch }} branch. Note that the make targets may not run if you aren't already in the `docker` group, so you'd need to logout/login and
rerun them.

```
./cord-bootstrap.sh -d -t "PODCONFIG=rcord-local.yml config" -t "build"
```

A prep for a mock/virtual/physical build, with a gerrit patchset applied:

```
./cord-bootstrap.sh -v -p orchestration/xos:1000/1
```

A virtual rcord pod, with tests runs afterward. Assumes that you're already in
the `libvirtd` group:

```
./cord-bootstrap.sh -v -t "PODCONFIG=rcord-virtual.yml config" -t "build" -t "pod-test"
```

### Manual Setup

The following tools are required to get started up CORD:

 - [Ansible](https://docs.ansible.com/ansible/intro_installation.html)
 - [Vagrant](https://www.vagrantup.com/downloads.html)
 - [Repo](https://source.android.com/source/downloading#installing-repo)
 - [Docker](https://www.docker.com/community-edition)

Downloading the source tree can be done by running:

<pre><code>mkdir cord && \
cd cord && \
repo init -u https://gerrit.opencord.org/manifest -b {{ book.branch }} && \
repo sync</code></pre>

The build system can be found in the `cord/build/` directory.

## Configuring a Build

### POD Config

Configuration for a specific build, specified in a YAML file that is used to
generate other configuration files.  These also specify the scenario and
profile to be used, allow for override the configuration in various ways, such
as hostnames, passwords, and other ansible inventory specific items. These
are specified in the `podconfigs` directory.

A minimal POD Config file must define:

`cord_scenario` - the name of the scenario to use, which is defined in a
directory under `scenarios`.

`cord_profile` - the name of a profile to use, defined as a YAML file in
`platform-install/profile_manifests`.

### Scenarios

Defines the physical or virtual environment that CORD will be installed
into, a default mapping of ansible groups to nodes, the set of Docker images
that can be built, and software and platform features are installed onto those
nodes. Scenarios are subdirectories of the `scenarios` directory, and consist
of a `config.yaml` file and possibly VM's specified in a `Vagrantfile`.

#### Included Scenarios

- `local`: Minimal set of containers running locally on the development host
- `mock`: Creates a single Vagrant VM with containers and DNS set up, without
  synchronizers
- `single`: Creates a single Vagrant VM with containers and DNS set up, with
  synchronizers and optional ElasticStack/ONOS
- `cord`: Physical or virtual multi-node CORD pod, with MaaS and OpenStack
- `opencloud`: Physical or virtual multi-node OpenCloud pod, with OpenStack

### Profile

The set of services that XOS on-boards into CORD -- the  _Service
Graph_, and other per-profile configuration for a CORD deployment.
These are located in `platform-install/profile_manifests`.

## Config Generation Overview

When a command to generate config such as `make PODCONFIG=rcord-mock.yml
config` is run, the following steps happen:

1. The POD Config file is read, in this case `genconfig/rcord-mock.yml`, which
   specifies the scenario and profile.
2. The Scenario config file is read, in this case `scenario/mock/config.yml`.
3. The contents of these files are combined into a master config variable, with
   the POD Config overwriting any config set in the Scenario.
4. The entire master config is written to `genconfig/config.yml`.
5. The `inventory_groups` variable is used to generate an ansible inventory
   file and put in `genconfig/inventory.ini`.
6. Various variables are used to generate the makefile config file
   `genconfig/config.mk`. This sets the targets invoked by `make build`

Note that the combination of the POD and Scenaro config in step #3 is not a
merge. If you define an item in the root of the POD Config that has subkeys,
it will overwrite every subkey defined in the Scenario.  This is most noticable
when setting the `inventory_groups` or `docker_image_whitelist`
variable. If changing either in a POD Config, you must recreate the
entire structure or list. This may seem inconvenient, but other list
or tree merging strategies lack a way to remove items from a tree
structure.

## Build Process Overview

The build process is driven by running `make`. The two most common makefile
targets are `config` and `build`, but there are also utility targets that are
handy to use during development.

### `config` make target

`config` requires a `PODCONFIG` argument, which is a name of a file in the
`podconfig` directory.  `PODCONFIG` defaults to `invalid`, so if you get errors
claiming an invalid config, you probably didn't set it, or set it to a filename
that doesn't exist.

#### Examples: `make config`

`make PODCONFIG=rcord-local.yml config`

`make PODCONFIG=opencloud-mock.yml config`

### `build` make target

`make build` performs the build process, and takes no arguments.  It may run
different targets specified by the scenario.

Most of the build targets in the Makefile don't leave artifacts behind, so we
write a placeholder file (aka "sentinels" or "empty targets") in the
`milestones` directory.

### Utility make targets

There are various utility targets:

 - `printconfig`: Prints the configured scenario and profile.

 - `xos-teardown`: Stop and remove a running set of XOS docker containers

 - `collect-diag`: Collect detailed diagnostic information on a deployed head
   and compute nodes, into `diag-<datestamp>` directory on the head node.

 - `compute-node-refresh`: Reload compute nodes brought up by MaaS into XOS,
   useful in the cord virtual and physical scenarios

 - `pod-test`: Run the `platform-install/pod-test-playbook.yml`, testing the
   virtual/physical cord scenario.

 - `vagrant-destroy`: Destroy Vagrant containers (for mock/virtual/physical
   installs)

 - `clean-images`: Have containers rebuild during the next build cycle. Does
   not actually delete any images, just causes imagebuilder to be run again.

 - `clean-genconfig`: Deletes the `make config` generated config files in
   `genconfig`, useful when switching between podconfigs

 - `clean-profile`: Deletes the `cord_profile` directory

 - `clean-all`: Runs `vagrant-destroy`, `clean-genconfig`, and `clean-profile`
   targets, removes all milestones. Good for resetting a dev environment back
   to an unconfigured state.

 - `clean-local`:  `clean-all` but for the `local` scenario - Runs
   `clean-genconfig` and `clean-profile` targets, removes local milestones.

The `clean-*` utility targets should modify the contents of the milestones
directory appropriately to cause the steps they clean up after to be rerun on
the next `make build` cycle.

### Target Logging

`make` targets that are built will create a per-target log file in the `logs`
directory. These are prefixed with a datestamp which is the same for every
target in a single run of make - re-running make will result in additional sets
of logs, even for the same target.

### Tips and Tricks

#### Debugging Make Failures

If you have a build failure and want to know which targets completed, running:

```
ls -ltr milestones ; ls -ltr logs
```

And looking for logfiles without a corresponding milestone will point you to
the make target(s) that failed.

#### Update XOS Container Images

To rebuild and update XOS container images, run:

```
make xos-update-images
make -j4 build
```

This will build new copies of all the images, then when build is run the newly
built containers will be restarted.

If you additionally want to stop all the XOS containers, clear the database,
and reload the profile, use `xos-teardown`:

```
make xos-teardown
make -j4 build
```

This will teardown the XOS container set, tell the build system to rebuild
images, then perform a build and reload the profile.

#### Use ElasticStack or ONOS with the `single` scenario

The single scenario is a medium-weight scenario for synchronizer development,
and has optional ElasticStack or ONOS functionality.

To use these, you would invoke the ONOS or ElasticStack milestone target before
the `build` target:

```
make PODCONFIG=rcord-single.yml config
make -j4 milestones/deploy-elasticstack
make -j4 build
```

or

```
make PODCONFIG=opencloud-single.yml config
make -j4 milestones/deploy-onos
make -j4 build
```

If you want to use both in combination, make sure to run the ElasticStack
target first, so ONOS can send logs to ElasticStack.

### Building Docker Images with imagebuilder.py

For docker images for XOS (and possibly others in the future) the build system
uses the imagebuilder script.  Run `imagebuilder.py -h` for a list of arguments
it supports.

For Docker images built by imagebuilder, the docker build logs are located in
the `image_logs` directory on the build host, which may differ between
scenarios.

The full list of all buildable images is in `docker_images.yml`, and the set of
images pulled in a particular build is controlled by the
`docker_image_whitelist` variable that is set on a per-scenario basis.

This script is in charge of guaranteeing that the code that has been checked
out and containers used by the system have the same code in them.  This is a
somewhat difficult task as we have parent/child relationships between
containers as well as components which are in multiple git repos in the source
tree and all of which could change independently, be on different branches, or
be manually modified during development. imagebuilder does this through a
combination of tagging and labeling which allows images to be prebuilt and
downloaded from dockerhub while still maintaining these guarantees.

imagebuilder takes as input a YAML file listing the images to be built, where
the Dockerfiles for those containers are located, and then goes about building
and tagging images.   The result of an imagebuilder run is:

 - Docker images in the local context
 - Optionally:
   - A YAML file which describes what actions imagebuilder performed (the `-a`
     option, default is `ib_actions.yml` )
   - A DOT file for graphviz that shows container relationships

While imagebuilder will pull down required images from dockerhub and build/tag
images, it does not push those images or delete obsolete ones.  These tasks are
left to other software (Ansible, Jenkins) which should take in imagebuilder's
YAML output and take the appropriate actions.

Additionally, there may be several operational tasks that take this as input.
Updating a running pod might involve stopping containers that have updated
images, starting containers with the new image, handling any errors if new
containers don't come up, then removing the obsolete images. These tasks go
beyond image building and are left to the deployment system.

