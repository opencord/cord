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

You will need a build machine (can be your developer laptop) and a target server.

Build host:

* Mac OS X, Linux, or Windows with a 64-bit OS
* [`git`](https://git-scm.com/) (2.5.4 or later)
* [`Vagrant`](https://www.vagrantup.com/) (1.8.1 or later)
* Access to the Internet
* SSH access to the target server

Target server:

* 64-bit server, with
  * 48GB+ RAM
  * 12+ CPU cores
  * 1TB+ disk
* Access to the Internet
* Ubuntu 14.04 LTS freshly installed (see [TBF]() for instruction on how to install Ubuntu 14.04).
* Account used to SSH from build host has password-less *sudo* capability (e.g., like the `ubuntu` user)

### Running on CloudLab (optional)

If you do not have a target server available, you can borrow one on
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

## Create the development environment

Follow the instructions in [devel_env_setup.md](./devel_env_setup.md) to set
up the Vagrant development machine for CORD on your build host.  

The rest of the tasks in this guide are run from inside the Vagrant development
machine, in the `/cord` directory.

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

## Run the post-deployment tests

After the single-node POD is set up, you can execute a set of basic health
tests on the platform by running this command:

```
./gradlew -PdeployConfig=/cord/components/platform-install/config/default.yml postDeployTests
```

Currently this tests the E2E connectivity of the POD by performing the following
steps:
 * Setting up a sample CORD subscriber in XOS
 * Launch a vSG for that subscriber on the CORD POD
 * Creating a test client, corresponding to a device in the subscriber's household
 * Connecting the test client to the vSG using a simulated OLT
 * Running `ping` in the client to a public IP address in the Internet

Success of this test means that traffic is flowing between the subscriber
household and the Internet via the vSG.

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

