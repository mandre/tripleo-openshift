#!/bin/bash -x

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

cat > $HOME/overcloud_env.yaml << EOF
resource_registry:
  OS::TripleO::NodeUserData: $SCRIPTDIR/$TARGET/bootstrap.yaml

parameter_defaults:
  CloudName: openstack.localdomain

  # Compute and controller counts in $TARGET/openstack-custom.yaml
  CephStorageCount: 0
  BlockStorageCount: 0
  ObjectStorageCount: 0

  OvercloudControllerFlavor: control
  OvercloudComputeFlavor: compute

  # We don't enable swift so switch this to file
  GlanceBackend: file

  DnsServers: [$NAMESERVERS]

  DockerInsecureRegistryAddress: $LOCAL_IP:8787
  DockerPuppetProcessCount: 3
EOF

pushd $HOME
openstack overcloud deploy \
    --templates $HOME/tripleo-heat-templates \
    --stack ${OPENSTACK_STACK_NAME} \
    -r $SCRIPTDIR/roles_data_controller_compute.yaml \
    -e $HOME/tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml \
    -e $HOME/tripleo-heat-templates/environments/network-isolation.yaml \
    -e $HOME/overcloud_env.yaml \
    -e $SCRIPTDIR/$TARGET/network.yaml \
    -e $SCRIPTDIR/$TARGET/openstack-custom.yaml \
    -e $HOME/docker-images.yaml \
    -e $HOME/inject-trust-anchor-hiera.yaml

popd
