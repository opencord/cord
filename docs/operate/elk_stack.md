# ELK Stack Logs

CORD uses ELK Stack for logging information at all levels. CORD’s
ELK Stack logger collects information from several components,
including the XOS Core, API, and various Synchronizers. On a running
POD, the logs can be accessed at `http://<head-node>:8080/kibana`.

There is also a second way of accessing low-level logs with additional
verbosity that do not make it into ELK Stack. This involves accessing log
messages in various containers directly. You may do so by running the
following command on the head node.

```
$ docker logs < container-name
```

For most purposes, the logs in ELK Stack should contain enough information
to diagnose problems. Furthermore, these logs thread together facts across
multiple components by using the identifiers of XOS data model objects.

More information about using
[Kibana](https://www.elastic.co/guide/en/kibana/current/getting-started.html)
to access ELK Stack logs is available elsewhere, but to illustrate how the logging
system is used in CORD, consider the following example quieries.

The first example query enlists log messages in the implementation of a
particular service synchronizer, in a given time range:

```
+synchronizer_name:vtr-synchronizer AND +@timestamp:[now-1h TO now]
```

A second query gets log messages that are linked to the _Network_ data model
across all services:

```
+model_name: Network
```

The same query can be refined to include the identifier of the specific
_Network_ object in question. You can obtain the object id from the object’s
page in the XOS GUI.

```
+model_name: Network AND +pk:7
```

A final example lists log messages in a service synchronizer that
contain Python exceptions, and will usually correspond to anomalous
execution:

```
+synchronizer_name: vtr-synchronizer AND +exception
```



