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
  * 32GB+ RAM
  * 8+ CPU cores
  * 200GB+ disk
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

CORD-in-a-Box creates a virtual CORD POD running inside Vagrant VMs.
You can inspect their current status as follows:

```
~$ cd opencord/build/
~/opencord/build$ vagrant status
Current machine states:

corddev                   running (libvirt)
prod                      running (libvirt)
switch                    not created (libvirt)
testbox                   not created (libvirt)
compute_node-1            running (libvirt)
compute_node-2            not created (libvirt)
```

### corddev VM

The `corddev` VM is a development machine used by the `cord-in-a-box.sh` script to drive the
installation.  It downloads and builds Docker containers and publishes them
to the virtal head node (see below). It then installs MaaS on the virtual head node (for bare-metal
provisioning) and the ONOS, XOS, and OpenStack services in containers.  This VM
can be entered as follows:

```
$ ssh corddev
```

The CORD build environment is located in `/cord/build` inside this VM.  It is
possible to manually run individual steps in the build process here if you wish; see
[quickstart_physical.md](./quickstart_physical.md) for more information on
how to run build steps.

### prod VM

The `prod` VM is the virtual head node of the POD.  It runs the OpenStack,
ONOS, and XOS services inside containers.  It also simulates a subscriber
devices using a container.  To enter it, simply type:

```
$ ssh prod
```

Inside the VM, a number of services run in Docker and LXD containers.

```
vagrant@prod:~$ docker ps
CONTAINER ID        IMAGE                                                 COMMAND                  CREATED             STATUS              PORTS                                                                                            NAMES
043ea433232c        xosproject/xos-ui                                     "python /opt/xos/mana"   About an hour ago   Up About an hour    8000/tcp, 0.0.0.0:8888->8888/tcp                                                                 cordpod_xos_ui_1
40b6b05be96c        xosproject/xos-synchronizer-exampleservice            "bash -c 'sleep 120; "   About an hour ago   Up About an hour    8000/tcp                                                                                         cordpod_xos_synchronizer_exampleservice_1
cfd93633bfae        xosproject/xos-synchronizer-vtr                       "bash -c 'sleep 120; "   2 hours ago         Up 2 hours          8000/tcp                                                                                         cordpod_xos_synchronizer_vtr_1
d2d2a0799ca0        xosproject/xos-synchronizer-vsg                       "bash -c 'sleep 120; "   2 hours ago         Up 2 hours          8000/tcp                                                                                         cordpod_xos_synchronizer_vsg_1
480b5e85e87d        xosproject/xos-synchronizer-onos                      "bash -c 'sleep 120; "   2 hours ago         Up 2 hours          8000/tcp                                                                                         cordpod_xos_synchronizer_onos_1
9686909333c3        xosproject/xos-synchronizer-fabric                    "bash -c 'sleep 120; "   2 hours ago         Up 2 hours          8000/tcp                                                                                         cordpod_xos_synchronizer_fabric_1
de53b100ce20        xosproject/xos-synchronizer-openstack                 "bash -c 'sleep 120; "   2 hours ago         Up 2 hours          8000/tcp                                                                                         cordpod_xos_synchronizer_openstack_1
8a250162424c        xosproject/xos-synchronizer-vtn                       "bash -c 'sleep 120; "   2 hours ago         Up 2 hours          8000/tcp                                                                                         cordpod_xos_synchronizer_vtn_1
f1bd21f98a9f        xosproject/xos                                        "python /opt/xos/mana"   2 hours ago         Up 2 hours          0.0.0.0:81->81/tcp, 8000/tcp                                                                     cordpodbs_xos_bootstrap_ui_1
e41ccc63e7dd        xosproject/xos                                        "bash -c 'cd /opt/xos"   2 hours ago         Up 2 hours          8000/tcp                                                                                         cordpodbs_xos_synchronizer_onboarding_1
7fdeb35614e8        redis                                                 "docker-entrypoint.sh"   2 hours ago         Up 2 hours          6379/tcp                                                                                         cordpodbs_xos_redis_1
84fa440023bf        xosproject/xos-postgres                               "/usr/lib/postgresql/"   2 hours ago         Up 2 hours          5432/tcp                                                                                         cordpodbs_xos_db_1
ef0dd85badf3        onosproject/onos:latest                               "./bin/onos-service"     2 hours ago         Up 2 hours          0.0.0.0:6653->6653/tcp, 0.0.0.0:8101->8101/tcp, 0.0.0.0:8181->8181/tcp, 0.0.0.0:9876->9876/tcp   onosfabric_xos-onos_1
e2348ddee189        xos/onos                                              "./bin/onos-service"     2 hours ago         Up 2 hours          0.0.0.0:6654->6653/tcp, 0.0.0.0:8102->8101/tcp, 0.0.0.0:8182->8181/tcp, 0.0.0.0:9877->9876/tcp   onoscord_xos-onos_1
f487db716d8c        docker-registry:5000/mavenrepo:candidate              "nginx -g 'daemon off"   3 hours ago         Up 3 hours          443/tcp, 0.0.0.0:8080->80/tcp                                                                    mavenrepo
0a24bcc3640a        docker-registry:5000/cord-maas-automation:candidate   "/go/bin/cord-maas-au"   3 hours ago         Up 3 hours                                                                                                           automation
c5448fb834ac        docker-registry:5000/cord-maas-switchq:candidate      "/go/bin/switchq"        3 hours ago         Up 3 hours          0.0.0.0:4244->4244/tcp                                                                           switchq
7690414fec4b        docker-registry:5000/cord-provisioner:candidate       "/go/bin/cord-provisi"   3 hours ago         Up 3 hours          0.0.0.0:4243->4243/tcp                                                                           provisioner
833752cd8c71        docker-registry:5000/config-generator:candidate       "/go/bin/config-gener"   3 hours ago         Up 3 hours          1337/tcp, 0.0.0.0:4245->4245/tcp                                                                 generator
300df95eb6bd        docker-registry:5000/consul:candidate                 "docker-entrypoint.sh"   3 hours ago         Up 3 hours                                                                                                           storage
e0a68af23e9c        docker-registry:5000/cord-ip-allocator:candidate      "/go/bin/cord-ip-allo"   3 hours ago         Up 3 hours          0.0.0.0:4242->4242/tcp                                                                           allocator
240a8b3e5af5        docker-registry:5000/cord-dhcp-harvester:candidate    "/go/bin/harvester"      3 hours ago         Up 3 hours          0.0.0.0:8954->8954/tcp                                                                           harvester
9444c39ffe10        registry:2.4.0                                        "/bin/registry serve "   3 hours ago         Up 3 hours          0.0.0.0:5000->5000/tcp                                                                           registry
13d2f04e3b9b        registry:2.4.0                                        "/bin/registry serve "   3 hours ago         Up 3 hours          0.0.0.0:5001->5000/tcp                                                                           registry-mirror
```

