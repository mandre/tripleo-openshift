#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

sudo setenforce 0
sudo sed -i "s/^SELINUX=enforcing/SELINUX=permissive/" /etc/selinux/config

# Workaround issue with repos in overcloud-full image
sudo yum install -y libguestfs-tools
virt-customize --selinux-relabel -a $HOME/overcloud-full.qcow2 --install yum-plugin-priorities
virt-customize --selinux-relabel -a $HOME/overcloud-full.qcow2 --upload $SCRIPTDIR/quickstart-centos-virt-container.repo:/etc/yum.repos.d/
openstack overcloud image upload --update-existing
