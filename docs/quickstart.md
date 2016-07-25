# CORD Quick Start Guide

This tutorial guide walks through the steps to bring up a demonstration CORD "POD",
running in virtual machines on a single physical server. The purpose
of this demonstration POD is to enable those interested in understanding how CORD works to
examine and interact with a running CORD environment.  It is a good place for
novice CORD users to start.

**NOTE:** *If you are looking for instructions on how to install a multi-node POD, you will
find them in [quickstart_physical.md](./quickstart_physical.md).*

Specifically, the tutorial covers the following:

1. Bring up a build environment
2. Fetch all artifacts
3. Deploy the software to the target platform (server)
4. Run some tests on the platform
5. Clean-up

## What you need (Prerequisites)

You will need a *build host* (e.g., your laptop) and a *target server*.  The build host will run
a development environment in a Vagrant VM that will be used to deploy CORD to the target server.

Build host requirements:

* Mac OS X, Linux, or Windows with a 64-bit OS
* [`git`](https://git-scm.com/) (2.5.4 or later)
* [`Vagrant`](https://www.vagrantup.com/) (1.8.1 or later)
* Access to the Internet
* SSH access to the target server

Target server requirements:

* 64-bit server, with
  * 48GB+ RAM
  * 12+ CPU cores
  * 1TB+ disk
* Access to the Internet
* Ubuntu 14.04 LTS freshly installed (see [TBF]() for instruction on how to install Ubuntu 14.04).
* Account used to SSH from build host has password-less *sudo* capability (e.g., like the `ubuntu` user)

### Target Server on CloudLab (optional)

If you do not have a target server available that meets the above requirements, you can borrow one on
[CloudLab](https://www.cloudlab.us).  Sign up for an account using your organization's
email address and choose "Join Existing Project"; for "Project Name" enter `cord-testdrive`.

**NOTE:** *CloudLab is supporting CORD as a courtesy.  It is expected that you will
not use CloudLab resources for purposes other than evaluating CORD.  If, after a
week or two, you wish to continue using CloudLab to experiment with or develop CORD,
then you must apply for your own separate CloudLab project.*

Once your account is approved, start an experiment using the `OnePC-Ubuntu14.04.4` profile
on either the Wisconsin or Clemson cluster.  This will provide you with a temporary target server
meeting the above requirements.

Refer to the [CloudLab documentation](https://docs.cloudlab.us) for more information.

## Clone the Repository
To clone the repository, on your build host issue the `git` command:
```
git clone http://gerrit.opencord.org/cord
```

### Complete
When this is complete, a listing (`ls`) of this directory should yield output
similar to:
```
ls
LICENSE.txt        ansible/           components/        gradle/            gradlew.bat        utils/
README.md          build.gradle       config/            gradle.properties  scripts/
Vagrantfile        buildSrc/          docs/              gradlew*           settings.gradle
```
## Create the Development Machine

The development environment is required for the tasks in this repository.
This environment leverages [Vagrant](https://www.vagrantup.com/docs/getting-started/)
to install the tools required to build and deploy the CORD software.

To create the development machine the following  Vagrant command can be
used. This will create an Ubuntu 14.04 LTS based virtual machine and install
some basic required packages, such as Docker, Docker Compose, and
Oracle Java 8.
```
vagrant up corddev
```
**NOTE:** *It may takes several minutes for the first command `vagrant up
corddev` to complete as it will include creating the VM as well as downloading
and installing various software packages.*

### Complete

Once the Vagrant VM is created and provisioned, you will see output ending
with:
```
==> corddev: PLAY RECAP *********************************************************************
==> corddev: localhost                  : ok=29   changed=25   unreachable=0    failed=0
==> corddev: Configuring cache buckets...
```

## Connect to the Development Machine
To connect to the development machine the following vagrant command can be used.
```
vagrant ssh corddev
```

Once connected to the Vagrant machine, you can find the deployment artifacts
in the `/cord` directory on the VM.
```
cd /cord
```

### Gradle
[Gradle](https://gradle.org/) is the build tool that is used to help
orchestrate the build and deployment of a POD. A *launch* script is included
in the Vagrant machine that will automatically download and install `gradle`.
The script is called `gradlew` and the download / install will be invoked on
the first use of this script; thus the first use may take a little longer
than subsequent invocations and requires a connection to the internet.

### Complete
Once you have created and connected to the development environment this task is
complete. The `cord` repository files can be found on the development machine
under `/cord`. This directory is mounted from the host machine so changes
made to files in this directory will be reflected on the host machine and
vice-versa.

## Fetch
The fetching phase of the deployment pulls Docker images from the public
repository down to the local machine as well as clones any `git` submodules
that are part of the project. This phase can be initiated with the following
command:
```
./gradlew fetch
```

### Complete
Once the fetch command has successfully been run, this step is complete. After
this command completes you should be able to see the Docker images that were
downloaded using the `docker images` command on the development machine:
```
docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
python              2.7-alpine          836fa7aed31d        5 days ago          56.45 MB
consul              <none>              62f109a3299c        2 weeks ago         41.05 MB
registry            2.4.0               8b162eee2794        9 weeks ago         171.1 MB
abh1nav/dockerui    latest              6e4d05915b2a        19 months ago       469.5 MB
```

## Edit the configuration file

Edit the configuration file `/cord/components/platform-install/config/default.yml`.  Add the IP address of your target
server as well as the `username / password` for accessing the server.  You can skip adding the password if you can SSH
to the target server from inside the Vagrant VM as `username` without one (e.g., by running `ssh-agent`).

If you are planning on deploying the single-node POD to a CloudLab host, uncomment
the following lines in the configuration file:

```
#extraVars:
#  - 'on_cloudlab=True'
```

This will signal the install process to set up extra disk space on the CloudLab
node for use by CORD.

### Complete

Before proceeding, verify that you can SSH to the target server from the development
environment using the IP address, username, and password that you entered into the
configuration file.  Also verify that the user account can `sudo` without a password.

## Deploy the single-node CORD POD on the target server

Deploy the CORD software to the the target server and configure it to form a running POD.

```
./gradlew -PdeployConfig=/cord/components/platform-install/config/default.yml deploySingle
   ```
> *What this does:*
>
> This command uses an Ansible playbook (cord-single-playbook.yml) to install
> OpenStack services, ONOS, and XOS in VMs on the target server.  It also brings up
> a compute node as a VM.

This step usually takes *at least an hour* to complete.  Be patient!

### Complete

This step is completed once the Ansible playbook finishes without errors.  If
an error is encountered when running this step, the first thing to try is
just running the above `gradlew` command again.

Once the step completes, two instances of ONOS are running, in
the `onos-cord-1` and `onos-fabric-1` VMs, though only `onos-cord-1` is used in
the single-node install.  OpenStack is also running on the target server with a virtual
compute node called `nova-compute-1`.  Finally, XOS is running inside the `xos-1`
VM and is controlling ONOS and OpenStack.  You can get a deeper understanding of
the configuration of the target server by visiting [head_node_services.md](./head_node_services.md).

## Login to the CORD GUI and look around

You can access the CORD GUI (provided by XOS) by pointing your browser to URL
`http://<target-server>:8888`, using username `padmin@vicci.org` and password `letmein`.

The state of the system is that all CORD services have been onboarded to XOS (you
can see them in the GUI by clicking _Services_ at left), but no
CORD subscribers have been created yet.  To create a sample subscriber, proceed
to the next step.

## Run the post-deployment test

After the single-node POD is set up, you can execute a basic health
test on the platform by running this command:

```
./gradlew -PdeployConfig=/cord/components/platform-install/config/default.yml postDeployTests
```

This tests the E2E connectivity of the POD by performing the following
steps:
 * Setting up a sample CORD subscriber in XOS
 * Launch a vSG for that subscriber on the CORD POD
 * Creating a test client, corresponding to a device in the subscriber's household
 * Connecting the test client to the vSG using a simulated OLT
 * Running `ping` in the client to a public IP address in the Internet

Success means that traffic is flowing between the subscriber
household and the Internet via the vSG.  If it succeeds, the end of the test
output should have some lines like this:

```
TASK [post-deploy-tests : Test external connectivity in test client] ***********
Monday 18 July 2016  22:21:19 +0000 (0:00:04.381)       0:01:37.751 ***********
changed: [128.104.222.194]

TASK [post-deploy-tests : Output from ping test] *******************************
Monday 18 July 2016  22:21:25 +0000 (0:00:05.603)       0:01:43.355 ***********
ok: [128.104.222.194] => {
    "pingtest.stdout_lines": [
        "nova-compute-1 | SUCCESS | rc=0 >>",
        "PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.",
        "64 bytes from 8.8.8.8: icmp_seq=1 ttl=46 time=29.9 ms",
        "64 bytes from 8.8.8.8: icmp_seq=2 ttl=46 time=29.2 ms",
        "64 bytes from 8.8.8.8: icmp_seq=3 ttl=46 time=29.5 ms",
        "",
        "--- 8.8.8.8 ping statistics ---",
        "3 packets transmitted, 3 received, 0% packet loss, time 2002ms",
        "rtt min/avg/max/mdev = 29.254/29.567/29.910/0.334 ms"
    ]
}

PLAY RECAP *********************************************************************
128.104.222.194            : ok=15   changed=8    unreachable=0    failed=0
```

### Optional cleanup

Once you are finished deploying the single-node POD, you can exit from the development
environment on the build host and destroy it:

```
exit
vagrant destroy -f
```

### Congratulations

If you got this far, you successfully built, deployed, and tested your
first CORD POD.

You are now ready to bring up a multi-node POD with a real switching
fabric and multiple physical compute nodes.  The process for doing so is described in
[quickstart_physical.md](./quickstart_physical.md).
