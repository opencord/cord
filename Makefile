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

# Configuration paths
PODCONFIG_D      ?= $(BUILD)/podconfig
SCENARIOS_D      ?= $(BUILD)/scenarios
GENCONFIG_D      ?= $(BUILD)/genconfig

# Milestones/logs paths
M                ?= $(BUILD)/milestones
LOGS             ?= $(BUILD)/logs

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
SSH_CONFIG       ?= ~/.ssh/config  # Vagrant will modify this

# Commands
SHELL            = bash -o pipefail
VAGRANT          ?= VAGRANT_CWD=$(VAGRANT_CWD) vagrant
ANSIBLE          ?= ansible -i $(INVENTORY)
ANSIBLE_PB       ?= ansible-playbook -i $(INVENTORY) --extra-vars @$(MASTER_CONFIG)
ANSIBLE_PB_LOCAL ?= ansible-playbook -i $(PI)/inventory/head-localhost --extra-vars "cord_profile=$(PROFILE)"
IMAGEBUILDER     ?= python $(BUILD)/scripts/imagebuilder.py
LOGCMD           ?= 2>&1 | tee -a $(LOGS)/$(TS)_$(@F)
SSH_HEAD         ?= ssh $(HEADNODE)
SSH_BUILD        ?= ssh $(BUILDNODE)

# default target, prints help
.DEFAULT: help

help:
	@echo "Please specify a target (config, deploy, teardown, ...)"

config: $(CONFIG_FILES)

cleanconfig:
	rm -f $(CONFIG_FILES)

# Config file generation
PODCONFIG_PATH   ?= $(PODCONFIG_D)/$(PODCONFIG)

$(CONFIG_FILES):
	# FIXME - check if PODCONFIG_PATH exists, print error, rather than running ansible and failing
	ansible-playbook -i 'localhost,' --extra-vars="cord_podconfig='$(PODCONFIG_PATH)' genconfig_dir='$(GENCONFIG_D)' scenarios_dir='$(SCENARIOS_D)'" $(BUILD)/ansible/genconfig.yml $(LOGCMD)

printconfig: config
	@echo "Scenario: $(SCENARIO)"
	@echo "Profile: $(PROFILE)"

# Primary Targets
# Many of these targets use target-specific variables
# https://www.gnu.org/software/make/manual/html_node/Target_002dspecific.html

build: $(BUILD_TARGETS)

# physical builds
cord: BUILDNODE = corddev
cord: VAGRANT_VMS = corddev
cord: $(M)/elasticstack $(M)/deploy-maas $(M)/onboard-openstack

opencloud: $(M)/elasticstack $(M)/onboard-openstack

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

$(M)/prereqs-check:
	$(ANSIBLE_PB) $(PI)/prereqs-check-playbook.yml $(LOGCMD)
	touch $@

$(M)/vagrant-up: $(VAGRANT_UP_PREREQS)
	$(VAGRANT) up $(VAGRANT_VMS) --provider $(VAGRANT_PROVIDER) $(LOGCMD)
	echo "Configuring SSH for VM's..."
	$(VAGRANT) ssh-config $(VAGRANT_VMS) > $(SSH_CONFIG)
	touch $@

$(M)/copy-cord: | $(M)/vagrant-up
	$(ANSIBLE_PB) $(PI)/copy-cord-playbook.yml $(LOGCMD)
	touch $@

$(M)/cord-config: | $(M)/copy-cord
	$(ANSIBLE_PB) $(PI)/cord-config-playbook.yml $(LOGCMD)
	touch $@

$(M)/copy-config: | $(M)/cord-config
	$(ANSIBLE_PB) $(PI)/copy-profile-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-buildnode: | $(M)/cord-config $(M)/copy-config
	$(ANSIBLE_PB) $(PI)/prep-buildnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-headnode: | $(M)/prep-buildnode
	$(ANSIBLE_PB) $(PI)/prep-headnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/elasticstack: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/deploy-elasticstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-computenode: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/prep-computenode-playbook.yml $(LOGCMD)
	touch $@

$(M)/glance-images: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/glance-images-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-openstack: | $(M)/elasticstack $(M)/prep-headnode $(M)/prep-computenode
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

$(M)/core-image: | $(M)/docker-images
	$(ANSIBLE_PB) $(PI)/build-core-image-playbook.yml $(LOGCMD)
	touch $@

$(M)/start-xos: | $(M)/prep-headnode $(M)/core-image
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/start-xos-playbook.yml" $(LOGCMD)
	touch $@

$(M)/onboard-profile: | $(M)/start-xos
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-profile-playbook.yml" $(LOGCMD)
	touch $@

$(M)/deploy-onos: | $(M)/start-xos $(M)/docker-images
	$(ANSIBLE_PB) $(PI)/deploy-onos-playbook.yml $(LOGCMD)
	touch $@

$(M)/onboard-openstack: | $(M)/deploy-computenode $(M)/glance-images $(M)/deploy-onos $(M)/onboard-profile
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-openstack-playbook.yml" $(LOGCMD)
	touch $@

# Testing targets
pod-test: $(M)/onboard-openstack
	$(ANSIBLE_PB) $(PI)/pod-test-playbook.yml $(LOGCMD)

# Local Targets, mainly for testing, without a VM

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

