# Terminology

This guide uses the following terminology. (Additional terminology and
definitions can be found in an overview of the
[CORD Ecosystem](https://wiki.opencord.org/display/CORD/Defining+CORD).)

**POD**
:  A single physical deployment of CORD.

**Full POD**
:  A typical configuration, used as example in this Guide.  A full CORD POD
   consists of three servers and four fabric switches.  This makes it possible to
   experiment with all the core features of CORD, and it is what the community
   typically uses for tests.

**Half POD**
:  A minimum-sized configuration. It is similar to a full POD, but with less
   hardware. It consists of two servers (one head node and one compute node), and
   one fabric switch. It does not allow experimentation with all of the core
   features that CORD offers (e.g., a switching fabric), but it is still good for
   basic experimentation and testing.

**CORD-in-a-Box (CiaB)**
:  Colloquial name for a Virtual POD.

**Development (Dev) Machine**
:  This is the machine used to download, build and deploy CORD onto a POD.
   Sometimes it is a dedicated server, and sometimes the developer's laptop.  In
   principle, it can be any machine that satisfies the hardware and software
   requirements.

**Development (Dev) VM**
:  Bootstrapping the CORD installation requires a lot of software to be
   installed and some non-trivial configurations to be applied.  All this should
   happen on the dev machine.  To help users with the process, CORD provides an
   easy way to create a VM on the dev machine with all the required software and
   configurations in place.

**Compute Node(s)**
:  A server in a POD that run VMs or containers associated with one or more
   tenant services. This terminology is borrowed from OpenStack.

**Head Node**
:  A compute node of the POD that also runs management services. This includes
   for example XOS (the orchestrator), two instances of ONOS (the SDN controller,
   one to control the underlay fabric and one to control the overlay), MAAS and
   all the services needed to automatically install and configure the rest of
   the POD devices.

**Fabric Switch**
:  A switch in a POD that interconnects other switches and servers inside the
   POD.

**vSG**
:  The virtual Subscriber Gateway (vSG) is the CORD counterpart for existing
   CPEs. It implements a bundle of subscriber-selected functions, such as
   Restricted Access, Parental Control, Bandwidth Metering, Access Diagnostics and
   Firewall. These functions run on commodity hardware located in the Central
   Office rather than on the customer’s premises. There is still a device in the
   home (which we still refer to as the CPE), but it has been reduced to a
   bare-metal switch.

