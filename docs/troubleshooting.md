# Troubleshooting

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

```shell
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

```shell
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

```shell
$ grep -F "make: ***" ~/build.out
make: *** [milestones/build-maas-images] Error 2
make: *** Waiting for unfinished jobs....
make: *** [milestones/build-onos-apps] Error 2
```

## Collecting POD diagnostics

There is a `collect-diag` make target that will collect diagnostic information
for a Virtual or Physical POD. It is run automatically when the `pod-test`
target is run, but can be run manually at any time:

```shell
cd ~/cord/build
make collect-diag
```

Once it's finished running, ssh to the head node and look for a directory named
`~/diag-<timestamp>` - a new directory will be created on repeated runs.

These directories  will contain subfolders with docker container logs, various
diagnostic commands run on the head node, Juju status, ONOS diagnostics, and
OpenStack status:

```shell
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
rcord_xos_tosca_1                    storage
rcord_exampleservice-synchronizer_1  rcord_xos_ui_1
rcord_fabric-synchronizer_1          rcord_xos_ws_1
rcord_onos-synchronizer_1            registry
rcord_openstack-synchronizer_1       registry-mirror
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

## prereqs-common failures

### Hardware Requirements

For a virtaul install, make sure the system you're using [meets the hardware requirements](install_virtual.md#what-you-need-prerequisites).

### CPU Quantity Check

The Head node must have at least 12 CPU cores.  Verify that your system
has adequate CPU resources.

### CPU KVM Check

The nodes must support KVM virtualization on the CPUs being used.  You
may have to turn it on in the firmware (BIOS, EFI, etc.) of your system.
 Sometimes a firmware update is required to support this if the system
is older.

If you're trying to implement this in a "nested virtualization"
environment, the virtualization system must support this and have it
turned on for your VM. 

Systems that support nested virtualization:

- VMWare - <https://communities.vmware.com/docs/DOC-8970>, <https://communities.vmware.com/community/vmtn/bestpractices/nested>
- Xen - <http://wiki.xenproject.org/wiki/Nested_Virtualization_in_Xen>
- KVM - <https://fedoraproject.org/wiki/How_to_enable_nested_virtualization_in_KVM> , <https://wiki.archlinux.org/index.php/KVM#Nested_virtualization>
- Hyper V - <https://msdn.microsoft.com/en-us/virtualization/hyperv_on_windows/user_guide/nesting>

Systems that lack nested virtualization:

- Virtualbox - track this feature request: <https://www.virtualbox.org/ticket/4032>

### DNS Lookup Check

The nodes must be able to look up hosts on the internet, to download software,
VM images, and other items. This verifies that your DNS is working properly by
performing lookups with the `dig` command, and that the query result is
correct, not modified or redirected to another server.

If this step fails please verify that DNS is set up properly (usually in
`/etc/resolv.conf`).

### DNS Global Root Connectivity Check

A DNS server is run on the head node to resolve internal DNS for the pod, and
for non-pod domains it makes requests to the global DNS root servers.

If this step fails, verify that you do not have a firewall that is blocking
outgoing DNS requests to the internet, or filtering DNS requests so that they
go to only specific servers.

### HTTP Download Check

This verifies that you can download files from the internet, and the integrity
of those files by checking a checksum on the download. If this fails, make sure
you don't have a proxy or other firewall blocking or modifying network traffic.
You can test this manually with `curl` or `wget`.

### HTTPS Download Check

The same as the HTTP check above, but over HTTPS. If this fails but the
previous HTTP check succeeds, check that you don't have an HTTPS specific proxy
or firewall, and that the date and time on the node is accurate.

## dns-configure failures

### Check that VM's can be found in DNS

This likely means that something has gone wrong either with the
connectivity or setup of the DNS server, or with the client
configuration.  Verify that `/etc/resolv.conf` on all the nodes is using
the IP address of the head node's default interface as the DNS server.

## Raising ONOS log levels

If you're working on an ONOS app and want to raise the logging level of that
specific ONOS app when debugging, there is an `onos-debug` target which will
set the level of the any services in the
[onos_debug_appnames](build_glossary.html#onosdebugappnames) list to
[onos_debug_level](build_glossary.html#onosdebuglevel).

Add the names of the ONOS apps to `onos_debug_appnames` and add `onos-debug`
to the `build_targets` list in your POD config file.

This must be done before running the `make config` target - it won't affect an
already-running POD.

