# Network Settings 

The CORD POD uses two core network interfaces: fabric and mgmtbr. 
The fabric interface is used to bond all interfaces meant to be used for CORD data traffic and the mgmtbr will be used to bridge all interfaces used for POD management (signaling) traffic. An additional interface of import on the head node is the external interface, or the interface through which the management network accesses upstream servers, such as the Internet. 

How physical interfaces are identified and mapped to either the external, the fabric or mgmtbr interface is a combination of their name, NIC driver, and/or bus type. 

You can verify how your network card matches these informations using on the compute nodes (including the one with head capabilities) 

```
ethtool -i <name>
```

By default, any interface that has a module or kernel driver of tun, bridge, bonding, or veth will be ignored when selecting devices for the fabric and mgmtbr interfaces, as well as any interface that is not associated with a bus type or has a bus type of N/A or tap. All other interfaces that are not ignored will be considered for selection to either the fabric or the mbmtbr interface. 

When deciding which interfaces are in this bond, the deployment script selects the list of available interfaces and filters them on the criteria below. The output is the list of interfaces that should be associated with the bond interface. The resultant list is sorted alphabetically. Finally, the interfaces are configured to be in the bond interface with the first interface in the list being the primary. 

The network configuration can be customized before deploying, using a set of variables that can be set in your deployment configuration file, for example `podX.yml`, in the dev VM, under `/cord/build/podconfig`. 
Below, an example of most commonly used network variables is reported:

```
'fabric_include_names'='<name1>,<name2>'
'fabric_include_module_types'='<mod1>,<mod2>'
'fabric_include_bus_types'='<bus1>,<bus2>'
'fabric_exclude_names'='<name1>,<name2>'
'fabric_exclude_module_types'='<mod1>,<mod2>'
'fabric_exclude_bus_types'='<bus1>,<bus2>'
'fabric_ignore_names'='<name1>,<name2>'
'fabric_ignore_module_types'='<mod1>,<mod2>'
'fabric_ignore_bus_types'='<bus1>,<bus2>'
'management_include_names'='<name1>,<name2>'
'management_include_module_types'='<mod1>,<mod2>'
'management_include_bus_types'='<bus1>,<bus2>'
'management_exclude_names'='<name1>,<name2>'
'management_exclude_module_types'='<mod1>,<mod2>'
'management_exclude_bus_types'='<bus1>,<bus2>'
'management_ignore_names'='<name1>,<name2>'
'management_ignore_module_types'='<mod1>,<mod2>'
'management_ignore_bus_types'='<bus1>,<bus2>'
```

Each of the criteria is specified as a comma separated list of regular expressions. 

There is a set of include, exclude, and ignore variables, that operate on the interface names, module types and bus types. By setting values on these variables it is fairly easy to customize the network settings. 

The options are processed as following:

1. If a given interface matches an ignore option, it is not available to be selected into either the fabric or mgmtbr interface and will not be modified in the `/etc/network/interface`. 

2. If no include criteria are specified and the given interfaces matches then exclude criteria then the interface will be set as manual configuration in the `/etc/network/interface` file and will not be auto activated 

3. If no include criteria are specified and the given interface does NOT match the exclude criteria then this interface will be included in either the frabric or mgmtbr interface. 

4. If include criteria are specified and the given interface does not match the criteria then the interface will be ignored and its configuration will NOT be modified 

5. If include criteria are specified and the given interface matches the criteria then if the given interface also matches the exclude criteria then this interface will be set as manual configuration in the /etc/network/interface file and will not be auto activated 

6. If include criteria are specified and the given interface matches the criteria and if it does NOT match the exclude criteria then this interface will be included in either the fabric or mgmtbr interface. 

7. By default, the only criteria that are specified is the fabric include module types and they are set to i40e, mlx4_en. 

8. If the fabric include module types is specified and the management exclude module types are not specified, then by default the fabric include module types are used as the management exclude module types. This ensures that by default the fabric and the mgmtbr do not intersect on interface module types. 

9. If an external interface is specified in the deployment configuration, this interface will be added to the farbric and management ignore names list. 

A common question is how a non-standard card can be used as fabric network card on the compute nodes. To do that, you should check the driver type for the card you want to use with ethtool -i <name>, and insert that in the list under the line `fabric_include_module_types`. 

Some notes:

* If the fabric include module types is specified and the management exclude module types are not specified, then by default the fabric include module types are used as the management exclude module types. This ensures that by default the fabric and the mgmtbr do not intersect on interface module types. 

* If an external interface is specified in the deployment configuration, this interface will be added to the fabric and management ignore names list. 

* Each of the criteria is specified as a comma separated list of regular expressions. 

>WARNING: The Ansible scripts configure the head node to provide DHCP/DNS/PXE services out of its internal / management network interfaces, to be able to reach the other components of the POD (i.e. the switches and the other compute nodes). These services are instead not exposed out of the external network. 

