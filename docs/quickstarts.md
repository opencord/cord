# POD Quickstarts

This section provides a short list of essential commands that can be used to
deploy virtual or physical PODs.

Before you start, you must obtain the CORD source tree and install Vagrat.
Instructions for doing this can be found at [Configuring your Development
Environment](install.md#configuring-your-development-environment) - if you're
on CloudLab, most likely you will want to use the `cord-bootstrap.sh` script
with the `-v` option.

## Virtual POD (CORD-in-a-Box)

This is a summary of [Installing a Virtual Pod (CORD-in-a-Box)](install_virtual.md).

To install a CiaB, on a [suitable](#target-server-requirements) Ubuntu 14.04
system, run the following commands:

```
cd ~/cord/build && \
make PODCONFIG=rcord-virtual.yml config && \
make -j4 build |& tee ~/build.out && \
make pod-test |& tee ~/test.out
```

This will create a virtual R-CORD pod (as specified in the `PODCONFIG`), and go
through the build and end-to-end test procedure, bringing up vSG and
ExampleService instances.

If you'll be running these commands frequently, a shortcut is to use the `-t`
option on the `cord-bootstrap.sh` script to run all the make targets, for a
more unattended build process, which can be handy when testing:

```
./cord-bootstrap.sh -v -t "PODCONFIG=rcord-virtual.yml config" -t "build" -t "pod-test"
```

## Physical POD

This is a summary of  [Installing a Physical POD](install_physical.md).

After performing the [physical
configuration](install_physical.md#physical-configuration), install Ubuntu
14.04 on a [suitable head node](install_physical.md#detailed-requirements). On
the target head node, add a `cord` user with `sudo` rights:

```
sudo adduser cord && \
sudo usermod -a -G sudo cord && \
echo 'cord ALL=(ALL) NOPASSWD:ALL' | sudo tee --append /etc/sudoers.d/90-cloud-init-users
```

[Create a POD configuration](install.md#pod-config) file in the
`~/cord/build/podconfig` directory, then run:

```
cd ~/cord/build && \
make PODCONFIG={YOUR_PODCONFIG_FILE.yml} config && \
make -j4 build |& tee ~/build.out
```

After a successful build, set the compute nodes and the switches to boot from
PXE and manually reboot them. They will be automatically deployed.

