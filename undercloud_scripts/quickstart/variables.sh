#!/bin/bash

NETWORK_GATEWAY=192.168.24.1
NETWORK_CIDR=192.168.24.0/24
DHCP_START=192.168.24.5
DHCP_END=192.168.24.30
INSPECTION_IP_RANGE=192.168.24.100,192.168.24.120
LOCAL_IP=192.168.24.1
UNDERCLOUD_PUBLIC_HOST=192.168.24.2
UNDERCLOUD_PUBLIC_IP=192.168.24.2
UNDERCLOUD_ADMIN_HOST=192.168.24.3
LOCAL_INTERFACE=eth1

# FIXME - create a mirror VM in quickstart
MIRROR_IP=172.31.9.99

declare -A NODES=(
[openshift-dev-master-0]=openshift_master
[openshift-dev-worker-0]=openshift_master
[openshift-dev-worker-1]=openshift_master
[openshift-master-0]=openshift_master
[openshift-worker-0]=openshift_worker
[openshift-worker-1]=openshift_worker
[openstack-compute-0]=compute
[openstack-controller-0]=control
)
