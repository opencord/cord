# CORD Master Makefile

# Timestamp for log files
TS               := $(shell date +'%Y%m%dT%H%M%SZ')

# Podconfig must be specified, so an invalid default
PODCONFIG        ?= invalid

# Source path
BUILD            ?= .
CORD             ?= ..
PI               ?= $(BUILD)/platform-install
MAAS             ?= $(BUILD)/maas
ONOS_APPS        ?= $(CORD)/onos-apps

# Configuration paths
PODCONFIG_D      ?= $(BUILD)/podconfig
PODCONFIG_PATH   ?= $(PODCONFIG_D)/$(PODCONFIG)

SCENARIOS_D      ?= $(BUILD)/scenarios
GENCONFIG_D      ?= $(BUILD)/genconfig

# Milestones/logs paths
M                ?= $(BUILD)/milestones
LOGS             ?= $(BUILD)/logs

ALL_MILESTONES   ?= $(M)/prereqs-check $(M)/vagrant-up $(M)/copy-cord $(M)/cord-config $(M)/copy-config $(M)/prep-buildnode $(M)/prep-headnode $(M)/deploy-elasticstack $(M)/prep-computenode $(M)/glance-images $(M)/deploy-openstack $(M)/deploy-maas $(M)/deploy-computenode $(M)/docker-images $(M)/core-image $(M)/start-xos $(M)/onboard-profile $(M)/deploy-onos $(M)/onboard-openstack

LOCAL_MILESTONES ?= $(M)/local-cord-config $(M)/local-docker-images $(M)/local-core-image $(M)/local-start-xos $(M)/local-onboard-profile

# Configuration files
MASTER_CONFIG    ?= $(GENCONFIG_D)/config.yml
MAKEFILE_CONFIG  ?= $(GENCONFIG_D)/config.mk
INVENTORY        ?= $(GENCONFIG_D)/inventory.ini
PROFILE_NAME_F   ?= $(GENCONFIG_D)/cord_profile
SCENARIO_NAME_F  ?= $(GENCONFIG_D)/cord_scenario

CONFIG_FILES     = $(MASTER_CONFIG) $(MAKEFILE_CONFIG) $(INVENTORY) $(PROFILE_NAME_F) $(SCENARIO_NAME_F)

include $(MAKEFILE_CONFIG)

# Set using files from genconfig
SCENARIO          = $(shell cat $(SCENARIO_NAME_F))
PROFILE           = $(shell cat $(PROFILE_NAME_F))

# Host names for SSH commands
BUILDNODE        ?= head1
HEADNODE         ?= ${BUILDNODE}

# Vagrant config
VAGRANT_PROVIDER ?= libvirt
VAGRANT_VMS      ?= $(HEADNODE)
VAGRANT_CWD      ?= $(SCENARIOS_D)/$(SCENARIO)/
SSH_CONFIG       ?= ~/.ssh/config  # Vagrant modifies this, should it always?

# Ansible args, for verbosity and other runtime parameters
ANSIBLE_ARGS     ?=

# Commands
SHELL            = bash -o pipefail
VAGRANT          ?= VAGRANT_CWD=$(VAGRANT_CWD) vagrant
ANSIBLE          ?= ansible -i $(INVENTORY)
ANSIBLE_PB       ?= ansible-playbook $(ANSIBLE_ARGS) -i $(INVENTORY) --extra-vars @$(MASTER_CONFIG)
ANSIBLE_PB_LOCAL ?= ansible-playbook $(ANSIBLE_ARGS) -i $(PI)/inventory/head-localhost --extra-vars "@/opt/cord_profile/genconfig/config.yml"
ANSIBLE_PB_MAAS  ?= ansible-playbook $(ANSIBLE_ARGS) -i /etc/maas/ansible/pod-inventory --extra-vars "@/opt/cord_profile/genconfig/config.yml"
IMAGEBUILDER     ?= python $(BUILD)/scripts/imagebuilder.py
LOGCMD           ?= 2>&1 | tee -a $(LOGS)/$(TS)_$(@F)
SSH_HEAD         ?= ssh $(HEADNODE)
SSH_BUILD        ?= ssh $(BUILDNODE)

