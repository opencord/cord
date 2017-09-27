# Troubleshooting and Build System Internals

> NOTE: Most of the debugging below assumes that you are logged into the
> `config` node, which is the node where `make` is run to start the build, and
> have checked out the CORD source tree to `~/cord`.

## Debugging make target Failures

The CORD build process uses `make` and frequently will have multiple concurrent
jobs running at the same time to speed up the build. Unfortunately, this has
two downsides:

1. The output of all concurrent jobs is shown at the same time, so the combined
   output can be very confusing to read and it might not be clear what failed.
2. If a target task fails, `make` will wait until all other jobs have finished,
   and it may not be apparent which has failed.

To address the first issue most CORD `make` targets will create a per-target
log file in the `~/cord/build/logs` directory - this output isn't interleaved
with other make targets and will be much easier to read.

```
~/cord/build$ make printconfig
Scenario: 'cord'
Profile: 'rcord'
~/cord/build$ cd logs
~/cord/build/logs$ ls -tr
README.md                             20171003T132550Z_publish-maas-images
20171003T132547Z_config.mk            20171003T132550Z_docker-images
20171003T132550Z_ciab-ovs             20171003T132550Z_core-image
20171003T132550Z_prereqs-check        20171003T132550Z_deploy-maas
20171003T132550Z_vagrant-up           20171003T132550Z_publish-onos-apps
20171003T132550Z_vagrant-ssh-install  20171003T132550Z_deploy-mavenrepo
20171003T132550Z_copy-cord            20171003T132550Z_publish-docker-images
20171003T132550Z_cord-config          20171003T132550Z_deploy-onos
20171003T132550Z_prep-buildnode       20171003T132550Z_start-xos
20171003T132550Z_copy-config          20171003T132550Z_onboard-profile
20171003T132550Z_build-maas-images    20171003T132550Z_deploy-openstack
20171003T132550Z_build-onos-apps      20171003T132550Z_setup-automation
20171003T132550Z_prep-headnode        20171003T132550Z_compute1-up
20171003T132550Z_prep-computenode     20171003T143046Z_collect-diag
20171003T132550Z_maas-prime           20171003T143046Z_pod-test
```

The logs are prefixed with a timestamp which is the same for every target in a
single run of make. Re-running make will result in additional sets of logs,
even for the same target, so make sure to look at the newest log when
debugging.

The various `make clean-*` targets will not delete logs between sets of builds,
so you may want to manually delete these periodically on a heavily used copy of
the CORD source tree.

There are two solutions to the second issue. If you compare the list of
milestones to the list of logs, you can determine which logs failed to result
in a milestone, and thus did not complete:

```
$ cd ~/cord/build
$ ls -ltr milestones ; ls -ltr logs
-rw-r--r-- 1 zdw xos-PG0 181 Oct  3 13:23 README.md
-rw-r--r-- 1 zdw xos-PG0   0 Oct  3 13:25 ciab-ovs
-rw-r--r-- 1 zdw xos-PG0   0 Oct  3 13:26 prereqs-check
-rw-r--r-- 1 zdw xos-PG0   0 Oct  3 13:27 vagrant-up
-rw-r--r-- 1 zdw xos-PG0   0 Oct  3 13:27 vagrant-ssh-install
-rw-r--r-- 1 zdw xos-PG0   0 Oct  3 13:27 copy-cord
-rw-r--r-- 1 zdw xos-PG0   0 Oct  3 13:28 cord-config
-rw-r--r-- 1 zdw xos-PG0   0 Oct  3 13:30 prep-buildnode
-rw-r--r-- 1 zdw xos-PG0   0 Oct  3 13:30 copy-config
-rw-r--r-- 1 zdw xos-PG0      76 Oct  3 13:23 README.md
-rw-r--r-- 1 zdw xos-PG0    8819 Oct  3 13:25 20171003T132547Z_config.mk
-rw-r--r-- 1 zdw xos-PG0    4655 Oct  3 13:25 20171003T132550Z_ciab-ovs
-rw-r--r-- 1 zdw xos-PG0    3665 Oct  3 13:26 20171003T132550Z_prereqs-check
-rw-r--r-- 1 zdw xos-PG0  110477 Oct  3 13:27 20171003T132550Z_vagrant-up
-rw-r--r-- 1 zdw xos-PG0    1712 Oct  3 13:27 20171003T132550Z_vagrant-ssh-install
-rw-r--r-- 1 zdw xos-PG0    2204 Oct  3 13:27 20171003T132550Z_copy-cord
-rw-r--r-- 1 zdw xos-PG0   40515 Oct  3 13:28 20171003T132550Z_cord-config
-rw-r--r-- 1 zdw xos-PG0    4945 Oct  3 13:29 20171003T132550Z_prep-buildnode
-rw-r--r-- 1 zdw xos-PG0    8246 Oct  3 13:30 20171003T132550Z_copy-config
-rw-r--r-- 1 zdw xos-PG0   21229 Oct  3 13:33 20171003T132550Z_build-maas-images
-rw-r--r-- 1 zdw xos-PG0 1069181 Oct  3 13:33 20171003T132550Z_build-onos-apps
```

