# CORD Master Makefile

# Timestamp for log files
TS               := $(shell date +'%Y%m%dT%H%M%SZ')

# Source path
BUILD            ?= .
CORD             ?= ..
PI               ?= $(BUILD)/platform-install
KUBESPRAY        ?= $(BUILD)/kubespray
MAAS             ?= $(BUILD)/maas
ONOS_APPS        ?= $(CORD)/onos-apps

# Configuration paths
ifdef PODCONFIG_PATH
	USECASE      := $(shell grep cord_profile: $(PODCONFIG_PATH) | awk '{print $$2}' | awk -F '-' '{print $$1}')
else ifdef PODCONFIG
	USECASE      := $(shell echo $(PODCONFIG) | awk -F '-' '{print $$1}')
else
	USECASE      = invalid
endif

PROFILE_D        ?= $(CORD)/orchestration/profiles/$(USECASE)
PODCONFIG_PATH   ?= $(PROFILE_D)/podconfig/$(PODCONFIG)

SCENARIOS_D      ?= $(BUILD)/scenarios
GENCONFIG_D      ?= $(BUILD)/genconfig

CONFIG_CORD_PROFILE_DIR ?= $(CORD)/../cord_profile

# Milestones/logs paths
M                ?= $(BUILD)/milestones
LOGS             ?= $(BUILD)/logs

PREP_MS          ?= $(M)/prereqs-check $(M)/build-local-bootstrap $(M)/ciab-ovs $(M)/vagrant-up $(M)/vagrant-ssh-install $(M)/copy-cord $(M)/cord-config $(M)/copy-config $(M)/prep-buildnode $(M)/prep-headnode $(M)/deploy-elasticstack $(M)/prep-computenode
KS_MS            ?= $(M)/prep-kubespray $(M)/deploy-kubespray $(M)/finish-kubespray $(M)/install-kubernetes-tools $(M)/start-xos-helm
MAAS_MS          ?= $(M)/build-maas-images $(M)/maas-prime $(M)/publish-maas-images $(M)/deploy-maas
OPENSTACK_MS     ?= $(M)/glance-images $(M)/deploy-openstack  $(M)/deploy-computenode $(M)/onboard-openstack
XOS_MS           ?= $(M)/docker-images $(M)/core-image $(M)/publish-docker-images $(M)/start-xos $(M)/onboard-profile
ONOS_MS          ?= $(M)/build-onos-apps $(M)/publish-onos-apps $(M)/deploy-onos $(M)/deploy-mavenrepo
POST_INSTALL_MS  ?= $(M)/setup-automation $(M)/setup-ciab-pcu $(M)/compute1-up $(M)/compute2-up $(M)/compute3-up
LOCAL_MILESTONES ?= $(M)/local-cord-config $(M)/local-docker-images $(M)/local-core-image $(M)/local-start-xos $(M)/local-onboard-profile
ALL_MILESTONES   ?= $(PREP_MS) $(KS_MS) $(MAAS_MS) $(OPENSTACK_MS) $(XOS_MS) $(ONOS_MS) $(POST_INSTALL_MS) $(LOCAL_MILESTONES)

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
EXTRA_VARS       ?= --extra-vars "@/opt/cord_profile/genconfig/config.yml"

# Commands
SHELL            = bash -o pipefail
VAGRANT          ?= VAGRANT_CWD=$(VAGRANT_CWD) vagrant
ANSIBLE          ?= ansible -i $(INVENTORY)
ANSIBLE_PB       ?= ansible-playbook $(ANSIBLE_ARGS) -i $(INVENTORY) --extra-vars @$(MASTER_CONFIG)
ANSIBLE_PB_KS    ?= ANSIBLE_CONFIG=../ansible.cfg ansible-playbook $(ANSIBLE_ARGS) -b -i inventory/inventory.cord --extra-vars @../$(MASTER_CONFIG)
ANSIBLE_PB_LOCAL ?= ansible-playbook $(ANSIBLE_ARGS) -i $(PI)/inventory/head-localhost $(EXTRA_VARS)
ANSIBLE_PB_MAAS  ?= ansible-playbook $(ANSIBLE_ARGS) -i /etc/maas/ansible/pod-inventory $(EXTRA_VARS)
IMAGEBUILDER     ?= python $(BUILD)/scripts/imagebuilder.py
LOGCMD           ?= 2>&1 | tee -a $(abspath $(LOGS)/$(TS)_$(@F))
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
	@test -e "$(PODCONFIG_PATH)" || { echo ""; echo "PODCONFIG file $(PODCONFIG_PATH) doesn't exist!" ; echo "*** Specify a valid CORD config file using PODCONFIG or PODCONFIG_PATH ***"; echo ""; exit 1; }
	ansible-playbook -i 'localhost,' --extra-vars="cord_podconfig='$(PODCONFIG_PATH)' genconfig_dir='$(GENCONFIG_D)' scenarios_dir='$(SCENARIOS_D)' platform_install_dir='$(PI)' cord_profile_src_dir='$(PROFILE_D)' " $(BUILD)/ansible/genconfig.yml $(LOGCMD)

