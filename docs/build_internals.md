# Build Process Internals

## Config Generation

All configuration in CORD is driven off of YAML files which contain variables
used by Ansible, make, and Vagrant to build development and production
environments. A [glossary of build system variables](build_glossary.md) is
available which describes these variables and where they are used.

When a command to generate config such as `make PODCONFIG=rcord-mock.yml
config` is run, the following steps happen:

1. The POD Config file is read, in this case
   [orchestration/profiles/rcord/podconfig/rcord-mock.yml](https://github.com/opencord/rcord/blob/{{
     book.branch }}/podconfig/rcord-mock.yml), which specifies the scenario and
     profile.  In virtual cases, frequently no further information is required,
     but in a physical POD, at least the [inventory](#inventory) configuration
     must be specified.

2. The Scenario config file is read, in this case
   [build/scenarios/mock/config.yml](https://github.com/opencord/cord/blob/{{
   book.branch }}/scenarios/mock/config.yml). The scenario determines which sets
   of components of CORD are installed, by controlling which make targets are
   run.  It also contains a default inventory, which is used for development
   and testing of the scenario with virtual machines.

3. The Profile config file is read, in this case
   [orchestration/profiles/rcord/rcord.yml](https://github.com/opencord/rcord/blob/{{
   book.branch }}/rcord.yml).  The profile contains the use-case
   _Service_Graph_ and additional configuration specific to the
   configuration.

4. The contents of these three files are combined into a master config
   variable. The Scenario overwrites any config set in the Profile, and the POD
   Config overwrites any config set in the Scenario or Profile.

5. The entire master config is written to `genconfig/config.yml`.

6. The `inventory_groups` variable is used to generate an ansible inventory
   file and put in `genconfig/inventory.ini`.

7. Various variables are used to generate the makefile config file
   `genconfig/config.mk`. This sets the targets invoked by `make build`, which
   is the `build_targets` list.

> NOTE: The combination of the POD config, Scenario config, and Profile config
> in step #4 is not a union or merge. If you define an item in the root of the
> POD Config that is complex and has subkeys, it will overwrite every subkey
> defined in the Scenario or Profile.
>
> This is most noticeable when setting the `inventory_groups` or
> `docker_image_whitelist` variable. If you are creating a change in a POD
> Config, you must recreate the entire structure or list.
>
> This may seem inconvenient, but other list or tree merging strategies
> available in Ansible lack a way to remove items from a tree structure, which
> is an incomplete solution.

## Build Process Steps

The build process is driven by running `make`. The two most common makefile
targets are `config` and `build`, but there are also utility targets that are
handy to use during development.

### `config` make target

`config` requires a `PODCONFIG` argument, which is the name of a file in
`orchestration/profiles/<use-case>/podconfig/`. `PODCONFIG` defaults to
`invalid`, so if you get errors claiming an invalid config, you probably didn't
run the `make config` step, or set it to a filename or `use-case` path that
doesn't exist.  Additionally, a `PODCONFIG_PATH` variable can be used, which
takes an arbitrary path, when the podconfig is not within the use-case
directory. `PODCONFIG_PATH` overrides `PODCONFIG` if both are set.

#### Examples: `make config`

`make PODCONFIG=rcord-local.yml config`

`make PODCONFIG=opencloud-mock.yml config`

### `build` make target

`make build` performs the build process, and usualy takes no arguments. The
targets run are specified in the scenario in the `build_targets` list.

Most of the build targets in the Makefile don't leave artifacts behind, so we
write a placeholder file (aka "sentinels" or "empty targets") in the
`build/milestones` directory.

