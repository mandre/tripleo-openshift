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
NAMESERVERS="192.168.23.1"

declare -A NODES=(
[openshift-dev-master-0]=openshift_master2
[openshift-dev-worker-0]=openshift_infra
[openshift-dev-worker-1]=openshift_infra
[openshift-master-0]=openshift_master
[openshift-worker-0]=openshift_worker
[openshift-worker-1]=openshift_worker
[openstack-compute-0]=compute
[openstack-controller-0]=control
)
