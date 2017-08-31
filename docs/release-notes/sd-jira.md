### Shared-Delusion: Jira

The following are Epics and Stories culled from Jira.

#### Epic: New Model Policy Framework 

* Document xproto policies 
* Debugging and end-to-end testing 
* Port old security policies to new framework 
* Implement security enforcements at the API boundary 
* End-to-end test validation 
* Design new model policy framework (python part) 
* Design new model policy framework (xproto part) 

#### Epic: Data Model Cleanup 

* Eliminate Many-To-Many between Image/Flavor and deployment 
* Cherry-pick and E2E test attic-less development for CORD-3.0 
* Document attic-less service development for 3.0 + Write helper target 
* Surgical cleanup for 3.0.1 to make up for not merging data model cleanup 
* Support packaging and namespacing for models 
* Autogenerate security policy enforcements 
* Modify xproto parser to support policies 
* xproto extension to specify security policies alongside data model definitions 
* Implement generalized privileges 
* Design security policies 
* Port existing code to data validation strategy 
* Autogenerate data validation code when models are saved 
* Support operations on field sets and generate unique-together 
* Merge new API generator + Modeldefs generator 
* Collapse core models into a single file 
* Convert xproto howto Google Doc into Markdown/gitbooks 
* Generate plcorebase and rename it to XOSBase 
* Update service onboarding Tutorial with documentation on xproto 
* Make it possible to fetch properties of parent models into child models 
* Extend IR to support implicit, reverse links 
* Recreate modeldefs API via xproto 
* Modify core api content_type_ip and mappings to use string 
* Support end-to-end singularization and pluralization 
* Support multiple inputs in xosgen 
* Implement pure-protobuf support for policy extension in xproto 
* Implement policy extension in xproto 
* Implement new credentials system 
* Generate unicode function from xproto 
* Delete old generative toolchain 
* Generate Synchronizer configuration from xproto 
* Unit test framework for client-side ORM 
* Eliminate dead code in core attic 
* Remove obsolete models and fields; rename models and fields 

#### Epic: Remove Hard-coded Service Dependencies 

* Eliminate hardcoded dependencies (VTN) 

#### Epic Rewrite TOSCA Engine 

* Implement the new TOSCA Engine 

#### Epic: Service/Tenancy Models 

* Clean up pass over ExampleService Models 
* Replace "kind" properties removed in Service Model refactoring 
* Port existing R-CORD services to new Service Models 
* Implement ServiceInstance, ServiceInterface, InterfaceType, and ServiceInterfaceLink models 
* Implement ServiceDependency Models 

#### Epic: Categorize, Unify, and Refactor Synchronizers 

* Better diagnostics for the synchronizer 
* Refactor synchronizer event loop 

#### Epic: Eliminate xos-ui Container 

* Create a "Debug" tab that can be enabled to show hidden fields
* Create a method to seed basic models to bootstrap the system 
* Get suggestions for fields that can be populated by a list of values. Eg: isolation can be only container or vm 
* Add the ability in xProto to hide fields/models from the GUI 
* Remove use of handcrafted XOS APIs in VTN 
* Add API to VTN model to signal that VTN app wants a resync 
* Inline navigation for related models 

#### Epic: XOS Configuration Management 

* Config Module - Implementation and Unit Tests 
* Config Module Design 

#### Epic: Deployments and Build Automation 

* Refactor installation guide on the wiki 
* Automate fabric configuration in ONOS and load POD configuartion files in pod-configs repo 
* Automate switch software installation 
* Refactor Jenkinsfile and automated build process to use yaml configuration file instead of Jenkins variables 
* Refactor Jenkins file putting parameters and methods for existing commonly used functions 

#### Epic: Refactor Build/Deploy 

* Add "mock" targets to master Makefile 
* Update Ansible and docker-compose versions 
* PI Role Cleanup 
* Volume mount certificate instead of baking into container 

#### Epic: Uniform Development Environments 

* Parallel build support for CiaB 
* Add Jenkins job for new CiaB build 
* Separate "build" and "head" nodes in POD build 
* "node" Docker image on headnode pulled from Docker Hub 
* "single" pod scenario, mock w/ synchronizers 
* Bootstrap mavenrepo container using platform-install 
* Clean up Vagrantfile 
* CiaB: "prod" VM has minimal dependencies installed 
* Docker image tagging for deployment 
* Evaluate imagebuilder.py 
* Determine where to inventory which container images are built 
* Add configure targets that generate credentials for each build layer 
* Add make targets for XOS profile development 
* Add make targets to install versioned POD or CiaB 
* Build and push tagged images to Docker Hub 
* Add CiaB targets to master Makefile 
* Build ONOS apps in a way that does not require installing Java / Gradle in the dev-env 
* Unify bootstapping dev-env 
* Write build environment design document
* Investigate build environment design considerations
* Write build environment design document 
* Investigate build environment design considerations

#### Epic: Expand QA Coverage 