# default target, prints help
.DEFAULT: help

help:
	@echo "Please specify a target (config, build, teardown, ...)"

# Config file generation
config: $(CONFIG_FILES)

$(CONFIG_FILES):
	ansible-playbook -i 'localhost,' --extra-vars="cord_podconfig='$(PODCONFIG_PATH)' genconfig_dir='$(GENCONFIG_D)' scenarios_dir='$(SCENARIOS_D)'" $(BUILD)/ansible/genconfig.yml $(LOGCMD)

printconfig: config
	@echo "Scenario: $(SCENARIO)"
	@echo "Profile: $(PROFILE)"

# Primary Targets
# Many of these targets use target-specific variables
# https://www.gnu.org/software/make/manual/html_node/Target_002dspecific.html

build: $(BUILD_TARGETS)

# Utility targets

xos-teardown: xos-update-images
	$(ANSIBLE_PB) $(PI)/teardown-playbook.yml $(LOGCMD)
	rm -f $(M)/onboard-profile $(M)/local-onboard-profile

xos-update-images: clean-images
	rm -f $(M)/start-xos $(M)/local-start-xos

collect-diag:
	$(ANSIBLE_PB) $(PI)/collect-diag-playbook.yml $(LOGCMD)

compute-node-refresh:
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_MAAS) $(PI)/compute-node-refresh-playbook.yml" $(LOGCMD)

vagrant-destroy:
	$(VAGRANT) destroy $(LOGCMD)
	rm -f $(M)/vagrant-up

clean-images:
	rm -f $(M)/docker-images $(M)/local-docker-images $(M)/core-image $(M)/local-core-image

clean-genconfig:
	rm -f $(CONFIG_FILES)

clean-profile:
	rm -rf $(CONFIG_CORD_PROFILE_DIR)
	rm -f $(M)/cord-config $(M)/copy-config

clean-all: vagrant-destroy clean-profile clean-genconfig
	rm -f $(ALL_MILESTONES)

clean-local: clean-profile clean-genconfig
	rm -f $(LOCAL_MILESTONES)

local-ubuntu-dev-env:
	$(ANSIBLE_PB) $(PI)/bootstrap-dev-env.yml $(LOGCMD)

# == PREREQS == #
VAGRANT_UP_PREREQS     ?=
CORD_CONFIG_PREREQS    ?=
COPY_CONFIG_PREREQS    ?=
PREP_BUILDNODE_PREREQS ?=
PREP_HEADNODE_PREREQS  ?=
START_XOS_PREREQS      ?=
DEPLOY_ONOS_PREREQS    ?=

# == MILESTONES == #
# empty target files are touched in the milestones dir to indicate completion

$(M)/prereqs-check:
	$(ANSIBLE_PB) $(PI)/prereqs-check-playbook.yml $(LOGCMD)
	touch $@

$(M)/vagrant-up: | $(VAGRANT_UP_PREREQS)
	$(VAGRANT) up $(VAGRANT_VMS) --provider $(VAGRANT_PROVIDER) $(LOGCMD)
	@echo "Configuring SSH for VM's..."
	$(VAGRANT) ssh-config $(VAGRANT_VMS) > $(SSH_CONFIG)
	touch $@

$(M)/copy-cord: | $(M)/vagrant-up
	$(ANSIBLE_PB) $(PI)/copy-cord-playbook.yml $(LOGCMD)
	touch $@

$(M)/cord-config: | $(M)/vagrant-up $(CORD_CONFIG_PREREQS)
	$(ANSIBLE_PB) $(PI)/cord-config-playbook.yml $(LOGCMD)
	cp -r $(GENCONFIG_D) $(CONFIG_CORD_PROFILE_DIR)/genconfig
	touch $@

