# vSG Configuration

First, login to the CORD head node (`ssh head1` in *CiaB*) and go to the
`/opt/cord_profile` directory. To configure the fabric gateway, you will need
to edit the file `cord-services.yaml`. You will see a section that looks like
this:

```yaml
addresses_vsg:
  type: tosca.nodes.AddressPool
    properties:
      addresses: 10.6.1.128/26
      gateway_ip: 10.6.1.129
      gateway_mac: 02:42:0a:06:01:01
```

Edit this section so that it reflects the fabric address block assigned to the
vSGs, as well as the gateway IP and the MAC address that the vSG should use to
reach the Internet.

Once the `cord-services.yaml` TOSCA file has been edited as described above,
push it to XOS by running the following:

```
cd /opt/cord_profile
docker-compose -p rcord exec xos_ui python /opt/xos/tosca/run.py xosadmin@opencord.org
/opt/cord_profile/cord-services.yaml
```

This step is complete once you see the correct information in the VTN app
configuration in XOS and ONOS.

To check that the VTN configuration maintained by XOS:

 1. Go to the "ONOS apps" page in the CORD GUI:
   * URL: `http://<head-node>/xos#/onos/onosapp/`
   * Username: `xosadmin@opencord.org`
   * Password: <content of
     /opt/cord/build/platform-install/credentials/xosadmin@opencord.org>

 2. Select VTN_ONOS_app in the table

 3. Verify that the `Backend status` is `1`

To check that the network configuration has been successfully pushed to the
ONOS VTN app and processed by it:

 1.  Log into ONOS from the head node

    * Command: `ssh -p 8102 onos@onos-cord`
    * Password: `rocks`

 2. Run the `cordvtn-nodes` command

 3. Verify that the information for all nodes is correct

 4.  Verify that the initialization status of all nodes is `COMPLETE`.

This will look like the following:

```
onos> cordvtn-nodes
	Hostname                      Management IP       Data IP             Data Iface     Br-int                  State
	sturdy-baseball               10.1.0.14/24        10.6.1.2/24         fabric         of:0000525400d7cf3c     COMPLETE
	Total 1 nodes
```

Run the `netcfg` command. Verify that the updated gateway information is
present under publicGateways:

```json
onos> netcfg
"publicGateways" : [
  {
    "gatewayIp" : "10.6.1.193",
    "gatewayMac" : "02:42:0a:06:01:01"
  }, {
    "gatewayIp" : "10.6.1.129",
    "gatewayMac" : "02:42:0a:06:01:01"
  }
],
```

