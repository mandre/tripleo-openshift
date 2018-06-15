#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

USER=`whoami`
if [ "$USER" != "stack" ]; then
    echo "Wrong user is used. Please login as stack"
    exit 1
fi

if [ -z "$TARGET" ]; then
    echo "SET TARGET!"
    exit 1
fi
source $SCRIPTDIR/$TARGET/variables.sh

OPENSTACK_STACK_NAME=${OPENSTACK_STACK_NAME:-openstack}
OPENSHIFT_STACK_NAME=${OPENSHIFT_STACK_NAME:-openshift}
OPENSHIFT_STACK_EXTRA_ARGS=${OPENSHIFT_STACK_EXTRA_ARGS:-}

if [ -f $HOME/stackrc ]; then
  source $HOME/stackrc
fi
