#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

# Deploy the openshift stack
# Add -e $HOME/tripleo-heat-templates/environments/openshift-cns.yaml to deploy with CNS
pushd $HOME
openstack overcloud deploy \
  --templates $HOME/tripleo-heat-templates \
  --disable-validations \
  --stack ${OPENSHIFT_STACK_NAME} \
  -r $HOME/openshift_roles_data.yaml \
  -e $HOME/tripleo-heat-templates/environments/openshift.yaml \
  -e $HOME/tripleo-heat-templates/environments/openshift-cns.yaml \
  -e $HOME/tripleo-heat-templates/environments/config-download-environment.yaml \
  -e $HOME/tripleo-heat-templates/environments/network-isolation.yaml \
  -e $HOME/tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml \
  -e $HOME/tripleo-heat-templates/environments/networks-disable.yaml \
  -e $HOME/openshift_env.yaml \
  -e $HOME/containers-prepare-parameter.yaml \
  -e $SCRIPTDIR/$TARGET/network.yaml \
  -e $SCRIPTDIR/$TARGET/openshift-custom.yaml \
  ${OPENSHIFT_STACK_EXTRA_ARGS}

popd