The above shows Docker containers launched by XOS (image names starting with
`xosproject`).  Containers starting with `onos` are running ONOS.
There is also a Docker image registry, a Maven repository containing
the CORD ONOS apps, and a number of microservices used in bare-metal provisioning.

```
vagrant@prod:~$ sudo lxc list
+-------------------------+---------+------------------------------+------+------------+-----------+
|          NAME           |  STATE  |             IPV4             | IPV6 |    TYPE    | SNAPSHOTS |
+-------------------------+---------+------------------------------+------+------------+-----------+
| ceilometer-1            | RUNNING | 10.1.0.4 (eth0)              |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
| glance-1                | RUNNING | 10.1.0.5 (eth0)              |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
| juju-1                  | RUNNING | 10.1.0.3 (eth0)              |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
| keystone-1              | RUNNING | 10.1.0.6 (eth0)              |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
| mongodb-1               | RUNNING | 10.1.0.13 (eth0)             |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
| nagios-1                | RUNNING | 10.1.0.8 (eth0)              |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
| neutron-api-1           | RUNNING | 10.1.0.9 (eth0)              |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
| nova-cloud-controller-1 | RUNNING | 10.1.0.10 (eth0)             |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
| openstack-dashboard-1   | RUNNING | 10.1.0.11 (eth0)             |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
| percona-cluster-1       | RUNNING | 10.1.0.7 (eth0)              |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
| rabbitmq-server-1       | RUNNING | 10.1.0.12 (eth0)             |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
| testclient              | RUNNING | 192.168.0.244 (eth0.222.111) |      | PERSISTENT | 0         |
+-------------------------+---------+------------------------------+------+------------+-----------+
```

The LXD containers ending with names ending with `-1` are running
OpenStack-related services. These containers can be
entered as follows:

```
$ ssh ubuntu@<container-name>
```

