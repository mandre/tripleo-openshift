#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

set -x

# Get version from openshift-release
OPENSHIFT_VERSION=3.9.0
OPENSHIFT_IMAGE_TAG="v${OPENSHIFT_VERSION}"

CONTAINER_IMAGES="
docker.io/cockpit/kubernetes:latest
docker.io/openshift/node:${OPENSHIFT_IMAGE_TAG}
docker.io/openshift/origin-deployer:${OPENSHIFT_IMAGE_TAG}
docker.io/openshift/origin-docker-registry:${OPENSHIFT_IMAGE_TAG}
docker.io/openshift/origin-haproxy-router:${OPENSHIFT_IMAGE_TAG}
docker.io/openshift/origin-pod:${OPENSHIFT_IMAGE_TAG}
docker.io/openshift/origin-web-console:${OPENSHIFT_IMAGE_TAG}
docker.io/openshift/origin:${OPENSHIFT_IMAGE_TAG}
registry.fedoraproject.org/latest/etcd:latest
"

for image in $CONTAINER_IMAGES; do
  if [ -z ${SKIP_PULL+x} ];
  then
      docker pull ${image}
  fi
  local_image="$LOCAL_IP:8787/${image#*\/}"
  docker tag ${image} ${local_image}
  docker push ${local_image}
done

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
