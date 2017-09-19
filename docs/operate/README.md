# Operating CORD

This guide defines various processes and procedures for operating a
CORD POD. It assumes the [build-and-install](../README.md) has already
completed, and you want to operate and manage a running POD.

Today, CORD most often runs for demo, development, or evaluation
purposes, so this guide is limited to simple procedures suitable for
such settings. We expect more realistic operational scenarios will be
supported in the future.

It is also the case that CORD's operations and management interface
is primarily defined by its Northbound API. The RESTful version of
this API is documented at `<head-node>/apidocs/` on a running
POD (a composite API spec is also included in this
[guide](rest_apis.md)
This API is auto-generated from a set of models, where CORD's
model-based design is describe [elsewhere](../xos/README.md).
