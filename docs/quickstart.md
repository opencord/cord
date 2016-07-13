# CORD Quick Start Guide

[*This description is for a stand-alone bare-metal target server.
It brings up a CORD POD on virtual machines on a single physical host. The purpose
of this solution is to enable those interested in understanding how CORD works to
examine and interact with a running CORD environment.  It is a good place for
novice CORD users to start.*]

[*NOTE: If you are looking for instructions on how to install a multi-node POD... (look where?) *]

This tutorial walks you through the steps to bring up a CORD "POD" on
a single bare-metal server.  This deployment uses a simulated fabric, but it is
good to get a quick feel for what is involved and how CORD works.

Specifically, the tutorial covers the following:

1. Bring up a build environment
2. Fetch all artifacts
3. Deploy the software to the target platform (server)
4. Run some tests on the platform
5. Clean-up

### What you need (Prerequisites)

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

[*Note: CloudLab is supporting CORD as a courtesy.  It is expected that you will
not use CloudLab resources for purposes other than evaluating CORD.  If, after a
week or two, you wish to continue using CloudLab to experiment with or develop CORD,
then you must apply for your own separate CloudLab project.*]

Once your account is approved, start an experiment using the `OnePC-Ubuntu14.04.4` profile
on either the Wisconsin or Clemson cluster.  This will provide you with a temporary target server
meeting the above requirements.

Refer to the [CloudLab documentation](https://docs.cloudlab.us) for more information.

### Bring up the CORD Build Environment

On the build host, clone the CORD integration repository anonymously and switch into its top directory:

   ```
   git clone https://gerrit.opencord.org/cord
   cd cord
   ```

If -- for whatever reason -- you decide to clone the repo as a private
repository using ssh, then you should add your private key to your local ssh
forwarding agent, because we will clone additional CORD repositories within
the Vagrant environment using the same git access mode, and this will require your
local agent to know your identity:

   ```
   ssh-add ~/.ssh/id_rsa
   ```

Bring up the standardized CORD build and development environment (VM). This will take a few minutes, depending on your connection speed:

   ```
   vagrant up corddev
   ```

Login to the build environment:

   ```
   vagrant ssh corddev
   ```

Switch to the CORD integration directory, which is shared from your host:

   ```
   cd /cord
   ```

Pre-fetch all pre-requisites needed to build all components for CORD. This step can take a while as a large number of images and files need to be downloaded.

   ```
   ./gradlew fetch
   ```

## Edit the configuration file

Edit the configuration file `/cord/components/platform-install/config/default.yml`.  Add the IP address of your target
server as well as the `username / password` for accessing the server.  You can skip adding the password if you can SSH
to the target server from inside the Vagrant VM as `username` without one (e.g., by running `ssh-agent`).

Before proceeding, verify that you can SSH to the target server from the development environment using the
above IP address, username, and password.  Also verify that the user account can `sudo` without a password.

Edit `/cord/gradle.properties` to add the following line:

   ```
   deployConfig=/cord/components/platform-install/config/default.yml
   ```

If your target server is a CloudLab machine, uncomment the following two lines in the
configuration file:

   ```
   #extraVars:
   #  - 'on_cloudlab=True'
  ```

### Deploy the single-node CORD POD on the target server

Deploy the CORD software to the the target server and configure it to form a running POD.

   ```
   ./gradlew deploySingle
   ```
> *What this does:*
>
> This command uses an Ansible playbook (cord-single-playbook.yml) to install
> OpenStack services, ONOS, and XOS in VMs on the target server.  It also brings up
> a compute node as a VM.

Note that this step usually takes *at least an hour* to complete.  Be patient!

Execute a set of basic health tests on the platform:

   ```
   ./gradlew post-deploy-tests
   ```


### Optional cleanup

Exit from the build environment and destroy it:

   ```
   exit
   vagrant destroy -f
   ```


### Congratulations

If you got this far, you successfully built, deployed, and tested your
first CORD POD.


### Further Steps

[TODO]
* Port forwarding for XOS login.  This should work:
  * URL: `http://<target-server>/`
  * Username: `padmin@vicci.org`
  * Password: `letmein`
* Add pointer to where to go next.  
