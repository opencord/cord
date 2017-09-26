# Release Notes: Shared-Delusion

The Shared-Delusion release completes a major refactoring of CORD,
with the goal of improving the developer experience. A full listing of
Epics and Stories completed for Shared-Delusion (pulled from Jira) is
available [here](sd-jira.md), with the highlights summarized below.

## XOS Modeling Framework

Completed the XOS modeling framework for on-boarding
services. Specific features include:

* A new modeling language (*xproto*) and generative toolchain
  (*xosgen*).

* Support for specifying and enforcing security policies.

* Support for auto-generating the TOSCA and GUI interfaces.

* General data model clean-up, including the introduction of
  `ServiceInstance`, `ServiceInterface`, `InterfaceType`, and
  `ServiceInterfaceLink` models.

* Eliminated hard-coded VTN dependencies.

* Added a *Debug* tab to the GUI that can be used to show hidden fields,
  and extended the data model to support hiding fields.

* Migrated the R-CORD services to use the new modeling framework
  and the latest model changes.

* Removed hand-crafted APIs and eliminated the `xos-gui` container.

> Information on migrating services to Shared-Delusion can be found in the
> [CORD-4.0 Service Migration Guide](/xos/migrate_4.0.md).

## Build System

Redesigned build system to streamline and unify the developer
workflow. Specific features include:

* Uses `make` and transitions away from `gradle`, providing better support for
  incremental builds and unifying the development process.

* Added a *scenario* system that encompasses the *mock* functionality
  previously available but doesn't require multiple profiles to be maintained.

* Implemented an XOS configuration module.

* Supports building and pushing tagged images to Docker Hub, and downloading
  images that match the code that is checked out.

* Added configure targets that generate credentials for each build layer.

* Added make targets for XOS profile development.

* Added make targets to install versioned POD or CiaB

* Updated `ansible` and `docker-compose` versions.

> The new (Make-based) and old (Gradle-based) build systems will co-exist for a
> while, but the latter is being deprecated. Users are strongly encouraged to
> [use the new system](../install.md).

## Physical POD Deployment

Automated the physical POD deployment system. Specific items
include:

* Supports fabric configuration in ONOS and load POD configuration files in
  `pod-configs` repo.

* Automated switch software installation.

* Refactored Jenkins build process to use `yaml` configuration
  file instead of Jenkins variables, and to parameterize methods
  for commonly used functions.

## Logging Support

Added a comprehensive logging facility that integrates logs across multiple
components. The logging facility uses ELK Stack and can be accessed using
Kibana.

> Most services have not been upgraded to use the new logging system.

## QA and Testing

Improved test coverage, including:

* Support for automatically running unit tests.

* Support for full API coverage.

* Added additional data plane tests.

* Integrated control/data plane tests.

* Developed scaling tests for subscribers, vRouter, IGMP, vSG and vCPE.

## Fabric Enhancements

Continued to add features to the fabric, including:

* Upgraded to OFDPA 3.0 EA4.

* Updated fabric synchronizer to push routes instead of hosts.

* Support to enable/disable ports on STANDBY nodes.

* DHCP server HA supported by DHCP relay app.

* Extended network configuration to support multi-homing.

* Supports dual-home host failover.

* Refactored DHCP relay

## Performance Optimizations

Optimized DPDK and OvS performance, including:

* Bound fabric interfaces to DPDK

* Added portbindings to `networking_onos` Neutron plugin

* Modified JuJu charms to configure optimizations into OpenStack.

* Changed kernel boot options for nodes

> This is a beta feature, and is not automatically included in a build.

