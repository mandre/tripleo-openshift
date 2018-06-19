#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

set -x

# Generate a roles_data with Openshift roles
# FIXME need a t-h-t patch to add these roles
#openstack overcloud roles generate --roles-path $HOME/tripleo-heat-templates/roles -o $HOME/openshift_roles_data.yaml OpenShiftMaster OpenShiftWorker
cat > $HOME/openshift_roles_data.yaml << EOF
- name: OpenShiftMaster
  description: OpenShift master node
  CountDefault: 1
  disable_upgrade_deployment: True
  tags:
    - primary
    - controller
  networks:
    - External
    - InternalApi
    - Storage
    - StorageMgmt
    - Tenant
  ServicesDefault:
    - OS::TripleO::Services::Docker
    - OS::TripleO::Services::OpenShift::Master
    - OS::TripleO::Services::OpenShift::Worker
    - OS::TripleO::Services::Sshd
    - OS::TripleO::Services::Ntp

- name: OpenShiftWorker
  description: OpenShift worker node
  disable_upgrade_deployment: True
  CountDefault: 2
  networks:
    - InternalApi
    - Storage
    - StorageMgmt
    - Tenant
  ServicesDefault:
    - OS::TripleO::Services::Docker
    - OS::TripleO::Services::OpenShift::Worker
    - OS::TripleO::Services::Sshd
    - OS::TripleO::Services::Ntp
EOF

# Get nameservers from the undercloud
if [ -z "$NAMESERVERS" ]; then
  NAMESERVERS=
  for n in $(awk 'match($0, /nameserver\s+(([0-9]{1,3}.?){4})/,address){print address[1]}' /etc/resolv.conf); do
    if [ -z "$NAMESERVERS" ]; then
      NAMESERVERS="\"$n\""
    else
      NAMESERVERS="$NAMESERVERS, \"$n\""
    fi
  done
fi

# Create the openshift config
# We use the oooq_* flavors to ensure the correct Ironic nodes are used
# But this currently doesn't enforce predictable placement (which is fine
# until we add more than one of each type of node)
cat > $HOME/openshift_env.yaml << EOF
resource_registry:
  OS::TripleO::NodeUserData: $SCRIPTDIR/$TARGET/bootstrap.yaml

parameter_defaults:
  CloudName: openshift.localdomain

  # Master and worker counts in $TARGET/openshift-custom.yaml

  OvercloudOpenShiftMasterFlavor: openshift_master
  OvercloudOpenShiftWorkerFlavor: openshift_worker

  DnsServers: [$NAMESERVERS]

  DockerInsecureRegistryAddress: $LOCAL_IP:8787

  OpenShiftAnsiblePlaybook: /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml

  # NOTE(flaper87): This should be 3.10
  # eventually
  OpenShiftGlobalVariables:

    # Allow all auth
    # https://docs.openshift.com/container-platform/3.7/install_config/configuring_authentication.html#overview
    openshift_master_identity_providers:
    - name: allow_all
      login: 'true'
      challenge: true
      kind: AllowAllPasswordIdentityProvider

    # NOTE(flaper87): Needed for the gate
    openshift_disable_check: package_availability,package_version,disk_availability,docker_storage,memory_availability,docker_image_availability
EOF

# Prepare container images
openstack overcloud container image prepare \
  --push-destination $LOCAL_IP:8787 \
  --output-env-file $HOME/openshift_docker_images.yaml \
  --output-images-file $HOME/openshift_containers.yaml \
  -e $HOME/tripleo-heat-templates/environments/openshift.yaml \
  -e $HOME/openshift_env.yaml \
  -e $SCRIPTDIR/$TARGET/openshift-custom.yaml \
  -r $HOME/openshift_roles_data.yaml

openstack overcloud container image upload --config-file $HOME/openshift_containers.yaml