printconfig:
	@echo "Scenario: '$(SCENARIO)'"
	@echo "Profile: '$(PROFILE)'"

# == BUILD TARGET == #
# This is entirely determined by the podconfig/scenario, and should generally
# be set to only one value - everything else should be a dependency
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

clean-onos:
	$(ANSIBLE_PB) $(PI)/teardown-onos-playbook.yml $(LOGCMD)
	rm -f $(M)/deploy-onos $(M)/onos-debug

clean-openstack:
	$(SSH_HEAD) "/opt/cord/build/platform-install/scripts/clean_openstack.sh" $(LOGCMD)
	rm -f $(M)/onboard-openstack

clean-kubespray:
	rm -f $(KS_MS)
	rm -rf $(KUBESPRAY)

# prereqs append the milestones dir to the front, but diag targets can be run multiple times
$(M)/collect-diag: | collect-diag
$(M)/collect-diag-maas: | collect-diag-maas

collect-diag:
	$(ANSIBLE_PB) $(PI)/collect-diag-playbook.yml $(LOGCMD)

collect-diag-maas:
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_MAAS) --private-key ~/.ssh/cord_rsa $(PI)/collect-diag-playbook.yml" $(LOGCMD)

compute-node-refresh:
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_MAAS) --private-key ~/.ssh/cord_rsa $(PI)/compute-node-refresh-playbook.yml" $(LOGCMD)

vagrant-destroy:
	$(VAGRANT) destroy -f $(LOGCMD) || true
	rm -f $(M)/vagrant-up $(M)/vagrant-ssh-install $(VAGRANT_SSH_CONF)

virsh-domain-destroy:
	virsh destroy ${VIRSH_CORDDEV_DOMAIN} || true
	virsh undefine ${VIRSH_CORDDEV_DOMAIN} || true

xos-teardown: xos-update-images
	$(ANSIBLE_PB) $(PI)/teardown-xos-playbook.yml $(LOGCMD)
	rm -f $(M)/onboard-profile

xos-update-images: clean-images
	rm -f $(M)/start-xos $(M)/local-start-xos

# local scenario helpers
clean-local: local-xos-teardown clean-profile clean-genconfig clean-images
	rm -f $(LOCAL_MILESTONES)

local-ubuntu-dev-env:
	$(ANSIBLE_PB) $(PI)/bootstrap-dev-env.yml $(LOGCMD)

