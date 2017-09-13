#  Container Images 

In the installation process CORD fetches, builds, and deploys a set of container images. 
These include:

* cord-maas-bootstrap - (directory: bootstrap) run during MaaS installation time to customize the MaaS instance via REST interfaces. 

* cord-maas-automation - (directory: automation) daemon on the head node to automate PXE booted servers through the MaaS bare metal deployment workflow. 

* cord-maas-switchq - (directory: switchq) daemon on the head node that watches for new switches being added to the POD and triggers provisioning when a switch is identified (via the OUI on MAC address). 

* cord-maas-provisioner - (directory: provisioner) daemon on the head node that manages the execution of ansible playbooks against switches and compute nodes as they are added to the POD. 

* cord-ip-allocator - (directory: ip-allocator) daemon on the head node used to allocate IP address for the fabric interfaces. 

* cord-dhcp-harvester - (directory: harvester) run on the head node to facilitate CORD / DHCP / DNS integration so that all hosts can be resolved via DNS. 

* opencord/mavenrepo - custom CORD maven repository image to support ONOS application loading from a local repository. 

* cord-test/nose - container from which cord tester test cases originate and validate traffic through the CORD infrastructure. 

* cord-test/quagga - BGP virtual router to support uplink from CORD fabric network to Internet. 

* cord-test/radius - Radius server to support cord-tester capability. 

* opencord/onos - custom version of ONOS for use within the CORD platform. 

