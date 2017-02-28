# CORD Quickstart (Makefile edition)

## TL;DR Version

 - Setup your build environment. On a bare Ubuntu 14.04 system, this can be
   done by running `scripts/cord-bootstrap.sh` or manually.
 - Pick a Pod Config, such as `rcord-mock.yml` from the podconfig directory.
 - Run `make PODCONFIG=podconfig.yml config` (see 'podconfig' directory for
   filenames) to generate a configuration into the `genconfig/` directory.
 - Run `make build` to build CORD.

## Setup the build environment

### Bootstrap script

There's a script `scripts/cord-bootstrap.sh` that will bootstrap an Ubuntu
14.04 system (such as a CloudLab node) by installing the proper tools and
checkout the codebase with repo.  Run it with `-h` to see help/options.

It can be downloaded and run on a system via:

```
curl -o ~/cord-bootstrap.sh https://raw.githubusercontent.com/opencord/cord/master/scripts/cord-bootstrap.sh
bash ~/cord-bootstrap.sh
```

### Manual setup

The following tools are required to get started up CORD:

 - Ansible
 - Vagrant
 - Repo
 - Docker (if running local profile)

*FIXME* -- add more detail on manual setup process

## Configuring a build

### Pod Config

Configuration for a specific pod, specified in a YAML file that is used to
generate other configuration files.  These also specify the scenario and
profile to be used, allow for override the configuration in various ways, such
as hostnames, passwords, and other ansible inventory specific items. These are
specified in the `podconfigs` directory.

A minimal Pod Config file must define:

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

- `local`: Minimal set of containers running directly on the host
- `mock`: Containers running in a single VM, with DNS and ElasticStack set up
- `cord`: Physical or virtual multi-node CORD pod, with MaaS and OpenStack
- `opencloud`: Physical or virtual multi-node OpenCloud pod, with OpenStack

### Profile

The set of CORD services brought into XOS, the service graph, and other
per-profile configuration for a CORD deployment. These are located in
`platform-install/profile_manifests`.

## Config generation overview

When a command to generate config such as `make PODCONFIG=rcord-mock.yml
config` is run, the following steps happen:

1. The Pod Config file is read, in this case `genconfig/rcord-mock.yml`, which
   specifies the scenario and profile.
2. The Scenario config file is read, in this case `scenario/mock/config.yml`.
3. The contents of these files are combined into a master config variable, with
   the Pod Config overwriting any config set in the Scenario.
4. The entire master config is written to `genconfig/config.yml`.
5. The `inventory_groups` variable is used to generate an ansible inventory
   file and put in `genconfig/inventory.ini`.
6. Various variables are used to generate the makefile config file
   `genconfig/config.mk`. This sets the targets invoked by `make build`

Note that the combination of the Pod and Scenaro config in step #3 is not a
merge - if you define an item in the root of the Pod Config that has subkeys,
it will overwrite every subkey defined in the Scenario.  This is most noticable
when setting the `inventory_groups` or `docker_image_whitelist` variable - if
changing either in a Pod Config, you must recreate the entire structure or
list. This may seem inconvenient, but other list or tree merging strategies
lack a way to remove items from those structures.

## Build process overview

The two most common makefile targets are `config` and `build`.

### Config make target

`config` needs the `PODCONFIG` argument set to be useful, or will error out.

### Build make target

`build` performs the build process.

Most of the build targets in the Makefile don't leave artifacts behind, so we
write a placeholder file (aka "sentinels" or "empty targets") in the
`milestones` directory.

### Utility make targets

The utility targets that reset portions of the build should modify the contents
of the milestones directory appropriately.

*FIXME* -- document utility targets here

### make target logging

Target that are built will create a per-target log file in the `logs`
directory. These are prefixed with a timestamp which is the same for every
target in a single run of make - re-running make will result in additional sets
of logs, even for the same target.

For Docker images built by imagebuilder, the docker build logs are located in
the `image_logs` directory on the host they are built on.

### imagebuilder

For docker images for XOS (and possibly others in the future) the build system
uses the imagebuilder script.  Run `imagebuilder.py -h` for a list of arguments
it supports.  The full list of all buildable images is in `docker_images.yml`,
and the set of images pulled in a particular build is controlled by the
`docker_image_whitelist` variable that is most frequently set on a per-Scenario
basis.

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

