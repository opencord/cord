# Offline (local repository) CORD Install

[*This document is out-of-date. It contains helpful suggestions about how one
might do an offline install, but it is not current with the latest CORD release.*]

It is possible to install CORD using a local Ubuntu application
repository. This can be useful for several use cases including

- CORD deployments that don't allow Internet access
- Deploying CORD multiple times if your Internet access is slow

To enable the install of CORD using a local repository you must first build
a **mirror** of all the repositories utilized by the CORD install procedure
locally. The CORD head/compute nodes must be able to access the host that is
acting as a mirror using http. If the head node host has enough disk space, it
can be the mirror repository.

### Creating the Mirror
To create the mirror you will need a host running `Ubtunu 14.04LTS Server`
that has access, at least temporarily, to the Internet. On this host
`apt-mirror` and `docker-engine` should be installed. `apt-mirror` is a
utility used to download the Debian packages and index files for the mirror and
`docker-engine` is used to front the mirror using an `nginx` container.

#### Installing `apt-mirror`
To install `apt-mirror` the following commands should suffice.

```
sudo apt-get update
sudo apt-get install -y apt-mirror
```

#### Installing `docker-engine`
To install `docker-engine` please follow the directions provided by Docker at
https://docs.docker.com/engine/installation/linux/ubuntulinux/.

#### `apt-mirror` Configuration
`apt-mirror` takes a configuration that downloads the Debian packages and
indexes to support a mirror. Save the following `apt-mirror` configuration to
a local file, e.g., `cord-mirror.list`. This will create a mirror for
machines using the `amd64` architecture. If you need the `i386` architecture
you can configure that via the `defaultarch` setting or by duplicating each
repository line, replacing `deb` with `deb-i386`.

The goal is to create a minimal mirror repository as the downloading of the
artifacts is quite time and space consuming. If you already have an existing
mirror in your enterprise it is possible to augment that to pull in the
additional repositories required by CORD, but this is an exercise left up to
the reader.

```
############# config ##################
#
# set base_path    /var/spool/apt-mirror
#
# set mirror_path  $base_path/mirror
# set skel_path    $base_path/skel
# set var_path     $base_path/var
# set cleanscript $var_path/clean.sh
# set postmirror_script $var_path/postmirror.sh
set run_postmirror 0
set defaultarch amd64
set nthreads     20
set _tilde 0
#
############# end config ##############

deb http://archive.ubuntu.com/ubuntu trusty main universe
deb http://archive.ubuntu.com/ubuntu trusty-updates main universe
deb http://apt.dockerproject.org/repo ubuntu-trusty main
deb http://ppa.launchpad.net/webupd8team/java/ubuntu trusty main
deb http://ppa.launchpad.net/ansible/ansible/ubuntu trusty main universe
deb http://ppa.launchpad.net/maas/stable/ubuntu trusty main
deb http://linux.dell.com/repo/community/ubuntu trusty openmanage
deb http://ppa.launchpad.net/juju/stable/ubuntu trusty main

clean http://archive.ubuntu.com/ubuntu
clean http://apt.dockerproject.org/repo
clean http://ppa.launchpad.net/webupd8team/java/ubuntu
clean http://ppa.launchpad.net/ansible/ansible/ubuntu
clean http://ppa.launchpad.net/maas/stable/ubuntu
clean http://linux.dell.com/repo/community/ubuntu
clean http://ppa.launchpad.net/juju/stable/ubuntu
```

After the `apt-mirror` configuration is ready, you can start the mirroring
process using the command

```
sudo apt-mirror cord-mirror.list
```

Be sure to replace the `cord-mirror.list` parameter with the path to the file
in which you saved the `apt-mirror` configuration.

**NOTE:** The mirroring process can take quite a while (3+ hours) and is
highly dependent on your Internet access speed. The mirroring process will
download and process about **90 Gigabytes** of data. So get a cup of coffee,
take a nap, enjoy the great out doors, or simply spend some time on
Facebook or Netflix.

#### Staring the `HTTP` Archive Server
Before the archive server is started, the `nginx` docker image should be
downloaded from dockerhub.com. Once this image is download the host should
no longer require Internet access and thus the install of CORD can be
completed offline. To download (pull) the `nginx` image use the following
command:

```
sudo docker pull nginx:1.10
```

The following command can be used to start an `nginx` docker container that
will front the mirror over `HTTP` so that the the head/compute nodes can
access the archive. This command will present the archive server on port `8888`
of the host machine. This can be changed by modifying the command line option
`-p`. The command line option `-v` is used to specify the location where
the mirror files were downloaded, `/var/spool/apt-mirror` by default.

```
sudo docker run \
    --name local-repository \
    --restart unless-stopped \
    -p 8888:80 \
    -v /var/spool/apt-mirror/:/usr/share/nginx/html \
    -d nginx:1.10
```

### Using the Local Repository
To use a local repository to deploy CORD, the POD deployment configuration must
be modified to point to the mirror or local repository that you will be using.
This is done by setting the following variables in the POD deployment
configuration. In the example below the values are set assuming the host IP
of the repository is `10.10.10.10` and the mirror was created per the
instructions above. If you are using a different repository these values may
have to be customized for you deployment. The simple way of looking at these
values is that this is the value that will be used in the *Ansible*
`apt_repository` task under the parameter `repo`.

```
seedServer
  extraVars:
    - ubuntu_apt_repo="deb [arch=amd64] http://10.10.10.10:8888/mirror/archive.ubuntu.com/ubuntu trusty main universe"
    - ubuntu_updates_apt_repo="deb [arch=amd64] http://10.10.10.10:8888/mirror/archive.ubuntu.com/ubuntu trusty-updates main universe"
    - docker_apt_repo="deb [arch-amd64] http://10.10.10.10:8888/mirror/apt.dockerproject.org/repo ubuntu-trusty main"
    - java_apt_repo="deb [arch-amd64] http://10.10.10.10:8888/mirror/ppa.launchpad.net/webupd8team/java/ubuntu trusty main"
    - ansible_apt_repo="deb [arch-amd64] http://10.10.10.10:8888/mirror/ppa.launchpad.net/ansible/ansible/ubuntu trusty main"
    - maas_apt_repo="deb [arch-amd64] http://10.10.10.10:8888/mirror/ppa.launchpad.net/maas/stable/ubuntu trusty main"
    - dell_apt_repo="deb [arch-amd64] http://10.10.10.10:8888/mirror/linux.dell.com/repo/community trusty openmanage"
    - juju_apt_repo="deb [arch-amd64] http://10.10.10.10:8888/mirror/ppa.launchpad.net/juju/stable/ubuntu trusty main"
```
