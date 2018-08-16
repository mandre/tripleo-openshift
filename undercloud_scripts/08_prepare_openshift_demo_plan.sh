#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

OPENSHIFT_DEMO_STACK_NAME=${OPENSHIFT_DEMO_STACK_NAME:-openshift-dev}
OPENSHIFT_DEMO_STACK_EXTRA_ARGS=${OPENSHIFT_DEMO_STACK_EXTRA_ARGS:-}

set -x

# Get version from openshift-release
OPENSHIFT_VERSION=3.9.0
OPENSHIFT_IMAGE_TAG="v${OPENSHIFT_VERSION}"

# Generate a roles_data with Openshift roles
# FIXME need a t-h-t patch to add these roles
#openstack overcloud roles generate --roles-path $HOME/tripleo-heat-templates/roles -o $HOME/openshift_roles_data.yaml OpenShiftMaster OpenShiftWorker
cat > $HOME/${OPENSHIFT_DEMO_STACK_NAME}_roles_data.yaml << EOF
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

# Create the openshift config
# We use the oooq_* flavors to ensure the correct Ironic nodes are used
# But this currently doesn't enforce predictable placement (which is fine
# until we add more than one of each type of node)
cat > $HOME/${OPENSHIFT_DEMO_STACK_NAME}_env.yaml << EOF
resource_registry:
  OS::TripleO::NodeUserData: $SCRIPTDIR/$TARGET/bootstrap.yaml

parameter_defaults:
  CloudName: ${OPENSHIFT_DEMO_STACK_NAME}.localdomain

  # Master and worker counts in $TARGET/openshift-custom.yaml

  OvercloudOpenShiftMasterFlavor: openshift_master2
  OvercloudOpenShiftWorkerFlavor: openshift_worker2

  DnsServers: [$NAMESERVERS]

  DockerInsecureRegistryAddress: $LOCAL_IP:8787

  # NOTE(flaper87): This should be 3.10
  # eventually
  OpenShiftGlobalVariables:
    openshift_version: '${OPENSHIFT_VERSION}'
    openshift_release: '3.9'
    openshift_image_tag: '${OPENSHIFT_IMAGE_TAG}'
    enable_excluders: false
    openshift_deployment_type: origin
    openshift_docker_selinux_enabled: false
    # NOTE(flaper87): Needed for the gate
    openshift_disable_check: package_availability,package_version,disk_availability,docker_storage,memory_availability,docker_image_availability

    # Allow all auth
    # https://docs.openshift.com/container-platform/3.7/install_config/configuring_authentication.html#overview
    openshift_master_identity_providers:
    - name: allow_all
      login: 'true'
      challenge: true
      kind: AllowAllPasswordIdentityProvider

    # NOTE(flaper87): Disable services we're not using for now.
    openshift_enable_service_catalog: false
    template_service_broker_install: false

    # NOTE(flaper87): This allows us to skip the RPM version checks since there
    # are not RPMs for 3.9. Remove as soon as the 3.9 branches are cut and
    # official rpms are built.
    # We are using the containers and there are tags for 3.9 already
    skip_version: true

    # NOTE(flaper87): Local Registry
    osm_etcd_image: "$LOCAL_IP:8787/latest/etcd"
    etcd_image: "$LOCAL_IP:8787/latest/etcd"

    oreg_url: "$LOCAL_IP:8787/openshift/origin-\${component}:$OPENSHIFT_IMAGE_TAG"
    osm_image: "$LOCAL_IP:8787/openshift/origin"
    osn_image: "$LOCAL_IP:8787/openshift/node"
    osn_ovs_image: "$LOCAL_IP:8787/openshift/openvswitch"
    openshift_examples_modify_imagestreams: true
    openshift_docker_additional_registries: "$LOCAL_IP:8787"

    system_images_registry_dict:
      openshift-enterprise: "$LOCAL_IP:8787"
      origin: "$LOCAL_IP:8787"

    # NOTE(flaper87): We shouldn't need the following configs
    # because we are using t-h-t to install and configure docker
    # Setting them anyway
    openshift_docker_additional_registries: $LOCAL_IP:8787
    insecure_registries:
       - $LOCAL_IP:8787

    docker_options: "--insecure-registry $LOCAL_IP:8787"

    # NOTE(flaper87): This is a d/s only var for now
    # https://github.com/flaper87/openshift-ansible/commit/c6bc3e98316e5aab45015bc6b135ac31494b548d
    openshift_use_external_openvswitch: true

  OpenShiftAnsiblePlaybook: /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml
EOF

# Deploy the openshift stack
# FIXME(mandre) don't we need -e $HOME/tripleo-heat-templates/environments/network-environment.yaml too?
# TODO(mandre) restore --config-download?
pushd $HOME
openstack overcloud deploy \
  --templates $HOME/tripleo-heat-templates \
  --disable-validations \
  --stack ${OPENSHIFT_DEMO_STACK_NAME} \
  -r $HOME/${OPENSHIFT_DEMO_STACK_NAME}_roles_data.yaml \
  -e $HOME/tripleo-heat-templates/environments/openshift.yaml \
  -e $HOME/tripleo-heat-templates/environments/config-download-environment.yaml \
  -e $HOME/tripleo-heat-templates/environments/network-isolation.yaml \
  -e $HOME/tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml \
  -e $HOME/tripleo-heat-templates/environments/networks-disable.yaml \
  -e $HOME/${OPENSHIFT_DEMO_STACK_NAME}_env.yaml \
  -e $SCRIPTDIR/$TARGET/network.yaml \
  -e $SCRIPTDIR/$TARGET/openshift-dev-custom.yaml \
  --update-plan-only \
  ${OPENSHIFT_STACK_EXTRA_ARGS}

popd
