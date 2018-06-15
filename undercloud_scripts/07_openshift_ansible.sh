#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

set -x

pushd $HOME
  # Extra safety measure to ensure the *latest* config dir is picked up
  rm -rf /home/stack/tripleo-config/${OPENSHIFT_STACK_NAME}
  mkdir -p /home/stack/tripleo-config/${OPENSHIFT_STACK_NAME}
  openstack overcloud config download \
    --name ${OPENSHIFT_STACK_NAME} \
    --config-dir /home/stack/tripleo-config/${OPENSHIFT_STACK_NAME}
  # FIXME we should make config download accept a --download-dir arg vs finding
  # the most recently written tmpdir...
  TMPDIR=$(ls -ltr /home/stack/tripleo-config/${OPENSHIFT_STACK_NAME} | grep "tripleo-.*-config" | awk '{print $9}')
  pushd /home/stack/tripleo-config/${OPENSHIFT_STACK_NAME}/$TMPDIR
    export TRIPLEO_PLAN_NAME=${OPENSHIFT_STACK_NAME}
    export ANSIBLE_HOST_KEY_CHECKING=no
    ansible-playbook -i /usr/bin/tripleo-ansible-inventory deploy_steps_playbook.yaml
  popd
popd
