#!/bin/bash

# Should put this in an Ansible role
parted /dev/vda mklabel msdos
parted /dev/vda mkpart primary 1 100%
mkfs.ext4 /dev/vda1
grep vda /etc/fstab || echo "/dev/vda1 /mnt ext4 rw 0 0" >> /etc/fstab
mount /mnt
mkdir -p /mnt/lxd
ln -s /mnt/lxd /var/lib

