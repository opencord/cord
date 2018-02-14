# POD Quickstarts

This section provides a short list of essential commands that can be used to
deploy virtual or physical PODs.

Before you start, you must obtain the CORD source tree and install Vagrant.
Instructions for doing this can be found at [Required
Tools](install.md#required-tools).

To prepare a newly installed Ubuntu 14.04 system for either a Physical or
Virtual pod, you can use the
[cord-bootstrap.sh](install.html#cord-bootstrapsh-script) script:

{% include "/partials/cord-bootstrap.md" %}

> NOTE: Change the `master` path component in the URL to your desired version
> branch (ex: `cord-5.0`) if required.

## Virtual POD (CORD-in-a-Box)

This is a summary of [Installing a Virtual Pod
(CORD-in-a-Box)](install_virtual.md).

To install a CiaB, on a [suitable](#target-server-requirements) Ubuntu 14.04
system, run the following commands:

```shell
./cord-bootstrap.sh -v
cd ~/cord/build && \
make PODCONFIG=rcord-virtual.yml config && \
make -j4 build |& tee ~/build.out && \
make pod-test |& tee ~/test.out
```

This will create a virtual R-CORD pod (as specified in the `PODCONFIG`), and go
through the build and end-to-end test procedure, bringing up vSG and
ExampleService instances.

If you'll be running these commands frequently, a shortcut is to use the `-t`
option on the `cord-bootstrap.sh` script to download source, then run all the
make targets involved in doing a build and test cycle:

```shell
./cord-bootstrap.sh -v -t "PODCONFIG=rcord-virtual.yml config" -t "build" -t "pod-test"
```

## Physical POD

This is a summary of  [Installing a Physical POD](install_physical.md).

After performing the [physical
configuration](install_physical.md#physical-configuration), install Ubuntu
14.04 on a [suitable head node](install_physical.md#detailed-requirements). On
the target head node, add a `cord` user with `sudo` rights:

```shell
sudo adduser cord && \
sudo usermod -a -G sudo cord && \
echo 'cord ALL=(ALL) NOPASSWD:ALL' | sudo tee --append /etc/sudoers.d/90-cloud-init-users
```

[Create a POD configuration](install.md#pod-config) file using
[physical-example.yml](https://github.com/opencord/cord/blob/{{ book.branch }}/podconfig/physical-example.yml)
as a template.  Then run:

```shell
cd ~/cord/build && \
make PODCONFIG_PATH={PATH_TO_YOUR_PODCONFIG_FILE.yml} config && \
make -j4 build |& tee ~/build.out
```

After a successful build, set the compute nodes and the switches to boot from
PXE and manually reboot them. They will be automatically deployed.

