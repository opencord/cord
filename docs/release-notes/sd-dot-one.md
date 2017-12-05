# Release Notes

The 4.1 service release of Shared-Delusion (4.0) includes two new profiles:
E-CORD and M-CORD. Detailed information about these two profiles can be
found in the [Service Profiles Guide](../service-profiles.md). The following
summarizes the new features.

## E-CORD Profile

The 4.1 release of E-CORD includes the following functionality:

* A hierarchical multi-pod orchestration deployment managed by XOS
and ONOS. Each of the local PODs registers with the global node, that in
turn asks for functionality and network/service setup.

* Through a hierarchical architecture, an enterprise customer is able to
provision an end-to-end *E-Line* carrier ethernet service (L2VPN).

* L2 Monitoring through OAM and CFM  can be provisioned for the
E-Line, with details such as delay and jitter observed in the
local POD where the E-Line starts.

* Each local POD deploys an R-CORD like service chain to connect to
the Public Internet. This connectivity configuration is currently
not automated.

* Documentation includes 

  * An overview of E-CORD.
  * How to install a full E-CORD, including two local PODs and a global node.
  * A CFM setup guide.
  * A Developer guide to manipulate and develop on top of E-CORD.
  * A Troubleshooting guide with reset scripts.

## M-CORD Profile

The 4.1 release of M-CORD supports 3GPP LTE connectivity, including:

* A CUPS compliant open source SPGW (in the form of two VNFs: SPGW-u and SPGW-c).
* An MME emulator with an integrated HSS, eNBs and UEs.
  * Emulates one eNB
  * Emulates up to ten UEs
  * Includes one MME with an integrated HSS
  * Can connect one SPGW-C/U
  * Allows users to attach, detach and send user plane traffic
* An application that emulates connectivity to the Internet.
* A composite EPC-as-a-Service that sets up and manages the other services.

The MME emulator is not open source. It comes as a binary, courtesy of ng4T, who provides free trial licenses for limited use. Users will need to apply for a free M-CORD license with ng4T, as described more fully in the Guide. Full versions of the emulator can also be licensed by contacting [ng4t](http://www.ng4t.com) directly.
