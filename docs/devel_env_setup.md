# The CORD Development Environment

The development environment is required for the tasks in this repository.
This environment leverages [Vagrant](https://www.vagrantup.com/docs/getting-started/)
to install the tools required to build and deploy the CORD software.  

## Cloning the Repository
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
## Creating the Development Machine
To create the development machine the following  Vagrant command can be
used. This will create an Ubuntu 14.04 LTS based virtual machine and install
some basic required packages, such as Docker, Docker Compose, and
Oracle Java 8.
```
vagrant up corddev
```
**NOTE:** *It may have several minutes for the first command `vagrant up
corddev` to complete as it will include creating the VM as well as downloading
and installing various software packages.*

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

## Gradle
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