local-xos-teardown: xos-update-images
	$(eval COMPOSE_FILE := $(shell cd $(CONFIG_CORD_PROFILE_DIR); ls dynamic_load/* 2>/dev/null | tr '\n' ':')docker-compose.yml)
	cd $(CONFIG_CORD_PROFILE_DIR); COMPOSE_FILE=$(COMPOSE_FILE) docker-compose -p $(PROFILE) rm -s -f || true
	rm -f $(M)/local-onboard-profile

# ===== usage: make xos-service-config NAME=exampleservice PATH=exampleservice KEYPAIR=exampleservice_rsa =======

xos-service-config:
	# NOTE check that variables are set before calling ansible?
	$(ANSIBLE_PB) --extra-vars 'xos_dynamic_services={"name": $(NAME), "path"=$(PATH), "keypair"= $(KEYPAIR)}' $(PI)/xos-service-config.yml $(LOGCMD)

xos-services-up:
	$(ANSIBLE_PB) $(PI)/xos-services-up.yml $(LOGCMD)

# docs
.PHONY: docs
docs:
	cd docs; make

# == PREREQS == #
VAGRANT_UP_PREREQS            ?=
COPY_CORD_PREREQS             ?=
CORD_CONFIG_PREREQS           ?=
CONFIG_SSH_KEY_PREREQS        ?=
PREP_BUILDNODE_PREREQS        ?=
PREP_HEADNODE_PREREQS         ?=
PREP_KUBESPRAY_PREREQS        ?=
DOCKER_IMAGES_PREREQS         ?=
PUBLISH_DOCKER_IMAGES_PREREQS ?=
START_XOS_PREREQS             ?=
BUILD_ONOS_APPS_PREREQS       ?=
DEPLOY_ONOS_PREREQS           ?=
DEPLOY_MAVENREPO_PREREQS      ?=
DEPLOY_OPENSTACK_PREREQS      ?=
ONBOARD_OPENSTACK_PREREQS     ?=
SETUP_AUTOMATION_PREREQS      ?=
TESTING_PREREQS               ?=

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

$(M)/config-ssh-key: | $(CONFIG_SSH_KEY_PREREQS)
	$(ANSIBLE_PB) $(BUILD)/ansible/config-ssh-key.yml $(LOGCMD)
	touch $@

$(M)/copy-cord: | $(COPY_CORD_PREREQS)
	$(ANSIBLE_PB) $(PI)/copy-cord-playbook.yml $(LOGCMD)
	touch $@

$(M)/cord-config: | $(CORD_CONFIG_PREREQS)
	$(ANSIBLE_PB) $(PI)/cord-config-playbook.yml $(LOGCMD)
	rm -rf $(CONFIG_CORD_PROFILE_DIR)/genconfig
	cp -r $(GENCONFIG_D) $(CONFIG_CORD_PROFILE_DIR)/genconfig
	touch $@

$(M)/copy-config: | $(M)/cord-config
	$(ANSIBLE_PB) $(PI)/copy-profile-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-buildnode: | $(M)/cord-config $(PREP_BUILDNODE_PREREQS)
	$(ANSIBLE_PB) $(PI)/prep-buildnode-playbook.yml $(LOGCMD)
	@echo Waiting 20 seconds to timeout SSH ControlPersist, and so future ansible commands gain docker group membership
	sleep 20
	touch $@

$(M)/prep-headnode: | $(M)/cord-config $(PREP_HEADNODE_PREREQS)
	$(ANSIBLE_PB) $(PI)/prep-headnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-elasticstack: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/deploy-elasticstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-computenode: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/prep-computenode-playbook.yml $(LOGCMD)
	touch $@


# kubernetes targets
$(M)/prep-kubespray: | $(M)/prep-headnode $(M)/prep-computenode $(PREP_KUBESPRAY_PREREQS)
	$(ANSIBLE_PB) $(BUILD)/ansible/prep-kubespray.yml $(LOGCMD)
	touch $@

$(M)/deploy-kubespray: | $(M)/prep-kubespray
	cd $(KUBESPRAY); $(ANSIBLE_PB_KS) cluster.yml $(LOGCMD)
	touch $@

$(M)/finish-kubespray: | $(M)/deploy-kubespray
	cd $(BUILD); $(ANSIBLE_PB) $(BUILD)/ansible/finish-kubespray.yml $(LOGCMD)
	touch $@

$(M)/install-kubernetes-tools: | $(M)/deploy-kubespray
	$(ANSIBLE_PB) $(PI)/install-kubernetes-tools-playbook.yml $(LOGCMD)
	touch $@

$(M)/start-xos-helm: | $(M)/install-kubernetes-tools $(M)/finish-kubespray $(M)/publish-docker-images
	$(ANSIBLE_PB) $(PI)/start-xos-helm-playbook.yml $(LOGCMD)
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
$(M)/deploy-mavenrepo: | $(M)/docker-images $(DEPLOY_MAVENREPO_PREREQS)
	$(ANSIBLE_PB) $(PI)/deploy-mavenrepo-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-onos: | $(M)/docker-images $(M)/deploy-mavenrepo $(DEPLOY_ONOS_PREREQS)
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
$(M)/publish-docker-images: | $(M)/docker-images $(M)/core-image $(PUBLISH_DOCKER_IMAGES_PREREQS)
	$(SSH_BUILD) "cd $(BUILD_CORD_DIR)/build; $(ANSIBLE_PB_LOCAL) $(PI)/publish-images-playbook.yml" $(LOGCMD)
	touch $@

$(M)/start-xos: | $(M)/prep-headnode $(M)/cord-config $(M)/core-image $(START_XOS_PREREQS)
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/start-xos-playbook.yml" $(LOGCMD)
	touch $@

$(M)/onboard-profile: | $(M)/start-xos
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-profile-playbook.yml" $(LOGCMD)
	touch $@


# OpenStack targets
$(M)/glance-images: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/glance-images-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-openstack: | $(M)/prep-headnode $(DEPLOY_OPENSTACK_PREREQS)
	$(ANSIBLE_PB) $(PI)/deploy-openstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-computenode: | $(M)/prep-computenode $(M)/deploy-openstack
	$(ANSIBLE_PB) $(PI)/deploy-computenode-playbook.yml $(LOGCMD)
	touch $@

$(M)/onboard-openstack: | $(M)/deploy-computenode $(M)/glance-images $(M)/deploy-onos $(M)/onboard-profile $(ONBOARD_OPENSTACK_PREREQS)
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

compute1-up: | $(M)/compute1-up
compute2-up: | $(M)/compute2-up
compute3-up: | $(M)/compute3-up

# Fabric targets
fabric-refresh: | $(M)/setup-automation
	$(ANSIBLE_PB) $(PI)/cord-refresh-fabric.yml $(LOGCMD)

fabric-pingtest:
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_MAAS) --private-key ~/.ssh/cord_rsa $(PI)/cord-fabric-pingtest.yml" $(LOGCMD)


# Testing targets

# R-CORD specific targets
pod-test: | $(TESTING_PREREQS)
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/pod-test-playbook.yml" $(LOGCMD)

rcord-%:
	$(ANSIBLE_PB) ../orchestration/profiles/rcord/test/rcord-$*-playbook.yml $(LOGCMD)

# M-CORD specific targets
mcord-%:
	$(ANSIBLE_PB) ../orchestration/profiles/mcord/test/mcord-$*-playbook.yml $(LOGCMD)

# E-CORD specific targets
ecord-%:
	$(ANSIBLE_PB) ../orchestration/profiles/ecord/test/ecord-$*-playbook.yml $(LOGCMD)


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

