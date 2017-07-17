# Transitioning to the new build system

## What changed?


### Unified build system

All development should start in the `cord/build` directory, not in
`platform-install`.  The build process is controlled by a single unifed
Makefile across all developer workflows.

### Scenarios and Unified Profiles

Scenarios describe how a deployment will occur, and what VM's, containers, and
surrouning infrastructure services are brought up during a build.

There are no longer "mock" profiles (these were previously in
`platform-install/profile_manifests`) that need to be kept in sync with their
non-mock counterparts - the Scenario system is used to implement this
functionality.

The scenarios that most closely match the previous mock workflow are:

 - `local` - runs containers directly on the host that starts the build
 - `mock` - brings up a VM and loads just the core XOS, without synchronizers
 - `single` - brings up a VM and loads XOS and synchronizers