The `testclient` container runs the simulated subscriber device used
for running simple end-to-end connectivity tests. Its only connectivity is
to the vSG, but it can be entered using:

```
$ sudo lxc exec testclient bash
```

### compute_node-1 VM

The `compute_node-1` VM is the virtual compute node controlled by OpenStack.
This VM can be entered from the `prod` VM.  Run `cord prov list` to get the
node name (assigned by MaaS) and then run:

```
$ ssh ubuntu@<compute-node-name>
```

Virtual machines created via XOS/OpenStack will be instantiated inside the `compute_node`
VM.  To login to an OpenStack VM, first get the management IP address (172.27.0.x):

```
vagrant@prod:~$ nova list --all-tenants
+--------------------------------------+-------------------------+--------+------------+-------------+---------------------------------------------------+
| ID                                   | Name                    | Status | Task State | Power State | Networks                                          |
+--------------------------------------+-------------------------+--------+------------+-------------+---------------------------------------------------+
| 3ba837a0-81ff-47b5-8f03-020175eed6b3 | mysite_exampleservice-2 | ACTIVE | -          | Running     | management=172.27.0.3; public=10.6.1.194          |
| 549ffc1e-c454-4ef8-9df7-b02ab692eb36 | mysite_vsg-1            | ACTIVE | -          | Running     | management=172.27.0.2; mysite_vsg-access=10.0.2.2 |
+--------------------------------------+-------------------------+--------+------------+-------------+---------------------------------------------------+
```

Then run `ssh-agent` and add the default key -- this key loaded into the VM when
it was created:

```
vagrant@prod:~$ ssh-agent bash
vagrant@prod:~$ ssh-add
```

SSH to the compute node with the `-A` option and then to the VM using
the management IP obtained above.  So if the compute node name is `bony-alley`
and the management IP is 172.27.0.2:

```
vagrant@prod:~$ ssh -A ubuntu@bony-alley
ubuntu@bony-alley:~$ ssh ubuntu@172.27.0.2

# Now you're inside the mysite-vsg-1 VM
ubuntu@mysite-vsg-1:~$
```

### MaaS GUI

You can access the MaaS (Metal-as-a-Service) GUI by pointing your browser to the URL
`http://<target-server>:8080/MAAS/`.  Username and password are both `cord`.  For more
information on MaaS, see [the MaaS documentation](http://maas.io/docs).

### XOS GUI

You can access the XOS GUI by pointing your browser to URL
`http://<target-server>:8080/xos/`.  Username is `padmin@vicci.org` and password is `letmein`.

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

## Troubleshooting

If the CORD-in-a-Box build fails, you may try simply resuming the
build at the place that failed.  The easiest way is to do is to re-run
the `cord-in-a-box.sh` script; this will start the build at the
beginning and skip over the steps that have already been completed.

A build can also be resumed manually; this is often quicker than
re-running the install script, but requires more knowledge about how
the build works.  The `cord-in-a-box.sh` script drives the build by
entering the `corddev` VM and executing the following commands in
`/cord/build`:

```
$ ./gradlew fetch
$ ./gradlew buildImages
$ ./gradlew -PdeployConfig=config/cord_in_a_box.yml -PtargetReg=10.100.198.201:5000 publish
$ ./gradlew -PdeployConfig=config/cord_in_a_box.yml deploy
```

The final `deploy` task is the longest one and so failures are most likely to
happen here.  It can be broken up into the following ordered sub-tasks:

```
$ ./gradlew -PdeployConfig=config/cord_in_a_box.yml deployBase
$ ./gradlew -PdeployConfig=config/cord_in_a_box.yml prepPlatform
$ ./gradlew -PdeployConfig=config/cord_in_a_box.yml deployOpenStack
$ ./gradlew -PdeployConfig=config/cord_in_a_box.yml deployONOS
$ ./gradlew -PdeployConfig=config/cord_in_a_box.yml deployXOS
$ ./gradlew -PdeployConfig=config/cord_in_a_box.yml setupAutomation
```

Manually driving the build following a failure involves looking in the log to 
figure out the failing task, and then running that task and subsequent tasks
using the above commands.

## Congratulations

If you got this far, you successfully built, deployed, and tested your
first CORD POD.

You are now ready to bring up a multi-node POD with a real switching
fabric and multiple physical compute nodes.  The process for doing so is described in
[quickstart_physical.md](./quickstart_physical.md).
