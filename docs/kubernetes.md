# Using CORD on Kubernetes (Exeperimental)

## Podconfigs & Scenarios

There are currently two kubernetes specific scenarios, `controlkube` and `preppedkube`.

### controlkube

This is the "small" installation, and brings up 3 nodes with 2GB of ram each.
It's designed for laptop or testing use.

### preppedkube

This is the "small" installation, and brings up 3 nodes with 16GB of ram each.
It's designed for testing and use on physical hardware.

## Building a Kubernetes enabled CORD pod

Currently, virtual deployment with Vagrant is only supported on linux, with
libvirt as a backend.

## `make` targets

Remove all kubespray related targets: `make clean-kubespray`

