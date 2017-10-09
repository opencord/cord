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

PREP_MS          ?= $(M)/prereqs-check $(M)/build-local-bootstrap $(M)/ciab-ovs $(M)/vagrant-up $(M)/vagrant-ssh-install $(M)/copy-cord $(M)/cord-config $(M)/copy-config $(M)/prep-buildnode $(M)/prep-headnode $(M)/deploy-elasticstack $(M)/prep-computenode
MAAS_MS          ?= $(M)/build-maas-images $(M)/maas-prime $(M)/publish-maas-images $(M)/deploy-maas
OPENSTACK_MS     ?= $(M)/glance-images $(M)/deploy-openstack  $(M)/deploy-computenode $(M)/onboard-openstack
XOS_MS           ?= $(M)/docker-images $(M)/core-image $(M)/publish-docker-images $(M)/start-xos $(M)/onboard-profile
ONOS_MS          ?= $(M)/build-onos-apps $(M)/publish-onos-apps $(M)/deploy-onos $(M)/deploy-mavenrepo
POST_INSTALL_MS  ?= $(M)/setup-automation $(M)/setup-ciab-pcu $(M)/compute1-up $(M)/compute2-up $(M)/compute3-up
ALL_MILESTONES   ?= $(PREP_MS) $(MAAS_MS) $(OPENSTACK_MS) $(XOS_MS) $(ONOS_MS) $(POST_INSTALL_MS)

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
VAGRANT_SWITCHES ?= leaf1
VAGRANT_CWD      ?= $(SCENARIOS_D)/$(SCENARIO)/

# Virsh config
VIRSH_CORDDEV_DOMAIN ?= cord_corddev

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
	@echo "Please specify a target (config, build, ...)"

# Config file generation
config: $(CONFIG_FILES)
	@echo ""
	@echo "CORD is configured with profile: '$(PROFILE)', scenario: '$(SCENARIO)'"
	@echo "Run 'make -j4 build' to continue."

$(CONFIG_FILES):
	test -e "$(PODCONFIG_PATH)" || { echo "PODCONFIG file $(PODCONFIG_PATH) doesn't exist!" ; exit 1; }
	ansible-playbook -i 'localhost,' --extra-vars="cord_podconfig='$(PODCONFIG_PATH)' genconfig_dir='$(GENCONFIG_D)' scenarios_dir='$(SCENARIOS_D)'" $(BUILD)/ansible/genconfig.yml $(LOGCMD)

printconfig:
	@echo "Scenario: '$(SCENARIO)'"
	@echo "Profile: '$(PROFILE)'"

# Primary Targets
build: $(BUILD_TARGETS)


# Utility targets
ansible-ping:
	$(ANSIBLE) -m ping all $(LOGCMD)

ansible-setup:
	$(ANSIBLE) -m setup all $(LOGCMD)

clean-images:
	rm -f $(M)/docker-images $(M)/local-docker-images $(M)/copy-cord $(M)/core-image $(M)/local-core-image $(M)/build-maas-images $(M)/build-onos-apps $(M)/publish-maas-images $(M)/publish-docker-images $(M)/publish-onos-apps

clean-genconfig:
	rm -f $(CONFIG_FILES)

