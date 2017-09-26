# CORD Guide

This is a curated set of guides that describe how to install, operate, test,
and develop [CORD](https://opencord.org).

CORD is a community-based open source project. In addition to this guide, you
can find information about this community, its projects, and its governance on
the [CORD wiki](https://wiki.opencord.org). This includes early white papers
and design notes that have shaped [CORD's
architecture](https://wiki.opencord.org/display/CORD/Documentation).

## Getting Started

If you are new to CORD and would like to get familiar with it, you should start
by [bringing up a virtual POD on a single physical server](install_virtual.md).

If you want to work on the CORD core or develop a service, please see [Getting
the Source Code](getting_the_code.md) and [Developing for CORD](develop.md).

## Getting Help

See [Troubleshooting and Build Internals](troubleshooting.md) if you're
having trouble with installing a CORD POD.

The best way to ask for help is to join the CORD Slack channel or mailing
lists. Information about both can be found at the [CORD
wiki](https://wiki.opencord.org/display/CORD).

## Making Changes to Documentation

The [http://guide.opencord.org](http://guide.opencord.org) website is built using the
[GitBook Toolchain](https://toolchain.gitbook.com/), with the documentation
root in [build/docs](https://github.com/opencord/cord/blob/{{ book.branch
}}/docs) in a checked out source tree.  It is build with `make`, and requires
that gitbook, python, and a few other tools are installed.

Source for individual guides is available in the [CORD code
repository](https://gerrit.opencord.org); look in the `docs` directory of each
project, with the documentation rooted in `build/docs`. Updates and
improvements to this documentation can be submitted through Gerrit.


