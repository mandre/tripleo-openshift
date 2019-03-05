#!/bin/bash

SCRIPTDIR=$(python -c "import os;print os.path.dirname(os.path.realpath('$0'))")
source $SCRIPTDIR/common.sh

usage () {
  echo "Usage: $(basename $0) [options]"
    echo ""
    echo "Basic options:"
    echo "  --redeploy          clean-up existing stack before deploying again"
    echo "  -h, --help          print this help and exit"
}

REMOVE_OLD_STACK=${REMOVE_OLD_STACK:-}

OPTS=`getopt -o h --long help,redeploy -- "$@"`
eval set -- "$OPTS"

while true; do
  case "$1" in
    -h | --help)
      usage; exit ;;
    --redeploy)
      export REMOVE_OLD_STACK=1; shift ;;
    --) shift ; break ;;
    * ) break ;;
  esac
done

if [[ $REMOVE_OLD_STACK -eq 1 ]]; then
  echo Removing previous deployment stack...
  openstack stack delete -y --wait $OPENSHIFT_STACK_NAME || true
elif openstack stack list | grep -q $OPENSHIFT_STACK_NAME; then
  echo -e "\e[31m[WARNING]\e[0m openshift is already deployed, assuming udate"
  echo Press Ctl-C to cancel
  sleep 10
fi

if [[ $OPENSHIFT_CNS -eq 1 ]]; then
  CNS_ENV="-e $HOME/tripleo-heat-templates/environments/openshift-cns.yaml"
fi

# Deploy the openshift stack
# TODO(mandre) Use -e $HOME/containers-prepare-parameter.yaml
pushd $HOME
openstack overcloud deploy \
  --templates $HOME/tripleo-heat-templates \
  --disable-validations \
  --stack ${OPENSHIFT_STACK_NAME} \
  -r $HOME/openshift_roles_data.yaml \
  -n $HOME/tripleo-heat-templates/network_data_openshift.yaml \
  -e $HOME/tripleo-heat-templates/environments/openshift.yaml \
  ${CNS_ENV} \
  -e $HOME/tripleo-heat-templates/environments/network-isolation.yaml \
  -e $HOME/tripleo-heat-templates/environments/net-single-nic-with-vlans.yaml \
  -e $HOME/openshift_env.yaml \
  -e $HOME/openshift_docker_images.yaml \
  ${OPENSHIFT_STACK_EXTRA_ARGS}

popd
