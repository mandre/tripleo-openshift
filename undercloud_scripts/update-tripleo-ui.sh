#!/bin/bash

if [[ ! -d $HOME/tripleo-ui ]]; then
  echo Missing $HOME/tripleo-ui checkout. Run pull_requirements.sh
  exit
fi

cd $HOME/tripleo-ui
npm install
npm run build
sudo rm -rf /var/www/openstack-tripleo-ui/dist.bak
sudo mv /var/www/openstack-tripleo-ui/dist{,.bak}
sudo cp -r dist/ /var/www/openstack-tripleo-ui/
