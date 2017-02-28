# CORD Build Makefile

# Target, used to determine builds/paths/etc. when shared between environments
TARGET           ?= $(firstword $(MAKECMDGOALS))

# Timestamp for log files
TS               := $(shell date +'%Y%m%dT%H%M%SZ')

# Source paths
BUILD            ?= .
CONFIG           ?= $(BUILD)/config
CORD             ?= ..
PI               ?= $(BUILD)/platform-install
MAAS             ?= $(BUILD)/maas
VAGRANT_CWD      ?= $(CONFIG)/$(TARGET)/
SSH_CONFIG       ?= ~/.ssh/config

# Milestones/logs paths
M                ?= $(BUILD)/milestones
LOGS             ?= $(BUILD)/logs

# Configuration files
INVENTORY        ?= "$(CONFIG)/$(TARGET)/inventory"
CONFIG_YAML      ?= "$(CONFIG)/$(TARGET)/config.yml"

# Host names
HEADNODE         ?= head1
BUILDNODE        ?= $(HEADNODE)

# Vagrant config
VAGRANT_PROVIDER ?= libvirt
VAGRANT_VMS      ?= $(HEADNODE)

# Commands
SHELL             = bash -o pipefail
VAGRANT           = VAGRANT_CWD=$(VAGRANTCWD) vagrant
ANSIBLE           = ansible -i $(INVENTORY)
ANSIBLE_PB        = ansible-playbook -i $(INVENTORY) --extra-vars @$(CONFIG_YAML)
ANSIBLE_PB_LOCAL  = ansible-playbook -i $(PI)/inventory/head-localhost --extra-vars "cord_profile=${TARGET}"
IMAGEBUILDER      = python /opt/cord/build/scripts/imagebuilder.py
LOGCMD            = 2>&1 | tee $(LOGS)/$(TS)_$(@F)
SSH_HEAD          = ssh $(HEADNODE)
SSH_BUILD         = ssh $(BUILDNODE)

# == TARGETS == #
.DEFAULT: help

help:
	echo "Please specify a target (rcord, opencloud, etc.)"

# physical builds
# R-CORD
rcord: VAGRANT_VMS = corddev
rcord: $(M)/deploy-maas $(M)/onboard-openstack

opencloud: $(M)/onboard-openstack

# test/frontend/mock builds
frontend: $(M)/onboard-profile
mock-rcord: $(M)/onboard-profile

# a theoretical build with XOS + ONOS but no OpenStack
frontend-with-onos: TARGET = frontend
frontend-with-onos: frontend $(M)/onboard-onos

# *-in-a-box virtualized environments
# https://www.gnu.org/software/make/manual/html_node/Target_002dspecific.html
rcord-in-a-box: TARGET = rcord
rcord-in-a-box: HEADNODE = prod
rcord-in-a-box: BUILDNODE = corddev
rcord-in-a-box: VAGRANT_VMS = corddev prod
rcord-in-a-box: rcord

opencloud-in-a-box: TARGET = opencloud
opencloud-in-a-box: HEADNODE = head1
opencloud-in-a-box: VAGRANT_VMS = head1 compute1 compute2
opencloud-in-a-box: opencloud

# testing targets
pod-test: $(M)/onboard-profile
	$(ANSIBLE_PB) $(PI)/pod-test-playbook.yml $(LOGCMD)

# utility targets
teardown:
	$(ANSIBLE_PB) $(PI)/teardown-playbook.yml $(LOGCMD)
	rm -f $(M)/start-xos $(M)/config-xos $(M)/onboard-profile

compute-node-refresh:
	$(ANSIBLE_PB) $(PI)/compute-node-refresh-playbook.yml $(LOGCMD)

opencloud-vagrant-destroy: TARGET = opencloud
opencloud-vagrant-destroy:
	$(VAGRANT) destroy
	rm $(M)/vagrant-up # and everything else?

# == MILESTONES == #
# files are touched in the milestones directory to indicate completion

$(M)/prereqs-check:
	$(ANSIBLE_PB) $(PI)/prereqs-check-playbook.yml $(LOGCMD)
	touch $@

$(M)/vagrant-up: | $(M)/prereqs-check
	$(VAGRANT) up $(VAGRANT_VMS) -provider $(VAGRANT_PROVIDER) $(LOGCMD)
	echo "Configuring SSH for VM's..." $(LOGCMD)
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

$(M)/prep-buildnode: | $(M)/cord-config
	$(ANSIBLE_PB) $(PI)/prep-buildnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-headnode: | $(M)/cord-config $(M)/copy-config
	$(ANSIBLE_PB) $(PI)/prep-headnode-playbook.yml $(LOGCMD)
	touch $@

$(M)/prep-computenode: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/prep-computenode-playbook.yml $(LOGCMD)
	touch $@

$(M)/glance-images: | $(M)/prep-headnode
	$(ANSIBLE_PB) $(PI)/glance-images-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-maas: | $(M)/cord-config $(M)/prep-headnode
	$(ANSIBLE_PB) $(MAAS)/head.yml $(LOGCMD)
	touch $@

$(M)/deploy-openstack: | $(M)/prep-headnode $(M)/prep-computenode
	$(ANSIBLE_PB) $(PI)/deploy-openstack-playbook.yml $(LOGCMD)
	touch $@

$(M)/deploy-computenode: | $(M)/deploy-openstack
	$(ANSIBLE_PB) $(PI)/deploy-computenode-playbook.yml $(LOGCMD)
	touch $@

$(M)/docker-images: | $(M)/prep-headnode # $(M)/prep-buildnode
	$(SSH_HEAD) "cd /opt/cord/build; $(IMAGEBUILDER) -l $(BUILD)/image_logs -g $(BUILD)/ib_graph.dot -a $(BUILD)/ib_actions.yml -b $(CONFIG_YAML)" $(LOGCMD)
	touch $@

#$(M)/push-to-registry: | $(M)/docker-images $(M)/prep-headnode
#	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/push_images_registry.yml" $(LOGCMD)
#	touch $@

$(M)/core-image: | $(M)/docker-images
	$(ANSIBLE_PB) $(PI)/build-core-image-playbook.yml $(LOGCMD)
	touch $@

$(M)/start-xos: | $(M)/core-image # $(M)/push-to-registry
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/start-xos-playbook.yml" $(LOGCMD)
	touch $@

$(M)/onboard-profile: | $(M)/start-xos
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-profile-playbook.yml" $(LOGCMD)
	touch $@

$(M)/deploy-onos: | $(M)/start-xos $(M)/docker-images # $(M)/push-to-registry
	$(ANSIBLE_PB) $(PI)/deploy-onos-playbook.yml $(LOGCMD)
	touch $@

$(M)/onboard-openstack: | $(M)/deploy-computenode $(M)/glance-images $(M)/deploy-onos $(M)/onboard-profile
	$(SSH_HEAD) "cd /opt/cord/build; $(ANSIBLE_PB_LOCAL) $(PI)/onboard-openstack-playbook.yml" $(LOGCMD)
	touch $@

