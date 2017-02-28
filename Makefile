# CORD bootstrapping Makefile

# Target - used to determine other builds/paths/etc.
TARGET           ?= $(firstword $(MAKECMDGOALS))
TS               := $(shell date +'%Y%m%dT%H%M%SZ')

# Host names
HEADNODE         := head1

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
EXTRA_VARS        = "$(PI)/profile_manifests/$(TARGET).yml"
CONTAINERS        = "$(CONFIG)/$(TARGET)/containers.yml"

# Commands
SHELL             = bash -o pipefail
ANSIBLE           = ansible -i $(INVENTORY)
ANSIBLE_PB        = ansible-playbook -i $(INVENTORY) --extra-vars @$(EXTRA_VARS)
ANSIBLE_PB_LOCAL  = ansible-playbook -i $(PI)/inventory/head-localhost --extra-vars @$(EXTRA_VARS)
IMAGEBUILDER      = python /opt/cord/build/scripts/imagebuilder.py
LOGCMD            = 2>&1 | tee $(LOGS)/$(TS)_$(@F)

# Optional dependencies
CORD_CONFIG_DEPS  =
DEPLOY_OPENSTACK_DEPS =

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
frontend-with-onos: TARGET = frontend
frontend-with-onos: frontend $(M)/onboard-onos

# *-in-a-box virtualized environments
# https://www.gnu.org/software/make/manual/html_node/Target_002dspecific.html
rcord-in-a-box: TARGET = rcord
rcord-in-a-box: rcord

opencloud-in-a-box: TARGET = opencloud
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

$(M)/cord-config: | $(M)/copy-cord
	$(ANSIBLE_PB) $(PI)/cord-config-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-buildnode: | $(M)/cord-config
	$(ANSIBLE_PB) $(PI)/prep-buildnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-headnode: | $(M)/cord-config
	$(ANSIBLE_PB) $(PI)/prep-headnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-computenode: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/prep-computenode-playbook.yml $(LOGCMD)
	touch $@

$(M)/glance-images: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/glance-images-playbook.yml $(LOGCMD)
	touch $@

# $(M)/deploy-maas: | $(M)/cord-config $(M)/prep-buildnode
#	$(ANSIBLE_PB) $(MAAS)/head.yml $(LOGCMD)
#	touch $@

$(M)/deploy-openstack: | $(M)/prep-headnode $(M)/prep-computenode
	$(ANSIBLE_PB) $(PI)/deploy-openstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/docker-images: | $(M)/prep-headnode # $(M)/prep-buildnode
	ssh $(HEADNODE) "cd /opt/cord/build; $(IMAGEBUILDER) -vv -b $(CONTAINERS)" $(LOGCMD)
	touch $@

#$(M)/push-to-registry: | $(M)/docker-images $(M)/prep-headnode
#	$(IMAGEBUILDER) -vv -p $(CONTAINERS) $(LOGCMD)
#	touch $@

$(M)/start-xos: | $(M)/docker-images # $(M)/push-to-registry
	ssh $(HEADNODE) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/start-xos-playbook.yml" $(LOGCMD)
	touch $@

$(M)/config-xos: | $(M)/start-xos
	ssh $(HEADNODE) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/config-xos-playbook.yml" $(LOGCMD)
	touch $@

$(M)/deploy-onos: | $(M)/config-xos $(M)/docker-images # $(M)/push-to-registry
	$(ANSIBLE_PB) $(PI)/deploy-onos-playbook.yml $(LOGCMD)
	touch $@

$(M)/onboard-onos: | $(M)/deploy-onos
	ssh $(HEADNODE) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-onos-playbook.yml" $(LOGCMD)
	touch $@

$(M)/onboard-openstack: | $(M)/deploy-openstack $(M)/glance-images $(M)/onboard-onos
	ssh $(HEADNODE) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-openstack-playbook.yml" $(LOGCMD)
	touch $@

$(M)/onboard-profile: | $(M)/onboard-openstack
	ssh $(HEADNODE) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-profile-playbook.yml" $(LOGCMD)
	touch $@