* Intel CORD manual installation/debugging 
* Extensive gRPC api tests 
* Expand API tests to cover combinations of all parameters 
* Integrate DHCP relay in cord-tester 
* Implementing DHCP relay test cases in cord-tester for voltha 
* DHCP relay setup in voltha 
* Implementation of igmp-proxy test scenarios in VOLTHA context 
* Scale module development in cord-tester and validating test scenarios on physical pod 
* Realign XOS based tests to run on jenkins job 
* Security concern of automatically triggering ng40 test on bare metal as root 
* Update QA environments to use new make-based build 
* Add Sanity Tests to physical POD 
* gRPC API : Generate grpc unit-tests using xosgenx 
* Develop test plan for scale tests 
* Develop scale tests for subscribers. 
* Develop and validate scale tests for vrouter, igmp
* Develop and validate scale test cases for vsg, vcpe
* Add automation script for dpdk pktgen in cord tester 
* Integrate cord-tester framework to test scale 
* 3.0.1 Release Tests: Run all existing tests and document verification 
* Prepare jenkins job environment for ng-core 
* Implementing Test scenarios in vSG and Exampleservice modules in cord-tester 
* Implementing test cases in cord-tester to test voltha using ponsim olt and onu, verifying tls, dhcp and igmp flow on it.
* gRPC API tests: Phase-1 - Framework Analysis 
* Dynamic Input file generation for tests 
* New tests to validate Images/services dynamically based on the profile loaded 
* Chameleon REST API testing 
* Add functional tests (vSG, VTN) for POD
* Integrate chameleon API tests into jenkins job 

#### Epic: Unit Testing Framework 

* Set up node for Sonarqube 
* Identify unit test frameworks for all relevant components 

#### Epic: Fabric Features & Improvements 

* Upgrade to OFDPA 3.0 EA4  
* Update fabric synchronizer to push routes instead of hosts  
* Support enable/disable ports on STANDBY nodes  
* DHCP server HA supported by DHCP relay app  
* DHCPv6 option de/serializers 
* DHCP Relay Manager 
* DHCP Relay Store 
* Create DHCPv6 serializer and deserializer 
* Add keepalive messages to FPM protocol 
* Dual-home host failover 
* Extend Network Cofnig Host Provider to support multihoming 
* Update host location when port goes down 
* Extend HostStore to track multiple locations 
* Add keepalives for FPM connections 
* Improve hash-groups scaling and routing logic to prepare for dual homing 
* VLAN support for DHCP Relay and HostLocationProvider 
* CLI for DHCP relay manager 
* Test multilink support on CORD pod 

#### Epic: DHCP Relay 

* DHCP relay app configuration change for multiple servers 
* Refactor DHCP relay app 
* Support DHCPv6 by HostLocationProvider 

#### Epic: Dual Homing 

* Extend HostLocationProvider to detect dual-homed hosts 

#### Epic: Logging 

* Support reloads for logging module 
* Implement logging component 
* Design new logging component 

#### Epic: Add OVS-DPDK support 

* Jenkins pipeline for setting up DPDK-enabled POD on QCT2 
* Validate DPDK setup on CiaB 
* Bind fabric interfaces to DPDK 
* Add portbindings to `networking_onos` Neutron plugin 
* Change kernel boot options for nodes 
* Modify the nova-compute charm to install, configure OVS-DPDK 
* Add OpenStack config options to` juju_config.yml`
* Configure Nova with DPDK-enabled flavor(s) 

#### Epic: R-CORD 

* Resurrect VOLT synchronizer and get it configuring the ONOS vOLT app 
* Deploy VOLTHA with ponsim on CORD POD 

#### Epic: Maintenance 

* Autogenerated OpenStack passwords if composed o only digits cause OpenStack synchronizer failures
* Specify files for GUI Extensions 
* Add description and human readable name to modeldefs 
* Fix 3.0 `xos_base` build 
* Fix wrong import of service models from core in A-CORD 
* Update ONOS to 1.10 
* Update CiaB fabric to use OVS instead of CPqD 
* Update generated fabric config 
* CiaB: remove incorrect VAGRANT_CWD from quickstart.md 
* VRouter tenants are not being reaped 
* Nuisance errors in `xos_ui` container 
* Use tmux or mosh to install CiaB 
* General refactor of the physical POD installation guide 
* Update ExampleService tutorial 
* Update VTN section of quickstart_physical.md for CORD 3.0 
* Cut 3.0.1 release 
* Duplicate NetworkSlice objects are created 
* Upgrade ONOS to 1.8.7, cut 3.0.0-rc3

#### Other (not assigned to an Epic)

* Optimize api-sanity-pipeline job for master branch 
* China Mobile E-CORD setup 2007-08-13 through -19 
* Add action to xosTable to navigate to the detail page 
* Standardize makefiles for maas 
* Bring Up XOS Services fails on master branch 
* For local scenarios, non-superuser creation of config file directories 
* `last_login` field doesn't show up in newly generated API 
* Investigate mock-rcord breakage 
* Look into xos-base build failure 
* Investigate API Sanity Pipeline breakage 
* Update CORD 3.0 to use release version of plyprotobuf 
* Create cross linkage of Gerrit commits to Jira stories 
* Modify CORD Jira workflow to match ONOS 
* Zombie processes are present as soon as the head node gets deployed 
* Add CLI command to view routes in FPM layer 

