# vSG Configuration

>NOTE: This section is only relevant if you wish to change the default IP address block or gateway MAC address associated with the vSG subnet.  One reason you might want to do this is to associate more IP addresses with the vSG network (the default is a /24).

First, login to the CORD head node (`ssh head1` in *CiaB*) and go to the
`/opt/cord_profile` directory. To configure the fabric gateway, you will need
to edit the file `cord-services.yaml`. You will see a section that looks like
this:

```yaml
addresses_vsg:
  type: tosca.nodes.AddressPool
    properties:
      addresses: 10.7.1.0/24
      gateway_ip: 10.7.1.1
      gateway_mac: a4:23:05:06:01:01
```

Edit this section so that it reflects the fabric address block that you wish to assign to the
vSGs, as well as the gateway IP and the MAC address that the vSG should use to
reach the Internet (e.g., for the vRouter)

Once the `cord-services.yaml` TOSCA file has been edited as described above,
push it to XOS by running the following:

```
cd /opt/cord_profile
docker-compose -p rcord exec xos_ui python /opt/xos/tosca/run.py xosadmin@opencord.org
/opt/cord_profile/cord-services.yaml
```

This step is complete once you see the correct information in the VTN app
configuration in ONOS.  To check that XOS has successfully pushed the network configuration to the ONOS VTN app:

 1.  Log into ONOS from the head node

    * Command: `ssh -p 8102 onos@onos-cord`
    * Password: `rocks`

 2. Run the `netcfg` command. Verify that the updated gateway information is
present under publicGateways:

```json
onos> netcfg
"publicGateways" : [
  {
    "gatewayIp" : "10.7.1.1",
    "gatewayMac" : "a4:23:05:06:01:01"
  }, {
    "gatewayIp" : "10.8.1.1",
    "gatewayMac" : "a4:23:05:06:01:01"
  }
],
```

> NOTE: The above output is just a sample; you should see the values you configured

 3. Run the `cordvtn-nodes` command.  This will look like the following:

```
onos> cordvtn-nodes
  Hostname                      Management IP       Data IP             Data Iface     Br-int                  State
  sturdy-baseball               10.1.0.14/24        10.6.1.2/24         fabric         of:0000525400d7cf3c     COMPLETE
  Total 1 nodes
```

 4. Verify that the information for all nodes is correct

 5. Verify that the initialization status of all nodes is `COMPLETE`.
