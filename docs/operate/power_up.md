# Powering Up a POD

This guide describes how to power up a previously installed CORD POD that
has been powered down (cleanly or otherwise). The end goal of the power up
procedure is a fully functioning CORD POD.

## Boot the Head Node

* **Physical  POD:** Power on the head node
* **CiaB:** Bring up the head1 VM:
```
$ cd ~/cord/build; VAGRANT_CWD=~/cord/build/scenarios/cord vagrant up head1 --provider libvirt
```

## Check the Head Node Services

1. Verify that `mgmtbr` and `fabric` interfaces are up and have IP addresses
2. Verify that MAAS UI is running and accessible:
  * **Physical POD:** `http://<head-node>/MAAS`
  * **CiaB:** `http://<ciab-server>:8080/MAAS`
> **Troubleshooting: MAAS UI not available on CiaB.**
> If you are running a CiaB and there is no webserver on port 8080, it might
> be necessary to refresh port forwarding to the prod VM.
> Run `ps ax|grep 8080`
> and look for an SSH command (will look something like this):
```
31353 pts/5    S      0:00 ssh -o User=vagrant -o Port=22 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PasswordAuthentication=no -o ForwardX11=no -o IdentityFile="/users/acb/cord/build/scenarios/cord/.vagrant/machines/head1/libvirt/private_key" -L *:8080:192.168.121.14:80 -N 192.168.121.14
```
> A workaround is to kill this process, and then copy and paste the command
> above into another window on the CiaB server to set up a new SSH port forwarding connection.

3. Verify that the following Docker containers are running: mavenrepo, switchq, automation, provisioner, generator, harvester, storage, allocator, registry

4. Use `sudo lxc list` to ensure that juju lxc containers are running. If any are stopped, use `sudo lxc start <name>` to restart them.

5. Run: `source /opt/cord_profile/admin-openrc.sh`

6. Verify that the following OpenStack commands work:
  * `$ keystone user-list`
  * `$ nova list --all-tenants`
  * `$ neutron net-list`
> **Troubleshooting: OpenStack commands give SSL error.**
> Sometimes Keystone starts up in a strange state and OpenStack
> commands will fail with various SSL errors.
> To fix this, it is often sufficient to run:
`ssh ubuntu@keystone sudo service apache2 restart`


## Power on Leaf and Spine Switches

* **Physical POD:** power on the switches.  
* **CiaB:** nothing to do; CiaB using OvS switches that come up when the CiaB server is booted.

## Check the Switches

* **Physical POD:** On the head node:
1. Get switch IPs by running: cord prov list
2. Verify that ping works for all switch IPs 

* **CiaB:** run `sudo ovs-vsctl show` on the CiaB server; you should see `leaf1` and `spine1`.

## Boot the Compute Nodes

* **Physical POD:** Log into the MAAS UI and power on the compute node.
* **CiaB:** Log into the MAAS UI and power on the compute node.

## Check the Compute Nodes

Once the compute nodes are up:

1. Login to the head node
2. Run: `source /opt/cord_profile/admin-openrc.sh`
3. Verify that nova service-list shows the compute node as “up”.
> It may take a few minutes until the node's status is updated in Nova.
4. Verify that you can log into the compute nodes from the head node as the ubuntu user

## Check XOS

Verify that XOS UI is running and accessible:

* **Physical POD:** `http://<head-node>/xos`
* **CiaB:** `http://<ciab-server>:8080/xos`

If it's not working, try restarting XOS (replace `rcord` with the name of your profile):

```
$ cd /opt/cord_profile; docker-compose -p rcord restart
```

## Check VTN

Verify that VTN is initialized correctly:

1. Run `onos> cordvtn-nodes`
2. Make sure the compute nodes have COMPLETE status.
3. Prior to rebooting existing OpenStack VMs:
  * Run `onos> cordvtn-ports`
  * Make sure some ports show up
  * If not, try this:
    - `onos> cordvtn-sync-neutron-states <keystone-url> admin admin <password>`
    - `onos> cordvtn-sync-xos-states <xos-url> xosadmin@opencord.org <password>`

##Boot OpenStack VMs

To bring up OpenStack VMs that were running before the POD was shut down:

1. Run `source /opt/cord_profile/admin-openrc.sh`
2. Get list of VM IDs: `nova list --all-tenants`
3. For each VM:
  * `$ nova start <vm-id>`
  * `$ nova console-log <vm-id>`
  * Inspect the console log to make sure that the network interfaces get IP addresses.

To restart a vSG inside the vSG VM:

1. SSH to the vSG VM
2. Run: `sudo rm /root/network_is_setup`
3. Save the vSG Tenant in the XOS UI
4. Once the synchronizer has re-run, make sure you can ping 8.8.8.8 from inside the vSG container
```
sudo docker exec -ti vcpe-222-111 ping 8.8.8.8
```
