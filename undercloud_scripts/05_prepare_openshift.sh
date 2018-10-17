#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

set -x

# Generate a roles_data with Openshift roles
# openstack overcloud roles generate --roles-path $HOME/tripleo-heat-templates/roles -o $HOME/openshift_roles_data.yaml OpenShiftAllInOne
openstack overcloud roles generate --roles-path $HOME/tripleo-heat-templates/roles -o $HOME/openshift_roles_data.yaml OpenShiftMaster OpenShiftWorker OpenShiftInfra

# Patch mistral_executor image
if [ ! -d $HOME/mistral_executor_patch ]; then
  if [ ! -d $HOME/tripleo-common ]; then
    git clone https://github.com/openstack/tripleo-common.git
  fi
  mkdir -p $HOME/mistral_executor_patch
  cp $HOME/tripleo-common/sudoers $HOME/mistral_executor_patch/
  cp $HOME/tripleo-common/scripts/tripleo-deploy-openshift $HOME/mistral_executor_patch/
  cat > $HOME/mistral_executor_patch/Dockerfile << EOF
FROM 192.168.24.1:8787/tripleomaster/centos-binary-mistral-executor:current-tripleo

USER root
COPY sudoers /etc/sudoers.d/tripleo-common
COPY tripleo-deploy-openshift /usr/bin/tripleo-deploy-openshift
USER mistral
EOF
  docker build $HOME/mistral_executor_patch -t 192.168.24.1:8787/tripleomaster/centos-binary-mistral-executor:tripleo-openshift
  sudo sed -i 's/mistral-executor:current-tripleo/mistral-executor:tripleo-openshift/' /var/lib/tripleo-config/docker-container-startup-config-step_4.json
  docker stop mistral_executor
  docker rm mistral_executor
  sudo paunch --debug apply --file /var/lib/tripleo-config/docker-container-startup-config-step_4.json --config-id tripleo_step4 --managed-by tripleo-Undercloud
fi

cat > $HOME/network_data.yaml << EOF
- name: Storage
  vip: true
  vlan: 30
  name_lower: storage
  ip_subnet: '172.17.3.0/24'
  allocation_pools: [{'start': '172.17.3.10', 'end': '172.17.3.149'}]

- name: InternalApi
  name_lower: internal_api
  vip: true
  vlan: 20
  ip_subnet: '172.17.1.0/24'
  allocation_pools: [{'start': '172.17.1.10', 'end': '172.17.1.149'}]

- name: External
  vip: true
  name_lower: external
  vlan: 10
  ip_subnet: '10.0.0.0/24'
  allocation_pools: [{'start': '10.0.0.101', 'end': '10.0.0.149'}]
  gateway_ip: '10.0.0.1'
EOF

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
  OvercloudOpenShiftInfraFlavor: openshift_infra

  DnsServers: [$NAMESERVERS]

  DockerInsecureRegistryAddress: $LOCAL_IP:8787

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

openstack overcloud container image prepare \
  --push-destination $LOCAL_IP:8787 \
  --output-env-file $HOME/openshift_docker_images.yaml \
  --output-images-file $HOME/openshift_containers.yaml \
  -e $HOME/tripleo-heat-templates/environments/docker.yaml \
  -e $HOME/tripleo-heat-templates/environments/openshift.yaml \
  -e $HOME/tripleo-heat-templates/environments/openshift-cns.yaml \
  -e $HOME/openshift_env.yaml \
  -e $SCRIPTDIR/$TARGET/openshift-custom.yaml \
  -r $HOME/openshift_roles_data.yaml
openstack overcloud container image upload --config-file $HOME/openshift_containers.yaml
