#!/bin/bash

if [ $# -ne 2 ]; then
  echo Usage: set_node_profile.sh node profile
  exit
fi

echo openstack baremetal node set $1 --property capabilities="profile:$2,boot_option:local"
