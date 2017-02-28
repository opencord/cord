# CORD Master Makefile

# Target, used to determine builds/paths/etc. when shared between environments
TARGET           ?= $(firstword $(MAKECMDGOALS))

# Timestamp for log files
TS               := $(shell date +'%Y%m%dT%H%M%SZ')

# Source paths
BUILD            ?= .
SCENARIOS        ?= $(BUILD)/scenarios
CORD             ?= ..
PI               ?= $(BUILD)/platform-install
MAAS             ?= $(BUILD)/maas

# Milestones/logs paths
M                ?= $(BUILD)/milestones
LOGS             ?= $(BUILD)/logs

# Configuration files
SCENARIO_CONFIG  ?= "$(SCENARIOS)/$(TARGET)/config.yml"
INVENTORY        ?= "$(SCENARIOS)/$(TARGET)/inventory"

# Host names
HEADNODE         ?= head1
BUILDNODE        ?= $(HEADNODE)

# Vagrant config
VAGRANT_PROVIDER ?= libvirt
VAGRANT_VMS      ?= $(HEADNODE)
VAGRANT_CWD      ?= $(SCENARIOS)/$(TARGET)/
SSH_CONFIG       ?= ~/.ssh/config

# Commands
SHELL             = bash -o pipefail
VAGRANT           = VAGRANT_CWD=$(VAGRANT_CWD) vagrant
ANSIBLE           = ansible -i $(INVENTORY)
ANSIBLE_PB        = ansible-playbook -i $(INVENTORY) --extra-vars @$(SCENARIO_CONFIG)
ANSIBLE_PB_LOCAL  = ansible-playbook -i $(PI)/inventory/head-localhost --extra-vars "cord_profile=${TARGET}"
IMAGEBUILDER      = python /opt/cord/build/scripts/imagebuilder.py
LOGCMD            = 2>&1 | tee -a $(LOGS)/$(TS)_$(@F)
SSH_HEAD          = ssh $(HEADNODE)
SSH_BUILD         = ssh $(BUILDNODE)

# Dependencies - set by targets below
COPY_CORD_DEPS =
DOCKER_IMAGE_DEPS =
CORE_IMAGE_DEPS = $(M)/docker-images
DEPLOY_OPENSTACK_DEPS =
DOCKER_IMAGE_DEPS =

# == TARGETS == #
.DEFAULT: help

help:
	@echo "Please specify a target (rcord, opencloud, etc.)"

# Many of these targets use target-specific variables
# https://www.gnu.org/software/make/manual/html_node/Target_002dspecific.html

# local/mock scenarios
local: CORE_IMAGE_DEPS = $(M)/local-docker-images
local: $(M)/local-onboard-profile

mock: VAGRANT_VMS = headnode
mock: HEADNODE = headnode
mock: $(M)/onboard-profile

# Virtualized pod scenarios
rcord-virt: HEADNODE = prod
rcord-virt: BUILDNODE = corddev
rcord-virt: VAGRANT_VMS = corddev prod
rcord-virt: COPY_CORD_DEPS = $(M)/vagrant-up
rcord-virt: CORE_IMAGE_DEPS = $(M)/push-to-registry
rcord-virt: DEPLOY_OPENSTACK_DEPS = $(M)/deploy-maas
rcord-virt: $(M)/prereqs-check $(M)/deploy-maas $(M)/onboard-openstack

opencloud-virt: VAGRANT_VMS = head1 compute1 compute2
opencloud-virt: COPY_CORD_DEPS = $(M)/vagrant-up
opencloud-virt: $(M)/prereqs-check $(M)/onboard-openstack

# physical builds
rcord: VAGRANT_VMS = corddev
rcord: COPY_CORD_DEPS = $(M)/vagrant-up
rcord: CORE_IMAGE_DEPS = $(M)/push-to-registry
rcord: DEPLOY_OPENSTACK_DEPS = $(M)/deploy-maas
rcord: $(M)/deploy-maas $(M)/onboard-openstack

opencloud: $(M)/onboard-openstack

# Testing targets
pod-test: $(M)/onboard-openstack
	$(ANSIBLE_PB) $(PI)/pod-test-playbook.yml $(LOGCMD)

# Utility targets
teardown:
	$(ANSIBLE_PB) $(PI)/teardown-playbook.yml $(LOGCMD)
	rm -f $(M)/start-xos $(M)/config-xos $(M)/onboard-profile