In the case above, `build-maas-images` and `build-onos-apps` failed to reach
the milestone state and should be inspected for errors.

Additionally, `make` job failures generally have this syntax:
`make: *** [targetname] Error #`, and can be found in log files with this
`grep` command:

```
$ grep -F "make: ***" ~/build.out
make: *** [milestones/build-maas-images] Error 2
make: *** Waiting for unfinished jobs....
make: *** [milestones/build-onos-apps] Error 2
```

## Collecting POD diagnostics

There is a `collect-diag` make target that will collect diagnostic information
for a Virtual or Physical POD. It is run automatically when the `pod-test`
target is run, but can be run manually at any time:

```
$ cd ~/cord/build
$ make collect-diag
```

Once it's finished running, ssh to the head node and look for a directory named
`~/diag-<timestamp>` - a new directory will be created on repeated runs.

These directories  will contain subfolders with docker container logs, various
diagnostic commands run on the head node, Juju status, ONOS diagnostics, and
OpenStack status:

```
$ ssh head1
vagrant@head1:~$ ls
diag-20171003T203058
vagrant@head1:~$ cd diag-20171003T203058/
vagrant@head1:~/diag-20171003T203058$ ls *
docker:
allocator                            rcord_vrouter-synchronizer_1
automation                           rcord_vsg-synchronizer_1
generator                            rcord_vtn-synchronizer_1
harvester                            rcord_vtr-synchronizer_1
mavenrepo                            rcord_xos_chameleon_1
onoscord_xos-onos_1                  rcord_xos_core_1
onosfabric_xos-onos_1                rcord_xos_db_1
provisioner                          rcord_xos_gui_1
rcord_addressmanager-synchronizer_1  rcord_xos_redis_1
rcord_consul_1                       rcord_xos_tosca_1
rcord_exampleservice-synchronizer_1  rcord_xos_ui_1
rcord_fabric-synchronizer_1          rcord_xos_ws_1
rcord_onos-synchronizer_1            registry
rcord_openstack-synchronizer_1       registry-mirror
rcord_registrator_1                  storage
rcord_volt-synchronizer_1            switchq

head:
arp_-n                cat__etc_resolv_conf  route_-n           sudo_virsh_list
brctl_show            date                  sudo_docker_ps_-a
cat__etc_lsb-release  ifconfig_-a           sudo_lxc_list

juju:
juju_status_--format_json     juju_status_--format_tabular
juju_status_--format_summary

onos:
apps_-s_-a                   cordvtn-nodes  flows        nodes
bundle_list                  cordvtn-ports  hosts        ports
cordvtn-networks             devices        log_display  rest_hosts
cordvtn-node-check_compute1  dhcp-list      netcfg       summary

openstack:
glance_image-list     neutron_net-list     nova_host-list
keystone_tenant-list  neutron_port-list    nova_hypervisor-list
keystone_user-list    neutron_subnet-list  nova_list_--all-tenants
```

## Raising ONOS log levels

If you're working on an ONOS app and want to raise the logging level of that
specific ONOS app when debugging, there is an `onos-debug` target which will
set the level of the any services in the
[onos_debug_appnames](build_glossary.html#onosdebugappnames) list to
[onos_debug_level](build_glossary.html#onosdebuglevel).

Add the names of the ONOS apps to `onos_debug_appnames` and add `onos-debug`
to the `build_targets` list in your POD config file in `~/cord/build/podconfig/`.

This must be done before running the `make config` target - it won't affect an
already-running POD.

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

