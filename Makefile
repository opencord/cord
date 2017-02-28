# CORD bootstrapping Makefile

# Target - used to determine other builds/paths/etc.
TARGET           ?= $(firstword $(MAKECMDGOALS))
TS               := `date %y%m%dT%H%M%SZ`

# Directories
BUILD            := .
CORD             := ..
PI               := $(BUILD)/platform-install
MAAS             := $(BUILD)/maas

# milestones - see below
M                := $(BUILD)/milestones
LOGS             := $(BUILD)/logs
CONFIG           := $(BUILD)/config

# Variables
INVENTORY         = "$(CONFIG)/$(TARGET)/inventory"
EXTRA_VARS        = "$(CONFIG)/$(TARGET)/vars.yml"
CONTAINERS        = "$(CONFIG)/$(TARGET)/containers.yml"

CORD_CONFIG_DEPS  = ""

# Commands
ANSIBLE           = ansible -i $(INVENTORY)
ANSIBLE_PB        = ansible-playbook -i $(INVENTORY) --extra-vars @$(EXTRA_VARS)
IMAGEBUILDER      = python $(BUILD)/scripts/imagebuilder.py
LOGCMD            = "2>&1 | tee $(LOGS)/$(TS)_$(@F)"

# Targets
.DEFAULT: help

help:
	echo "Please specify a target (rcord, opencloud, etc.)"

# physical builds
rcord: $(M)/onboard-profile
opencloud: $(M)/onboard-profile

# test/frontend/mock builds
frontend: $(M)/config-xos
mock-rcord: $(M)/config-xos

# a theoretical build with XOS + ONOS but no OpenStack
frontend-with-onos: $(M)/onboard-onos

# *-in-a-box virtualized environments
# https://www.gnu.org/software/make/manual/html_node/Target_002dspecific.html
rcord-in-a-box: TARGET = rcord
rcord-in-a-box: CORD_CONFIG_DEPS += $(M)/copy-cord
rcord-in-a-box: rcord

opencloud-in-a-box: TARGET = opencloud
opencloud-in-a-box: CORD_CONFIG_DEPS += $(M)/copy-cord
opencloud-in-a-box: opencloud

# testing targets

pod-test: $(M)/onboard-profile
	$(ANSIBLE_PB) $(PI)/pod-test-playbook.yml $(LOGCMD)

# cleanup targets
teardown:
	$(ANSIBLE_PB) $(PI)/teardown-playbook.yml $(LOGCMD)
	rm -f $(M)/start-xos $(M)/config-xos $(M)/onboard-profile

# Milestones
# Files are created in the milestones directory with the name of the target

$(M)/prereqs-check:
	$(ANSIBLE_PB) $(PI)/prereqs-check-playbook.yml $(LOGCMD)
	touch $@

$(M)/copy-cord: | $(M)/prereqs-check
	$(ANSIBLE_PB) $(PI)/copy-cord-playbook.yml $(LOGCMD)
	touch $@

$(M)/cord-config: | $(CORD_CONFIG_DEPS)
	$(ANSIBLE_PB) $(PI)/cord-config-playbook.yml $(LOGCMD)
	touch $@

$(M)/image-buildenv: | $(M)/cord-config
	$(ANSIBLE_PB) $(PI)/image-buildenv-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-buildhost: | $(M)/cord-config
	$(ANSIBLE_PB) $(PI)/prep-buildhost-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-headnode: | $(M)/cord-config
	$(ANSIBLE_PB) $(PI)/prep-headnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-computenode: | $(M)/cord-config
	$(ANSIBLE_PB) $(PI)/prep-computenode-playbook.yml $(LOGCMD)
	touch $@

$(M)/glance-images: | $(M)/cord-config $(M)/prep-buildhost
	$(ANSIBLE_PB) $(PI)/glance-images-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-openstack: | $(M)/cord-config $(M)/prep-headnode $(M)/prep-computenode
	$(ANSIBLE_PB) $(PI)/deploy-openstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/docker-images: | $(M)/image-buildenv $(M)/prep-buildhost
	$(IMAGEBUILDER) $(CONTAINERS) -vv $(LOGCMD)
	touch $@

$(M)/push-to-registry: | $(M)/docker-images $(M)/prep-headnode
	$(IMAGEBUILDER) -p $(CONTAINERS) -vv $(LOGCMD)
	touch $@

$(M)/start-xos: | $(M)/push-to-registry
	$(ANSIBLE_PB) $(PI)/start-xos-playbook.yml $(LOGCMD)
	touch $

$(M)/config-xos: | $(M)/start-xos
	$(ANSIBLE_PB) $(PI)/config-xos-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-onos: | $(M)/push-to-registry
	$(ANSIBLE_PB) $(PI)/deploy-onos-playbook.yml $(LOGCMD)
	touch $@

$(M)/onboard-onos: | $(M)/deploy-onos $(M)/config-xos
	$(ANSIBLE_PB) $(PI)/onboard-onos-playbook.yml $(LOGCMD)
	touch $@

$(M)/onboard-openstack: | $(M)/prep-computenode $(M)/glance-images $(M)/config-xos $(M)/onboard-onos
	$(ANSIBLE_PB) $(PI)/onboard-openstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/onboard-profile: | $(M)/onboard-openstack
	$(ANSIBLE_PB) $(PI)/onboard-profile-playbook.yml $(LOGCMD)
	touch $@