See [adding targets to the Makefile](#adding-targets-to-the-makefile) for
Makefile development information.

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
  `genconfig`, useful when switching between POD configs

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

#### Updating XOS Container Images on a running POD

To rebuild and update XOS container images, run:

```shell
make xos-update-images
make -j4 build
```

This will build new copies of all the images, then when build is run the newly
built containers will be restarted.

If you additionally want to stop all the XOS containers, clear the database,
and reload the profile, use `xos-teardown`:

```shell
make xos-teardown
make -j4 build
```

This will teardown the XOS container set, tell the build system to rebuild
images, then perform a build and reload the profile.

## Creating a Scenario

Creating a new scenarios requires creating 3 items:

1. Creating a scenario config file, in `build/scenarios/<scenario-name>/config.yml`.

2. Creating any makefile targets necessary for new features

3. The Virtual machine configuration (stored in a `Vagrantfile`) for testing
   the scenario.

By default, the inventory in a Scenario is specific to the machines created in
the `Vagrantfile`, and if needed elsewhere the

### Creating the scenario config.yaml

A scenario configuration yaml file must define the following items:

1. `build_targets`, which is a list of milestones to complete. In most cases,
   there is only one item in this list, and all other milestone targets are
   invoked via dependencies within the makefile.

2. `docker_image_whitelist`, which is the list of [images used in the
   scenario](build_images.md#adding-a-new-docker-image-to-cord).

3. `inventory_groups`, which specifies the [inventory](install.md#inventory)
   used for testing the scenario in a virtual installation.

Most scenarios also define the following:

- `vagrant_vms`, a list of the Vagrant VM's to bring up for testing the
  scenario in a virtual environment.

- Various Vagrant configuration variables, used to [configure VM's in the
  Vagrantfile](#creating-a-scenario-vagrantfile).

- `headnode`, and possibly `buildnode`, which specify the hosts that are logged
  into with SSH when running various build steps that have to be executed
  locally on those nodes.  These names should match the names or IP addresses
  given in `inventory_groups`, but in a SSH compatible format. Some example of
  this: `<host>`, `<user>@<host>`, `<user>@<ipaddr>`.

- `physical_node_list`, which is used for DNS, DHCP, and network configuration
  of compute nodes.  It specifies the last octet of the IP addresses used for
  each node on the management and fabric networks, and the management network
  DNS names assigned to the node.  This should match or be a superset of every
  system listed in `inventory_groups`.

### Adding targets to the Makefile

If you would like to add functionality to the makefile for inclusion in a
scenario, the process is:

1. Create an ansible playbook or script for your task.  In most cases this is
   in the `platform-install` if the task applies to the entire platform, or in
   `maas` if it's specific to the MaaS hardware deployment component.

2. Add a target to the makefile for the task. Many paths to source code
   locations, names of binaries, and similar are variables in the Makefile, so
   check the [top of the Makefile](https://github.com/opencord/cord/blob/{{
   book.branch }}/Makefile) for these.

   The general format of a make target is:

   ```make
   $(M)/my-target: | $(m)prereq-target
     $(ANSIBLE_PB) $(PI)/my-task-playbook.yml $(LOGCMD)
     touch $@
   ```

   The `touch $@` is to create a create a file in the `milestones` directory
   (make variable for the path to `milestones` is `$(M)`) after the target is
   run.

3. Create dependencies within the makefile to depend upon your task.  Be aware
   of adding dependencies that could break other scenarios, so do this with
   care.

To handle the case where a target may be used only in a subset of scenarios,
`prereqs_*` lists of milestones are added to the scenario, and when `make
config` is run, these are added to the `genconfig/config.mk` file, in a
capitalized version.  For example the `start_xos_prereqs` list adds milestones
to the `START_XOS_PREREQS` variable (the `$(M)` milestones directory path is
added to every item in the list)

If you need to add a new `prereq_*` variable, see the
[config.mk.j2](https://github.com/opencord/cord/blob/{{ book.branch
}}/ansible/roles/genconfig/templates/config.mk.j2) and
[Makefile](https://github.com/opencord/cord/blob/{{ book.branch }}/Makefile).

### Creating a scenario Vagrantfile

A Vagrantfile should be created for the scenario, for testing and development
work.

Vagrantfiles can be thought of as a ruby Domain Specific Language (DSL), and as
such can take advantage of other ruby language features.  This is used in CORD
to read the `genconfig/config.yml` file generated during the `make config` step
as the `settings` variable , which allows for the VMs to  have additional
configuration at runtime - for example, the amount of memory used in a VM is
frequently set this way.

Some example configuration variables found in scenarios that are used in
Vagrantfiles:

- `vagrant_box` - The name of the Vagrant Box image used for the VM's.  This is
  currently either `ubuntu/trusty64` or `bento/ubuntu-16.04` depending on the
  base OS used.

- `*_vm_mem` - The amount of memory allocated for the VM

- `*_vm_cpu` - The number of CPU's allocated for the VM