compute-node-refresh:
	$(ANSIBLE_PB) $(PI)/compute-node-refresh-playbook.yml $(LOGCMD)

vagrant-destroy:
	$(VAGRANT) destroy $(LOGCMD)
	rm -f $(M)/vagrant-up # and everything else?

# == MILESTONES == #
# empty target files are touched in the milestones dir to indicate completion

# note use of secondary expansion to create dynamic lists of target prereqs
# https://www.gnu.org/software/make/manual/html_node/Secondary-Expansion.html
.SECONDEXPANSION:

$(M)/prereqs-check:
	$(ANSIBLE_PB) $(PI)/prereqs-check-playbook.yml $(LOGCMD)
	touch $@

$(M)/vagrant-up:
	$(VAGRANT) up $(VAGRANT_VMS) --provider $(VAGRANT_PROVIDER) $(LOGCMD)
	echo "Configuring SSH for VM's..."
	$(VAGRANT) ssh-config $(VAGRANT_VMS) > $(SSH_CONFIG)
	touch $@

$(M)/copy-cord: | $(COPY_CORD_DEPS)
	$(ANSIBLE_PB) $(PI)/copy-cord-playbook.yml $(LOGCMD)
	touch $@

$(M)/cord-config: | $(M)/copy-cord
	$(ANSIBLE_PB) $(PI)/cord-config-playbook.yml $(LOGCMD)
	touch $@

$(M)/copy-config: | $(M)/cord-config
	$(ANSIBLE_PB) $(PI)/copy-profile-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-headnode: | $(M)/cord-config $(M)/copy-config
	$(ANSIBLE_PB) $(PI)/prep-headnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-buildnode: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/prep-buildnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-computenode: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/prep-computenode-playbook.yml $(LOGCMD)
	touch $@

$(M)/glance-images: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/glance-images-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-maas: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(MAAS)/head.yml $(LOGCMD)
	touch $@

$(M)/deploy-openstack: | $(M)/prep-headnode $(M)/prep-computenode $(DEPLOY_OPENSTACK_DEPS)
	$(ANSIBLE_PB) $(PI)/deploy-openstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-computenode: | $(M)/deploy-openstack
	$(ANSIBLE_PB) $(PI)/deploy-computenode-playbook.yml $(LOGCMD)
	touch $@

$(M)/docker-images: | $(DOCKER_IMAGE_DEPS)
	$(SSH_BUILD) "cd /opt/cord/build; $(IMAGEBUILDER) -l $(BUILD)/image_logs -g $(BUILD)/ib_graph.dot -a $(BUILD)/ib_actions.yml -b $(SCENARIO_CONFIG)" $(LOGCMD)
	touch $@

$(M)/local-docker-images:
	$(IMAGEBUILDER) -l $(BUILD)/image_logs -g $(BUILD)/ib_graph.dot -a $(BUILD)/ib_actions.yml -b $(SCENARIO_CONFIG) $(LOGCMD)
	touch $@

$(M)/push-to-registry: | $(M)/docker-images
	$(SSH_BUILD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/push_images_registry.yml" $(LOGCMD)
	touch $@

$(M)/core-image: | $(CORE_IMAGE_DEPS)
	$(ANSIBLE_PB) $(PI)/build-core-image-playbook.yml $(LOGCMD)
	touch $@

$(M)/start-xos: | $(M)/core-image
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/start-xos-playbook.yml" $(LOGCMD)
	touch $@

$(M)/local-start-xos: | $(M)/core-image
	$(ANSIBLE_PB) $(ANSIBLE_PB_LOCAL) $(PI)/start-xos-playbook.yml $(LOGCMD)
	touch $@

$(M)/onboard-profile: | $(M)/start-xos
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-profile-playbook.yml" $(LOGCMD)
	touch $@

$(M)/local-onboard-profile: | $(M)/start-xos
	$(ANSIBLE_PB) $(PI)/onboard-profile-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-onos: | $(M)/start-xos $(M)/docker-images # $(M)/push-to-registry
	$(ANSIBLE_PB) $(PI)/deploy-onos-playbook.yml $(LOGCMD)
	touch $@

$(M)/onboard-openstack: | $(M)/deploy-computenode $(M)/glance-images $(M)/deploy-onos $(M)/onboard-profile
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-openstack-playbook.yml" $(LOGCMD)
	touch $@

