#!/usr/bin/env bash
#
# Milestone tests
# Does a dry run of `make` targets for a scenario, compares the milestones
# created to a known good list, to avoid breaking dependencies across scenarios

# Copyright 2017-present Open Networking Foundation


# Check that `README.md` is the only file in /milestones
M="../milestones"

if `ls $M` != "README.md" then
do 
  echo "You have an unclean milestones directory - make clean-all ?"
  exit 1
done

# Set the commands in the Makefile to "echo" so they do nothing

export SHELL="echo"
export VAGRANT="echo"
export ANSIBLE="echo"
export ANSIBLE_PB="echo"
export ANSIBLE_PB_LOCAL="echo"
export ANSIBLE_PB_MAAS="echo"
export IMAGEBUILDER="echo"
export SSH_HEAD="echo"
export SSH_BUILD="echo"
export LOGCMD=""

# Run make targets

make 

# Compare output with saved copies



# Clean up 


