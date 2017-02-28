# CORD Quickstart (Makefile edition)

## Getting the code

### Bootstrap script

There's a script `scripts/cord-bootstrap.sh` that will bootstrap an Ubuntu
14.04 system (such as a CloudLab node) with the proper tools to start the
makefile.  Run it with `-h` to see options.

### Manual setup

FIXME

The following tools are required to get started up CORD:

 - Ansible
 - Vagrant
 - Repo
 - Docker

## Config

### Pod Config

The configuration details for a specific pod installation.  These also specify the
scenario and profile to, override the configuration and to specify hostnames,
passwords, etc. where required.

### Scenarios

The set of VM's, containers, or physical nodes that a profile is installed
onto. Defines what platform features are available to a profile - for example,
synchronizers and OpenStack aren't set up in the `local` or `mock` scenario.

### Profile

The set of services, service graph, configuration for a CORD deployment.
Defined primarily in `platform-install/profile_manifests`.

## Creating Pod Config

Pod config files are 

## Scenarios

### local

Minimal set of docker containers running directly on the host

### mock

CORD Containers running in a single VM, with DNS and ElasticStack set up 

### rcord-virt

Virtual, multi-node R-CORD pod, with MaaS and OpenStack

### rcord

Physical, multi-node R-CORD pod, with MaaS and OpenStack

### opencloud-virt

Virtual, multi-node OpenCloud pod, with OpenStack

### opencloud

Physical, multi-node OpenCloud pod, with OpenStack

## Make targets

Most of the build targets in the Makefile don't leave artifacts behind, so we
write a placeholder file (aka "sentinels" or "empty targets") in the
`milestones` directory.

The utility targets that reset portions of the build should modify the contents
of the milestones directory appropriately.

### Logging

Target that are built will create a per-target log file in the `logs`
directory. These are prefixed with a timestamp which is the same for every
target in a single run of make - re-running make will result in additional sets
of logs, even for the same target.

For Docker images built by imagebuilder, the docker build logs are located in
the `image_logs` directory on the host they are built on. 

### imagebuilder

For docker images for XOS (and possibly others in the future) the build system
uses the imagebuilder script.  Run `imagebuilder.py -h` for a list of arguments
it supports.

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
left to other software (ansible, Jenkins) which should take in imagebuilder's
YAML output and take the appropriate actions. 

Additionally, there may be several operational tasks that take this as input.
Updating a running pod might involve stopping containers that have updated
images, starting containers with the new image, handling any errors if new
containers don't come up, then removing the obsolete images. These tasks go
beyond image building and are left to the deployment system.