clean-profile:
	rm -rf $(CONFIG_CORD_PROFILE_DIR)/*
	rm -f $(M)/cord-config $(M)/copy-config $(M)/onboard-profile $(M)/local-onboard-profile $(M)/onboard-openstack $(M)/refresh-fabric

clean-all: virsh-domain-destroy vagrant-destroy clean-profile clean-genconfig
	rm -f $(ALL_MILESTONES)

clean-local: clean-profile clean-genconfig clean-images
	rm -f $(LOCAL_MILESTONES)

clean-onos:
	$(ANSIBLE_PB) $(PI)/teardown-onos-playbook.yml $(LOGCMD)
	rm -f $(M)/deploy-onos $(M)/onos-debug

clean-openstack:
	$(SSH_HEAD) "/opt/cord/build/platform-install/scripts/clean_openstack.sh" $(LOGCMD)
	rm -f $(M)/onboard-openstack

collect-diag:
	$(ANSIBLE_PB) $(PI)/collect-diag-playbook.yml $(LOGCMD)

compute-node-refresh:
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_MAAS) --private-key ~/.ssh/cord_rsa $(PI)/compute-node-refresh-playbook.yml" $(LOGCMD)

.PHONY: docs
docs:
	cd docs; make

local-ubuntu-dev-env:
	$(ANSIBLE_PB) $(PI)/bootstrap-dev-env.yml $(LOGCMD)

vagrant-destroy:
	$(VAGRANT) destroy -f $(LOGCMD)
	rm -f $(M)/vagrant-up $(M)/vagrant-ssh-install $(VAGRANT_SSH_CONF)

virsh-domain-destroy:
	virsh destroy ${VIRSH_CORDDEV_DOMAIN} || true
	virsh undefine ${VIRSH_CORDDEV_DOMAIN} || true

xos-teardown: xos-update-images
	$(ANSIBLE_PB) $(PI)/teardown-xos-playbook.yml $(LOGCMD)
	rm -f $(M)/onboard-profile $(M)/local-onboard-profile

xos-update-images: clean-images
	rm -f $(M)/start-xos $(M)/local-start-xos


# == PREREQS == #
VAGRANT_UP_PREREQS     ?=
COPY_CORD_PREREQS      ?=
CORD_CONFIG_PREREQS    ?=
COPY_CONFIG_PREREQS    ?=
PREP_BUILDNODE_PREREQS ?=
PREP_HEADNODE_PREREQS  ?=
DOCKER_IMAGES_PREREQS  ?=
START_XOS_PREREQS      ?=
DEPLOY_ONOS_PREREQS    ?=
DEPLOY_OPENSTACK_PREREQS ?=
DEPLOY_MAVENREPO_PREREQS ?=
SETUP_AUTOMATION_PREREQS ?=

# == MILESTONES == #
# empty target files are touched in the milestones dir to indicate completion

# Prep targets
$(M)/prereqs-check:
	$(ANSIBLE_PB) $(PI)/prereqs-check-playbook.yml $(LOGCMD)
	touch $@

$(M)/build-local-bootstrap:
	$(ANSIBLE_PB) $(BUILD)/ansible/build-local-bootstrap.yml $(LOGCMD)
	touch $@

$(M)/ciab-ovs:
	$(ANSIBLE_PB) $(BUILD)/ansible/ciab-ovs.yml $(LOGCMD)
	touch $@

$(M)/vagrant-up: | $(VAGRANT_UP_PREREQS)
	$(VAGRANT) up $(VAGRANT_VMS) --provider $(VAGRANT_PROVIDER) $(LOGCMD)
	touch $@

$(M)/vagrant-ssh-install: | $(M)/vagrant-up
	$(VAGRANT) ssh-config $(VAGRANT_VMS) > /tmp/vagrant_ssh_config
	$(ANSIBLE_PB) $(BUILD)/ansible/vagrant-ssh-install.yml $(LOGCMD)
	touch $@

$(M)/config-ssh-key: | $(M)/vagrant-up
	$(ANSIBLE_PB) $(BUILD)/ansible/config-ssh-key.yml $(LOGCMD)
	touch $@

$(M)/copy-cord: | $(M)/vagrant-ssh-install $(COPY_CORD_PREREQS)
	$(ANSIBLE_PB) $(PI)/copy-cord-playbook.yml $(LOGCMD)
	touch $@

$(M)/cord-config: | $(M)/vagrant-ssh-install $(CORD_CONFIG_PREREQS)
	$(ANSIBLE_PB) $(PI)/cord-config-playbook.yml $(LOGCMD)
	cp -r $(GENCONFIG_D) $(CONFIG_CORD_PROFILE_DIR)/genconfig
	touch $@

$(M)/copy-config: | $(COPY_CONFIG_PREREQS)
	$(ANSIBLE_PB) $(PI)/copy-profile-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-buildnode: | $(M)/vagrant-ssh-install $(M)/cord-config $(PREP_BUILDNODE_PREREQS)
	$(ANSIBLE_PB) $(PI)/prep-buildnode-playbook.yml $(LOGCMD)
	@echo Waiting 20 seconds to timeout SSH ControlPersist, and so future ansible commands gain docker group membership
	sleep 20
	touch $@

$(M)/prep-headnode: | $(M)/vagrant-ssh-install $(M)/cord-config $(PREP_HEADNODE_PREREQS)
	$(ANSIBLE_PB) $(PI)/prep-headnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-elasticstack: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/deploy-elasticstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-computenode: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/prep-computenode-playbook.yml $(LOGCMD)
	touch $@


# MaaS targets
$(M)/build-maas-images: | $(M)/prep-buildnode $(BUILD_MAAS_IMAGES_PREREQS)
	$(SSH_BUILD) "cd $(BUILD_CORD_DIR)/build/maas; rm -f consul.image; make MAKE_CONFIG=../$(MAKEFILE_CONFIG) build" $(LOGCMD)
	touch $@

$(M)/maas-prime: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(MAAS)/prime-node.yml $(LOGCMD)
	touch $@

$(M)/publish-maas-images: | $(M)/maas-prime $(M)/build-maas-images
	$(SSH_BUILD) "cd $(BUILD_CORD_DIR)/build/maas; rm -f consul.publish; make MAKE_CONFIG=../$(MAKEFILE_CONFIG) publish" $(LOGCMD)
	touch $@

$(M)/deploy-maas: | $(M)/publish-maas-images $(M)/cord-config $(M)/copy-config
	$(ANSIBLE_PB) $(MAAS)/head-node.yml $(LOGCMD)
	touch $@


# ONOS targets
$(M)/build-onos-apps: | $(M)/prep-buildnode $(BUILD_ONOS_APPS_PREREQS)
	$(SSH_BUILD) "cd $(BUILD_CORD_DIR)/onos-apps; make MAKE_CONFIG=../build/$(MAKEFILE_CONFIG) build" $(LOGCMD)
	touch $@

$(M)/publish-onos-apps: | $(M)/deploy-maas $(M)/build-onos-apps
	$(SSH_BUILD) "cd $(BUILD_CORD_DIR)/onos-apps; make MAKE_CONFIG=../build/$(MAKEFILE_CONFIG) publish" $(LOGCMD)
	touch $@

$(M)/deploy-mavenrepo: | $(M)/publish-onos-apps $(DEPLOY_MAVENREPO_PREREQS)
	$(ANSIBLE_PB) $(PI)/deploy-mavenrepo-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-onos: | $(M)/docker-images $(DEPLOY_ONOS_PREREQS)
	$(ANSIBLE_PB) $(PI)/deploy-onos-playbook.yml $(LOGCMD)
	touch $@

$(M)/onos-debug: | $(M)/onboard-profile $(M)/deploy-onos
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onos-debug-playbook.yml" $(LOGCMD)
	touch $@


# XOS targets
$(M)/docker-images: | $(M)/prep-buildnode $(DOCKER_IMAGES_PREREQS)
	$(SSH_BUILD) "cd $(BUILD_CORD_DIR)/build; $(IMAGEBUILDER) -f $(MASTER_CONFIG) -l $(BUILD)/image_logs -g $(BUILD)/ib_graph.dot -a $(BUILD)/ib_actions.yml " $(LOGCMD)
	touch $@

$(M)/core-image: | $(M)/docker-images
	$(ANSIBLE_PB) $(PI)/build-core-image-playbook.yml $(LOGCMD)
	touch $@

# Requires ib_actions.yml file which is on the build host
$(M)/publish-docker-images: | $(M)/deploy-maas $(M)/docker-images $(M)/core-image
	$(SSH_BUILD) "cd $(BUILD_CORD_DIR)/build; $(ANSIBLE_PB_LOCAL) $(PI)/publish-images-playbook.yml" $(LOGCMD)
	touch $@

$(M)/start-xos: | $(M)/prep-headnode $(M)/core-image $(START_XOS_PREREQS)
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/start-xos-playbook.yml" $(LOGCMD)
	touch $@

$(M)/onboard-profile: | $(M)/start-xos
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-profile-playbook.yml" $(LOGCMD)
	touch $@


# OpenStack targets
$(M)/glance-images: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/glance-images-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-openstack: | $(M)/prep-headnode $(M)/prep-computenode $(DEPLOY_OPENSTACK_PREREQS)
	$(ANSIBLE_PB) $(PI)/deploy-openstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-computenode: | $(M)/deploy-openstack
	$(ANSIBLE_PB) $(PI)/deploy-computenode-playbook.yml $(LOGCMD)
	touch $@

$(M)/onboard-openstack: | $(M)/deploy-computenode $(M)/glance-images $(M)/deploy-onos $(M)/onboard-profile
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-openstack-playbook.yml" $(LOGCMD)
	touch $@


# Post-onboarding targets
$(M)/setup-automation: | $(M)/onboard-profile $(M)/deploy-onos $(SETUP_AUTOMATION_PREREQS)
	$(ANSIBLE_PB) $(PI)/cord-automation-playbook.yml $(LOGCMD)
	touch $@


# Additional CiaB targets
$(M)/setup-ciab-pcu: | $(M)/setup-automation
	$(ANSIBLE_PB) $(MAAS)/setup-ciab-pcu.yml
	touch $@

$(M)/compute%-up: | $(M)/setup-ciab-pcu
	$(VAGRANT) up compute$* --provider $(VAGRANT_PROVIDER) $(LOGCMD)
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) ansible/maas-provision.yml --extra-vars='maas_user=maas vagrant_name=cord_compute$*'" $(LOGCMD)
	touch $@

$(M)/refresh-fabric: | $(M)/compute1-up
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_MAAS) $(PI)/cord-refresh-fabric.yml" $(LOGCMD)
	touch $@


# Testing targets
pod-test: $(M)/setup-automation collect-diag
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/pod-test-playbook.yml" $(LOGCMD)

fabric-pingtest: $(M)/refresh-fabric
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_MAAS) $(PI)/cord-fabric-pingtest.yml" $(LOGCMD)


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

