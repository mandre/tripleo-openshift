#!/bin/bash

usage () {
    echo "Usage: $0 [options]"
    echo ""
    echo "Basic options:"
    echo "  --skip-undercloud   skip undercloud install"
    echo "  --skip-openstack    skip openstack install"
    echo "  --no-cleanup        keep local requirements"
    echo "  -h, --help          print this help and exit"
}

OPTS=`getopt -o h --long help,skip-undercloud,skip-openstack,no-cleanup -- "$@"`
eval set -- "$OPTS"

while true; do
  case "$1" in
    -h | --help)
      usage; exit ;;
    --skip-undercloud)
      SKIP_UNDERCLOUD=1; shift ;;
    --skip-openstack)
      SKIP_OPENSTACK=1; shift ;;
    --no-cleanup)
      SKIP_CLEANUP=1; shift ;;
    --) shift ; break ;;
    * ) break ;;
  esac
done

SKIP_UNDERCLOUD=${SKIP_UNDERCLOUD:-}
SKIP_OPENSTACK=${SKIP_OPENSTACK:-}
SKIP_CLEANUP=${SKIP_CLEANUP:-}

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $HOME/stackrc

openstack stack delete -y --wait openshift

if [ ! $SKIP_OPENSTACK ]; then
  openstack stack delete -y --wait openstack
fi

set -eu

if [ ! $SKIP_CLEANUP ]; then
  $SCRIPTDIR/cleanup_all.sh -y
fi

if [ ! $SKIP_UNDERCLOUD ]; then
  $SCRIPTDIR/01_install_undercloud.sh
fi

# This pulls the latest requirements if needed
$SCRIPTDIR/02_configure_undercloud.sh

if [ ! $SKIP_OPENSTACK ]; then
  $SCRIPTDIR/03_prepare_overcloud.sh
  $SCRIPTDIR/04_deploy_overcloud.sh
fi

$SCRIPTDIR/05_prepare_openshift.sh
$SCRIPTDIR/06_deploy_openshift.sh
# $SCRIPTDIR/07_openshift_ansible.sh
