# Troubleshooting and Build System Internals

## Debugging make target Failures

`make` targets that are built will create a per-target log file in the `logs`
directory. These are prefixed with a timestamp which is the same for every
target in a single run of make - re-running make will result in additional sets
of logs, even for the same target.

If you have a build failure and want to know which targets completed, running:

```
ls -ltr milestones ; ls -ltr logs
```

And looking for logfiles without a corresponding milestone will point you to
the make target(s) that failed.

## Config Generation Overview

All configuration in CORD is driven off of YAML files which contain variables
used by Ansible, make, and Vagrant to build development and production
environments. A [glossary of build system variables](build_glossary.md) is
available which describes these variables and where they are used.

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
it will overwrite every subkey defined in the Scenario.  This is most noticeable
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

 - `xos-teardown`: Stop and remove a running set of XOS docker containers,
   removing the database.

 - `xos-update-images`: Rebuild the images used by XOS, without tearing down
   running XOS containers.

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

 - `clean-onos`: Stops the ONOS containers on the head node

 - `clean-openstack`: Cleans up and deletes all instances and networks created
   in OpenStack.

 - `clean-profile`: Deletes the `cord_profile` directory

 - `clean-all`: Runs `vagrant-destroy`, `clean-genconfig`, and `clean-profile`
   targets, removes all milestones. Good for resetting a dev environment back
   to an unconfigured state.

 - `clean-local`:  `clean-all` but for the `local` scenario - Runs
   `clean-genconfig` and `clean-profile` targets, removes local milestones.

The `clean-*` utility targets should modify the contents of the milestones
directory appropriately to cause the steps they clean up after to be rerun on
the next `make build` cycle.

### Development workflow

#### Updating XOS Container Images on a running pod

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

