# Release Notes: Satisfying-Cactus

The Satisfying-Cactus (5.0) release includes R-CORD, E-CORD and M-CORD
profiles. Detailed information about these profiles can be found in
the [Service Profile Guide](../service-profiles.md). The following
summarizes the new features.

## Platform and Build System

* Added support for dynamically loading new services and service profiles into
a running system. R-CORD and E-CORD services converted to use new
dynamic loading mechanism, but M-CORD still uses `corebuilder`.

* Refactored build to isolate profile-specific information (e.g., models,
TOSCA templates). R-CORD, M-CORD, and E-CORD converted to use
refactoring.

* Added support for logging and diagnostics. See the
[Logging and Diagnostics](../operate/elk_stack.md) section of the
guide for more information.

* Added new scenarios to build:

  * `preppedpod`: Installs a CORD POD without MaaS on pre-prepared systems,
  which can run the R-CORD test suite.

  * `controlpod`: Installs XOS and ONOS without VNF support. Runs on Ubuntu
16.04 in preparation for updating the entire CORD platform.

  * `controlkube`: Preliminary support for running XOS on Kubernetes, in preparation
  for greater functionality in the next release.

* Preliminary integration of Kubernetes into CORD (pre-alpha):

  * Manages XOS containers

  * Works with `controlkube` Scenario

* Removed old TOSCA Engine.

## Trellis

* Upgraded ONOS to 1.12.0

## R-CORD

* Documented how to manually bring up VOLTHA in R-CORD

## M-CORD

* Integrated MME/HSS [Beta, undocumented]

* Integrated physical eNB

* Integreated ProgRAN

## E-CORD

* Automated Monitoring at EVC creation
