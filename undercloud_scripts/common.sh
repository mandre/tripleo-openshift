#!/bin/bash

USER=`whoami`
if [ "$USER" != "stack" ]; then
    echo "Wrong user is used. Please login as stack"
    exit 1
fi

if [ -f $HOME/tripleo-openshift-env ]; then
  source $HOME/tripleo-openshift-env
fi

OPENSHIFT_AIO=${OPENSHIFT_AIO:-}
OPENSHIFT_CNS=${OPENSHIFT_CNS:-}
OPENSHIFT_DOWNSTREAM=${OPENSHIFT_DOWNSTREAM:-}
OPENSHIFT_STACK_NAME=${OPENSHIFT_STACK_NAME:-openshift}
OPENSHIFT_STACK_EXTRA_ARGS=${OPENSHIFT_STACK_EXTRA_ARGS:-}

if [ -f $HOME/stackrc ]; then
  source $HOME/stackrc
fi
