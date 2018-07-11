#!/bin/bash

if [[ $1 == '-y' ]]; then
  REPLY=y
else
  read -p "This script cleans up all your local repositories. Are you sure? " -n 1 -r
  echo
fi

if [[ $REPLY =~ ^[Yy]$ ]]; then
  set -eux
  cd
  sudo rm -rf $HOME/tripleo-heat-templates \
    $HOME/tripleo-common \
    $HOME/tripleo-ui \
    $HOME/puppet/tripleo \
    $HOME/python-tripleoclient \
    /usr/share/openshift-ansible \
    $HOME/*_roles_data.yaml \
    $HOME/*_env.yaml
fi