$(M)/copy-config: | $(COPY_CONFIG_PREREQS)
	$(ANSIBLE_PB) $(PI)/copy-profile-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-buildnode: | $(M)/vagrant-up $(M)/cord-config $(PREP_BUILDNODE_PREREQS)
	$(ANSIBLE_PB) $(PI)/prep-buildnode-playbook.yml $(LOGCMD)
	@echo Waiting 10 seconds to timeout SSH ControlPersist, and so future ansible commands gain docker group membership
	sleep 10
	touch $@

$(M)/prep-headnode: | $(M)/vagrant-up $(M)/cord-config $(PREP_HEADNODE_PREREQS)
	$(ANSIBLE_PB) $(PI)/prep-headnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-elasticstack: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/deploy-elasticstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-computenode: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/prep-computenode-playbook.yml $(LOGCMD)
	touch $@

$(M)/glance-images: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/glance-images-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-openstack: | $(M)/deploy-elasticstack $(M)/prep-headnode $(M)/prep-computenode
	$(ANSIBLE_PB) $(PI)/deploy-openstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-maas: | $(M)/deploy-openstack
	$(ANSIBLE_PB) $(MAAS)/head.yml $(LOGCMD)
	touch $@

$(M)/deploy-computenode: | $(M)/deploy-openstack
	$(ANSIBLE_PB) $(PI)/deploy-computenode-playbook.yml $(LOGCMD)
	touch $@

$(M)/docker-images: | $(M)/prep-buildnode
	$(SSH_BUILD) "cd /opt/cord/build; $(IMAGEBUILDER) -f $(MASTER_CONFIG) -l $(BUILD)/image_logs -g $(BUILD)/ib_graph.dot -a $(BUILD)/ib_actions.yml " $(LOGCMD)
	touch $@

$(M)/core-image: | $(M)/docker-images $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/build-core-image-playbook.yml $(LOGCMD)
	touch $@

$(M)/start-xos: | $(M)/prep-headnode $(M)/core-image $(START_XOS_PREREQS)
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/start-xos-playbook.yml" $(LOGCMD)
	touch $@

$(M)/onboard-profile: | $(M)/start-xos
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-profile-playbook.yml" $(LOGCMD)
	touch $@

$(M)/build-onos-apps: | $(M)/prep-buildnode
	$(SSH_BUILD) "cd /opt/cord/onos-apps; make images" $(LOGCMD)
	touch $@

$(M)/deploy-onos: | $(M)/prep-headnode $(M)/docker-images $(M)/build-onos-apps $(DEPLOY_ONOS_PREREQS)
	$(ANSIBLE_PB) $(PI)/deploy-mavenrepo-playbook.yml $(LOGCMD)
	$(ANSIBLE_PB) $(PI)/deploy-onos-playbook.yml $(LOGCMD)
	touch $@

$(M)/onboard-openstack: | $(M)/deploy-computenode $(M)/glance-images $(M)/deploy-onos $(M)/onboard-profile
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-openstack-playbook.yml" $(LOGCMD)
	touch $@

# Testing targets
pod-test: $(M)/onboard-openstack collect-diag
	$(ANSIBLE_PB) $(PI)/pod-test-playbook.yml $(LOGCMD)

# Local Targets, bring up XOS containers without a VM

$(M)/local-cord-config:
	$(ANSIBLE_PB) $(PI)/cord-config-playbook.yml $(LOGCMD)
	touch $@

$(M)/local-docker-images: | $(M)/local-cord-config
	$(IMAGEBUILDER) -f $(MASTER_CONFIG) -l $(BUILD)/image_logs -g $(BUILD)/ib_graph.dot -a $(BUILD)/ib_actions.yml $(LOGCMD)
	touch $@

$(M)/local-core-image: | $(M)/local-docker-images
	$(ANSIBLE_PB) $(PI)/build-core-image-playbook.yml $(LOGCMD)
	touch $@

$(M)/local-start-xos: | $(M)/local-core-image
	$(ANSIBLE_PB) $(PI)/start-xos-playbook.yml $(LOGCMD)
	touch $@

$(M)/local-onboard-profile: | $(M)/local-start-xos
	$(ANSIBLE_PB) $(PI)/onboard-profile-playbook.yml $(LOGCMD)
	touch $@

