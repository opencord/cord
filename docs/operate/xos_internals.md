# XOS Internals

XOS is the component of CORD that implements the control plane
through which operators control and manage CORD. This normally
happens through a set of XOS-generated interfaces:

* [TOSCA](../xos-tosca/README.md)
* [REST API](rest_apis.md)
* [XOSSH](../xos/dev/xossh.md)

This section describes XOS internals, including how it is configured and
deployed on a running POD. Additional information about how to write
XOS models (from which these interfaces are generated) is
described [elsewhere](../xos/README.md) in thie guide.
