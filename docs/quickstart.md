# CORD-in-a-Box Quick Start Guide

This tutorial guide walks through the steps to bring up a demonstration CORD "POD",
running in virtual machines on a single physical server (a.k.a. "CORD-in-a-Box"). The purpose
of this demonstration POD is to enable those interested in understanding how CORD works to
examine and interact with a running CORD environment.  It is a good place for
novice CORD users to start.

**NOTE:** *This tutorial installs a simplified version of a CORD POD on a single server
using virtual machines.  If you are looking for instructions on how to install a multi-node POD, you will
find them in [quickstart_physical.md](./quickstart_physical.md).  For more
details about the actual build process, look there.*

## What you need (Prerequisites)

You will need a *target server*, which will run both a development environment
in a Vagrant VM (used to deploy CORD) as well as CORD-in-a-Box itself.

Target server requirements:

* 64-bit server, with
  * 48GB+ RAM
  * 12+ CPU cores
  * 1TB+ disk
* Access to the Internet
* Ubuntu 14.04 LTS freshly installed (see [TBF]() for instruction on how to install Ubuntu 14.04).
* User account used to install CORD-in-a-Box has password-less *sudo* capability (e.g., like the `ubuntu` user)

### Target Server on CloudLab (optional)

If you do not have a target server available that meets the above requirements, you can borrow one on
[CloudLab](https://www.cloudlab.us).  Sign up for an account using your organization's
email address and choose "Join Existing Project"; for "Project Name" enter `cord-testdrive`.

**NOTE:** *CloudLab is supporting CORD as a courtesy.  It is expected that you will
not use CloudLab resources for purposes other than evaluating CORD.  If, after a
week or two, you wish to continue using CloudLab to experiment with or develop CORD,
then you must apply for your own separate CloudLab project.*

Once your account is approved, start an experiment using the `OnePC-Ubuntu14.04.5` profile
on either the Wisconsin or Clemson cluster.  This will provide you with a temporary target server
meeting the above requirements.

Refer to the [CloudLab documentation](https://docs.cloudlab.us) for more information.

## Download and Run the Script

On the target server, download the script that installs CORD-in-a-Box.  Then run it,
saving the screen output to a file called `install.out`:

```
curl -o ~/cord-in-a-box.sh https://raw.githubusercontent.com/opencord/cord/master/scripts/cord-in-a-box.sh
bash ~/cord-in-a-box.sh -t | tee ~/install.out
```

The script takes a *long time* (at least two hours) to run.  Be patient!  If it hasn't completely
failed yet, then assume all is well!

### Complete

The script builds the CORD-in-a-Box and runs a couple of tests to ensure that
things are working as expected.  Once it has finished running, you'll see a
**BUILD SUCCESSFUL** message.

The file `~/install.out` contains the full output of the build process.

### Using cord-in-a-box.sh to download development code from Gerrit

There is an `-b` option to cord-in-a-box.sh that will checkout a specific
changset from a gerrit repo during the run.  The syntax for this is `<project
path>:<changeset>/<revision>`.  It can be used multiple times - for example:

```
bash ~/cord-in-a-box.sh -b build/platform-install:1233/4 -b orchestration/service-profile:1234/2"
```

will check out the `platform-install` repo with changeset 1233, revision 4, and
`service-profile` repo changeset 1234, revision 2.

You can find the project path used by the `repo` tool in the [manifest/default.xml](https://gerrit.opencord.org/gitweb?p=manifest.git;a=blob;f=default.xml) file.

## Inspecting CORD-in-a-Box

CORD-in-a-Box installs the target server as a CORD head node, with OpenStack,
ONOS, and XOS services running inside VMs.  An OpenStack compute node
is also brought up inside a virtual machine.  You can see all the virtual
machines by running `virsh list` on the target server:

```
$ virsh list
 Id    Name                           State
----------------------------------------------------
 2     build_corddev                  running
 3     juju-1                         running
 4     ceilometer-1                   running
 5     glance-1                       running
 6     keystone-1                     running
 7     percona-cluster-1              running
 8     nagios-1                       running
 9     neutron-api-1                  running
 10    nova-cloud-controller-1        running
 11    openstack-dashboard-1          running
 12    rabbitmq-server-1              running
 13    onos-cord-1                    running
 14    onos-fabric-1                  running
 15    xos-1                          running
 18    build_compute_node             running
```

The `build_corddev` VM is the Vagrant development machine that executes
the build process.  It download and build Docker containers and publish them
to the target server. It then installs MaaS on the target server (for bare-metal
provisioning) and the ONOS, XOS, and OpenStack services in VMs.  This VM
can be entered as follows:

```
cd ~/opencord/build; vagrant ssh corddev
```

The CORD build environment is located in `/cord/build` inside this VM.  It is
possible to manually run individual steps in the build process here if you wish; see
[quickstart_physical.md](./quickstart_physical.md) for more information on
how to run build steps.

The VMs ending with names ending with `-1` are running the various CORD
head node services.  Two instances of ONOS are running, in
the `onos-cord-1` and `onos-fabric-1` VMs, though only `onos-cord-1` is used in
the CORD-in-a-Box.  XOS is running inside the `xos-1`
VM and is controlling ONOS and OpenStack.  You can get a deeper understanding of
the configuration of the target server by visiting [head_node_services.md](./head_node_services.md).
These VMs can be entered as follows:

```
ssh ubuntu@<vm-name>
```

The `build_compute_node` VM is the virtual compute node controlled by OpenStack.
This VM can be entered as follows:

```
ssh ubuntu@$( cord prov list | tail -1 | awk '{print $2}' )
```

### Docker Containers

The target server runs a Docker image registry, a Maven repository containing
the CORD ONOS apps, and a number of microservices used in bare-metal provisioning.
You can see these by running `docker ps`:

```
$ docker ps
CONTAINER ID        IMAGE                                                 COMMAND                  CREATED             STATUS              PORTS                           NAMES
adfe0a0b68e8        docker-registry:5000/mavenrepo:candidate              "nginx -g 'daemon off"   3 hours ago         Up 3 hours          443/tcp, 0.0.0.0:8080->80/tcp   mavenrepo
da6bdd4ca322        docker-registry:5000/cord-dhcp-harvester:candidate    "python /dhcpharveste"   3 hours ago         Up 3 hours          0.0.0.0:8954->8954/tcp          harvester
b6fe30f03f73        docker-registry:5000/cord-maas-switchq:candidate      "/go/bin/switchq"        3 hours ago         Up 3 hours                                          switchq
a1a7d4c7589f        docker-registry:5000/cord-maas-automation:candidate   "/go/bin/cord-maas-au"   3 hours ago         Up 3 hours                                          automation
628fb3725abf        docker-registry:5000/cord-provisioner:candidate       "/go/bin/cord-provisi"   3 hours ago         Up 3 hours                                          provisioner
fe7b3414cf88        docker-registry:5000/config-generator:candidate       "/go/bin/config-gener"   3 hours ago         Up 3 hours          1337/tcp                        generator
c7159495f9b4        docker-registry:5000/cord-ip-allocator:candidate      "/go/bin/cord-ip-allo"   3 hours ago         Up 3 hours                                          allocator
33bf33214d98        docker-registry:5000/consul:candidate                 "docker-entrypoint.sh"   3 hours ago         Up 3 hours                                          storage
b44509b3314e        registry:2.4.0                                        "/bin/registry serve "   3 hours ago         Up 3 hours          0.0.0.0:5000->5000/tcp          registry
79060bba9994        registry:2.4.0                                        "/bin/registry serve "   3 hours ago         Up 3 hours          0.0.0.0:5001->5000/tcp          registry-mirror
```

### MaaS GUI

You can access the MaaS (Metal-as-a-Service) GUI by pointing your browser to the URL
`http://<target-server>/MAAS/`.  Username and password are both `cord`.  For more
information on MaaS, see [the MaaS documentation](http://maas.io/docs).

### XOS GUI

You can access the XOS GUI by pointing your browser to URL
`http://<target-server>/xos/`.  Username is `padmin@vicci.org` and password is `letmein`.

The state of the system is that all CORD services have been onboarded to XOS.  You
can see them in the GUI by clicking _Services_ at left.  Clicking on the name of
a service will show more details about it.

A sample CORD subscriber has also been created.  A nice way to drill down into
the configuration is to click _Customize_ at left, add the _Diagnostic_
dashboard, and then click _Diagnostic_ at left.  To see the details of the
subscriber in this dashboard, click the green box next to _Subscriber_ and
select `cordSubscriber-1`.  The dashboard will change to show information
specific to that subscriber.

## Test results

After CORD-in-a-Box was set up, a couple of basic health
tests were executed on the platform.  The results of these tests can be
found near the end of `~/install.out`.

### test-vsg

This tests the E2E connectivity of the POD by performing the following
steps:
 * Sets up a sample CORD subscriber in XOS
 * Launches a vSG for that subscriber on the CORD POD
 * Creates a test client, corresponding to a device in the subscriber's household
 * Connects the test client to the vSG using a simulated OLT
 * Runs `ping` in the client to a public IP address in the Internet

Success means that traffic is flowing between the subscriber
household and the Internet via the vSG.  If it succeeded, you should see some
lines like these in the output:

```
TASK [test-vsg : Output from ping test] ****************************************
Thursday 27 October 2016  15:29:17 +0000 (0:00:03.144)       0:19:21.336 ******
ok: [10.100.198.201] => {
    "pingtest.stdout_lines": [
        "PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.",
        "64 bytes from 8.8.8.8: icmp_seq=1 ttl=47 time=29.7 ms",
        "64 bytes from 8.8.8.8: icmp_seq=2 ttl=47 time=29.2 ms",
        "64 bytes from 8.8.8.8: icmp_seq=3 ttl=47 time=29.1 ms",
        "",
        "--- 8.8.8.8 ping statistics ---",
        "3 packets transmitted, 3 received, 0% packet loss, time 2003ms",
        "rtt min/avg/max/mdev = 29.176/29.367/29.711/0.243 ms"
    ]
}
```

### test-exampleservice

This test builds on `test-vsg` by loading the *exampleservice* described in the
[Tutorial on Assembling and On-Boarding Services](https://wiki.opencord.org/display/CORD/Assembling+and+On-Boarding+Services%3A+A+Tutorial).
The purpose of the *exampleservice* is to demonstrate how new subscriber-facing services
can be easily deployed to a CORD POD. This test performs the following steps:
 * On-boards *exampleservice* into the CORD POD
 * Creates an *exampleservice* tenant, which causes a VM to be created and Apache to be loaded and configured inside
 * Runs a `curl` from the subscriber test client, through the vSG, to the Apache server.

Success means that the Apache server launched by the *exampleservice* tenant is fully configured
and is reachable from the subscriber client via the vSG.  If it succeeded, you should see some
lines like these in the output:

```
TASK [test-exampleservice : Output from curl test] *****************************
Thursday 27 October 2016  15:34:40 +0000 (0:00:01.116)       0:24:44.732 ******
ok: [10.100.198.201] => {
    "curltest.stdout_lines": [
        "ExampleService",
        " Service Message: \"hello\"",
        " Tenant Message: \"world\""
    ]
}
```

## Congratulations

If you got this far, you successfully built, deployed, and tested your
first CORD POD.

You are now ready to bring up a multi-node POD with a real switching
fabric and multiple physical compute nodes.  The process for doing so is described in
[quickstart_physical.md](./quickstart_physical.md).
