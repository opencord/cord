# OpenCORD Quick Start Guide

[*This description is for a stand-alone bare-metal target server.
If we succeed to bring up CORD on a VM, we will relax the text and
go for the simpler experience.*]

This tutorial walks you through the steps to bring up an OpenCORD "POD" on a single server.
This deployment uses a simulated fabric, but it is good to get a quick feel
for what is involved and how CORD works.

Specifically, the tutorial covers the following:

1. Bring up a build environment
2. Fetch and build all binary artifacts
3. Deploy the software to the target platform (server)
4. Run some tests on the platform
5. Clean-up

### What you need (Prerequisites)

You will need a build machine (can be your developer laptop) and a target server.

Build host:

* Mac OS X, Linux, or Windows with a 64-bit OS
* Git (2.5.4 or later) - [TODO add pointers and/or instructions]
* Vagrant (1.8.1 or later) - [TODO add pointers and/or instructions]
* Access to the Internet (at least through the fetch phase)
* SSH access to the target server

Target server:

* 64-bit server, with
  * 16GB+ RAM
  * 30GB+ disk
* Ubuntu 14.04 LTS freshly installed (see [TBF]() for instruction on how to install Ubuntu 14.04).


### Bring up an Use the OpenCORD Build Environment

On the build host, clone the OpenCORD integration repository and switch into its top directory:

   ```
   git clone https://gerrit.opencord.org/opencord
   cd opencord
   ```
   
Bring up the standardized OpenCORD build and development environment (VM). This will take a few minutes, depending on your connection speed:

   ```
   vagrant up corddev
   ```
   
Login to the build environment:

   ```
   vagrant ssh corddev
   ```
   
Switch to the OpenCORD integration directory, which is shared from your host:

   ```
   cd /opencord
   ```
   
Pre-fetch all pre-requisites needed to build all components for OpenCORD. This is the step that takes the longest time as a large number of images and files need to be downloaded.

   ```
   ./gradlew fetch
   ```
   
Time to build artifacts needed for deployment:

   ```
   ./gradlew build
   ```
   
Lets publish all artifacts to the staging registry (Docker registry).

   ```
   ./gradlew publish
   ```
   
   
### Deploy to the Target Server

Deploy the software to the target platform:

   ```
   ./gradlew deploy
   ```
   
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

If you got this far, you successfully built, deployed, and tested your first OpenCORD POD.


### Further Steps

[TODO]