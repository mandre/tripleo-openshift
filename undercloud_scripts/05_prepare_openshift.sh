#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

set -x

# Generate a roles_data with Openshift roles
# openstack overcloud roles generate --roles-path $HOME/tripleo-heat-templates/roles -o $HOME/openshift_roles_data.yaml OpenShiftAllInOne
openstack overcloud roles generate --roles-path $HOME/tripleo-heat-templates/roles -o $HOME/openshift_roles_data.yaml OpenShiftMaster OpenShiftWorker OpenShiftInfra

# Create the openshift config
# We use the oooq_* flavors to ensure the correct Ironic nodes are used
# But this currently doesn't enforce predictable placement (which is fine
# until we add more than one of each type of node)
cat > $HOME/openshift_env.yaml << EOF
# resource_registry:

parameter_defaults:
  CloudName: openshift.localdomain

  OpenShiftMasterCount: 1
  OpenShiftWorkerCount: 3
  OpenShiftInfraCount: 3
  # OpenShiftAllInOneCount: 1
  OpenShiftGlusterDisks:
    - /dev/vdb

  OvercloudOpenShiftMasterFlavor: oooq_openshift_master
  OvercloudOpenShiftWorkerFlavor: oooq_openshift_worker
  OvercloudOpenShiftInfraFlavor: oooq_openshift_infra
  OvercloudOpenShiftAllInOneFlavor: oooq_openshift_infra

  DnsServers: ["192.168.23.1"]

  DockerInsecureRegistryAddress: 192.168.24.1:8787

  OpenShiftGlobalVariables:

    # Allow all auth
    # https://docs.openshift.com/container-platform/3.7/install_config/configuring_authentication.html#overview
    openshift_master_identity_providers:
    - name: allow_all
      login: 'true'
      challenge: true
      kind: AllowAllPasswordIdentityProvider

    openshift_disable_check: memory_availability
EOF

openstack overcloud container image prepare \
  --push-destination 192.168.24.1:8787 \
  --output-env-file $HOME/openshift_docker_images.yaml \
  --output-images-file $HOME/openshift_containers.yaml \
  -e $HOME/tripleo-heat-templates/environments/docker.yaml \
  -e $HOME/tripleo-heat-templates/environments/openshift.yaml \
  -e $HOME/tripleo-heat-templates/environments/openshift-cns.yaml \
  -e $HOME/openshift_env.yaml \
  -r $HOME/openshift_roles_data.yaml
openstack overcloud container image upload --config-file $HOME/openshift_containers.yaml
