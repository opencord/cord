# Quickstart

This section provides a short list of essential commands that can be
used to deploy CORD-in-a-Box and a physical POD.

>NOTE: Looking for the full Cord-in-a-Box (CiaB) installation guide? You can find it [here](install_ciab.md).

>NOTE: Looking for the full physical pod installation guide? You can find it [here](install_pod.md).

## Common Step (for both CiaB and a Physical POD)
<pre><code>cd ~ && \
wget https://raw.githubusercontent.com/opencord/cord/{{ book.branch }}/scripts/cord-bootstrap.sh && \
chmod +x cord-bootstrap.sh && \
~/cord-bootstrap.sh -v</code></pre>

Logout and log back in.

## CORD-in-a-Box (CiaB)
To install CiaB, type the following commands:

```
cd ~/cord/build && \
make PODCONFIG=rcord-virtual.yml config && \
make -j4 build |& tee ~/build.out
```

## Physical POD
The following steps install a physical POD.

### Prepare the head node

```
sudo adduser cord && \
sudo adduser cord sudo && \
echo 'cord ALL=(ALL) NOPASSWD:ALL' | sudo tee --append /etc/sudoers.d/90-cloud-init-users
```

### On the development machine
Create your POD configuration `.yml` file in `~/cord/build/podconfig`.

```
cd ~/cord/build && \
make PODCONFIG={YOUR_PODCONFIG_FILE.yml} config && \
make -j4 build |& tee ~/build.out
```

### Compute nodes and fabric switches
After a successful build, set the compute nodes and the switches to boot from PXE and manually reboot them. They will be automatically deployed.
