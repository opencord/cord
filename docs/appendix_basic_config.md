#  Basic Configuration 

The following provides instructions on how to configure an installed POD.

##Fabric 

This section describes how to apply a basic configuration to a freshly installed fabric. The fabric needs to be configured to forward traffic between the different components of the POD. More info about how to configure the fabric can be found here. 

##Configure Routes on the Compute Nodes 

Before starting to configure the fabric we need to make sure the traffic going out of the compute nodes can go out through the correct interface, towards the fabric. To do this, the routes on the compute node br-int interface need to be manually configured. 

Run the following command on the compute nodes:

```
sudo ip route add 10.6.2.0/24 via 10.6.1.254 
```

>NOTE: it’s strongly suggested to add it as a permanent route to the compute node, so the route will still be there after a reboot 

##Configure the Fabric:  Overview 

On the head node there is a service able to generate an ONOS network configuration to control the leaf and spine network fabric. This configuration is generated querying ONOS for the known switches and compute nodes and producing a JSON structure that can be posted to ONOS to implement the fabric. 

The configuration generator can be invoked using the CORD generate command, which print the configuration at screen (standard output). 

##Remove Stale ONOS Data 

Before generating a configuration you need to make sure that the instance of ONOS controlling the fabric doesn't contain any stale data and that has processed a packet from each of the switches and computes nodes. 

ONOS needs to process a packet because it does not have a mechanism to automatically discover the network elements. Thus, to be aware of a device on the network ONOS needs to first receive a packet from it. 

To remove stale data from ONOS, the ONOS CLI `wipe-out` command can be used:

```
ssh -p 8101 onos@onos-fabric wipe-out -r -j please 
Warning: Permanently added '[onos-fabric]:8101,[10.6.0.1]:8101' (RSA) to the list of known hosts. 
Password authentication 
Password:  (password rocks) 
Wiping intents 
Wiping hosts 
Wiping Flows 
Wiping groups 
Wiping devices 
Wiping links 
Wiping UI layouts 
Wiping regions 
```

>NOTE: When prompt, use password "rocks". 

To ensure ONOS is aware of all the switches and the compute nodes, you must have each switch "connected" to the controller and let each compute node ping over its fabric interface to the controller. 

##Connect the Fabric Switches to ONOS 

If the switches are not already connected, the following command on the head node CLI will initiate a connection. 

```
for s in $(cord switch list | grep -v IP | awk '{print $3}'); do 
ssh -qftn root@$s ./connect -bg 2>&1  > $s.log 
done 
```

You can verify ONOS has recognized the devices using the following command:

```
ssh -p 8101 onos@onos-fabric devices 

Warning: Permanently added '[onos-fabric]:8101,[10.6.0.1]:8101' (RSA) to the list of known hosts. 
Password authentication 
Password:
id=of:0000cc37ab7cb74c, available=true, role=MASTER, type=SWITCH, mfr=Broadcom Corp., hw=OF-DPA 2.0, sw=OF-DPA 2.0, serial=, driver=ofdpa, channelId=10.6.0.23:58739, managementAddress=10.6.0.23, protocol=OF_13 
id=of:0000cc37ab7cba58, available=true, role=MASTER, type=SWITCH, mfr=Broadcom Corp., hw=OF-DPA 2.0, sw=OF-DPA 2.0, serial=, driver=ofdpa, channelId=10.6.0.20:33326, managementAddress=10.6.0.20, protocol=OF_13 
id=of:0000cc37ab7cbde6, available=true, role=MASTER, type=SWITCH, mfr=Broadcom Corp., hw=OF-DPA 2.0, sw=OF-DPA 2.0, serial=, driver=ofdpa, channelId=10.6.0.52:37009, managementAddress=10.6.0.52, protocol=OF_13 
id=of:0000cc37ab7cbf6c, available=true, role=MASTER, type=SWITCH, mfr=Broadcom Corp., hw=OF-DPA 2.0, sw=OF-DPA 2.0, serial=, driver=ofdpa, channelId=10.6.0.22:44136, managementAddress=10.6.0.22, protocol=OF_13 
```

>NOTE: This is a sample output that won’t necessarily reflect your output 

>NOTE: When prompt, use password "rocks". 

##Connect Compute Nodes to ONOS 

To make sure that ONOS is aware of the compute nodes the follow command will a ping over the fabric interface on each compute node. 

```
for h in localhost $(cord prov list | grep "^node" | awk '{print $4}'); do 
ssh -qftn $h ping -c 1 -I fabric 8.8.8.8;
done 
```

You can verify ONOS has recognized the devices using the following command:

```
ssh -p 8101 onos@onos-fabric hosts 
Warning: Permanently added '[onos-fabric]:8101,[10.6.0.1]:8101' (RSA) to the list of known hosts. 
Password authentication 
Password:
id=00:16:3E:DF:89:0E/None, mac=00:16:3E:DF:89:0E, location=of:0000cc37ab7cba58/3, vlan=None, ip(s)=[10.6.0.54], configured=false 
id=3C:FD:FE:9E:94:28/None, mac=3C:FD:FE:9E:94:28, location=of:0000cc37ab7cba58/4, vlan=None, ip(s)=[10.6.0.53], configured=false 
```

>NOTE: When prompt, use password rocks 

##Generate the Network Configuration 

To modify the fabric configuration for your environment, generate on the head node a new network configuration using the following commands:

```
cd /opt/cord_profile && \
cp fabric-network-cfg.json{,.$(date +%Y%m%d-%H%M%S)} && \
cord generate > fabric-network-cfg.json 
```

##Load Network Configuration 

Once these steps are done load the new configuration into XOS, and restart the apps in ONOS:

###Install Dependencies 

```
sudo pip install httpie 
```

###Delete Old Configuration 

```
http -a onos:rocks DELETE http://onos-fabric:8181/onos/v1/network/configuration/docker-compose -p rcord exec xos_ui python /opt/xos/tosca/run.py xosadmin@opencord.org /opt/cord_profile/fabric-service.yaml 
```

###Load New Configuration 

```
http -a onos:rocks POST http://onos-fabric:8181/onos/v1/applications/org.onosproject.vrouter/active 
```

###Restart ONOS Apps 

```
http -a onos:rocks POST http://onos-fabric:8181/onos/v1/applications/org.onosproject.segmentrouting/active 
```

To verify that XOS has pushed the configuration to ONOS, log into ONOS in the onos-fabric VM and run netcfg:

```
$ ssh -p 8101 onos@onos-fabric netcfg 
Password authentication 
Password:
{
  "hosts" : {
    "00:00:00:00:00:04/None" : {
      "basic" : {
        "ips" : [ "10.6.2.2" ],
        "location" : "of:0000000000000002/4"
      }
    },
    "00:00:00:00:00:03/None" : {
      "basic" : {
        "ips" : [ "10.6.2.1" ],
        "location" : "of:0000000000000002/3"
      }
    },
	... 
```	

>NOTE: When prompt, use password "rocks"

