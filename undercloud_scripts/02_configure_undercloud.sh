#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

# This updates us to the latest UI as well as various other patches
# needed to make all this work.
source $SCRIPTDIR/pull_requirements.sh

# Delete default overcloud plan
openstack overcloud plan delete overcloud

# Update the validations to match environment
# TODO have a way to know if a validation applies to the overcloud or other
# deployment options
VALIDATIONS_DIR=/usr/share/openstack-tripleo-validations/validations
NON_RELEVANT_VALIDATIONS="
ceilometerdb-size.yaml
controller-ulimits.yaml
ceph-ansible-installed.yaml
ceph-health.yaml
switch-vlans.yaml
undercloud-debug.yaml
deployment-images.yaml
mysql-open-files-limit.yaml
neutron-sanity-check.yaml
pacemaker-status.yaml
rabbitmq-limits.yaml
haproxy.yaml
stonith-exists.yaml
no-op-firewall-nova-driver.yaml
openstack-endpoints.yaml
ntpstat.yaml
controller-token.yaml
repos.yaml
"

for validation in $NON_RELEVANT_VALIDATIONS; do
  if [ -f $VALIDATIONS_DIR/$validation ]; then
    sudo mv $VALIDATIONS_DIR/$validation{,.bak}
  fi
done

# Lower requirements
sudo sed -i 's/min_undercloud_cpu_count: 8/min_undercloud_cpu_count: 6/' $VALIDATIONS_DIR/undercloud-cpu.yaml
sudo sed -i 's/min_undercloud_disk_gb: 60/min_undercloud_disk_gb: 10/' $VALIDATIONS_DIR/undercloud-disk-space.yaml
sudo sed -i 's/min_undercloud_ram_gb: 16/min_undercloud_ram_gb: 12/' $VALIDATIONS_DIR/undercloud-ram.yaml
sudo sed -i 's/ctlplane_iprange_min_size: 25/ctlplane_iprange_min_size: 20/' $VALIDATIONS_DIR/ctlplane-ip-range.yaml
sudo sed -i 's/max_process_count: 8/max_process_count: 16/' $VALIDATIONS_DIR/undercloud-process-count.yaml

# Hide a warning in validate_node_pool_size
sudo sed -i '535s/try/#try/' $VALIDATIONS_DIR/library/network_environment.py
sudo sed -i '536s/    warnings/#    warnings/' $VALIDATIONS_DIR/library/network_environment.py
sudo sed -i '537s/                                       template_files/#                                       template_files/' $VALIDATIONS_DIR/library/network_environment.py
sudo sed -i '538s/except/#except/' $VALIDATIONS_DIR/library/network_environment.py
sudo sed -i '539s/    errors/#    errors/' $VALIDATIONS_DIR/library/network_environment.py
