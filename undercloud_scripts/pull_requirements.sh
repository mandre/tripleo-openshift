#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PATCH_DIR=$SCRIPTDIR/../patches/

source $SCRIPTDIR/common.sh

sudo yum -y install \
  ansible \
  curl \
  telnet \
  vim

# This is needed to run a local checkout of the Tripleo-UI
curl --silent --location https://rpm.nodesource.com/setup_8.x | sudo bash -
sudo yum -y install nodejs

# NOTE(mandre) use centos-release-openshift-origin instead?
sudo yum -y install centos-release-openshift-origin39
sudo yum -y install openshift-ansible-playbooks

# NOTE (alitke): Needed for openshift-metrics install
#sudo yum -y install java-1.8.0-openjdk-headless

set -eu

# these avoid errors for the cherry-picks below
if [ ! -f $HOME/.gitconfig ]; then
  git config --global user.email "theboss@foo.bar"
  git config --global user.name "TheBoss"
fi

if [ ! -d $HOME/tripleo-heat-templates ]; then
  git clone git://git.openstack.org/openstack/tripleo-heat-templates $HOME/tripleo-heat-templates

  # Apply any patches needed
  pushd $HOME/tripleo-heat-templates

  # Add pvremove to the disk clean step
  # https://review.openstack.org/#/c/565182/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/82/565182/4 && git cherry-pick FETCH_HEAD

  popd
fi

# if [ ! -d $HOME/tripleo-common ]; then
#   git clone git://git.openstack.org/openstack/tripleo-common $HOME/tripleo-common

#   # Apply any patches needed
#   pushd $HOME/tripleo-common

#   sudo rm -Rf /usr/lib/python2.7/site-packages/tripleo_common*
#   sudo python setup.py install
#   sudo cp /usr/share/tripleo-common/sudoers /etc/sudoers.d/tripleo-common
#   docker restart mistral_executor
#   docker restart mistral_engine
#   # this loads the actions via entrypoints
#   sudo mistral-db-manage populate

#   mistral cron-trigger-delete publish-ui-logs-hourly
#   for workbook in $(openstack workbook list -f value -c Name | grep tripleo); do
#     openstack workbook delete $workbook
#   done
#   for workflow in $(openstack workflow list -f value -c Name | grep tripleo); do
#     openstack workflow delete $workflow
#   done
#   for workbook in $(ls /usr/share/openstack-tripleo-common/workbooks/*); do
#     openstack workbook create $workbook
#   done
#   # Restore cron trigger with updated publish_ui_logs_to_swift workflow
#   # This ensure we're not affected by https://bugs.launchpad.net/tripleo/+bug/1754061
#   mistral cron-trigger-create --pattern "0 * * * *" publish-ui-logs-hourly tripleo.plan_management.v1.publish_ui_logs_to_swift

#   popd
# fi

# if [ ! -d $HOME/python-tripleoclient ]; then
#   git clone git://git.openstack.org/openstack/python-tripleoclient $HOME/python-tripleoclient

#   # Apply any patches needed
#   pushd $HOME/python-tripleoclient

#   # Our setuptools is too old to understand 'lesser than' requirements
#   # https://docs.openstack.org/pbr/latest/user/compatibility.html#setuptools
#   sed -i "s/;python_version<'3.3'//" requirements.txt

#   sudo python setup.py install
#   popd
# fi

# if [ ! -d $HOME/tripleo-ui ]; then
#   git clone git://git.openstack.org/openstack/tripleo-ui $HOME/tripleo-ui

#   # Apply any patches needed
#   pushd $HOME/tripleo-ui

#   # Mask Passwords and allow Copy to Clipboard
#   # https://review.openstack.org/#/c/562039/
#   git fetch https://git.openstack.org/openstack/tripleo-ui refs/changes/39/562039/8 && git cherry-pick FETCH_HEAD

#   mkdir dist
#   cp /var/www/openstack-tripleo-ui/dist/tripleo_ui_config.js dist

#   $SCRIPTDIR/update-tripleo-ui.sh

#   popd
# fi

# if [ ! -d $HOME/puppet/tripleo ]; then
#   # We need a recent puppet-tripleo for https://review.openstack.org/#/c/579128/
#   git clone git://git.openstack.org/openstack/puppet-tripleo $HOME/puppet/tripleo
#   upload-puppet-modules -d $HOME/puppet/ -c openshift-artifacts
# fi

cat > $HOME/containers-prepare-parameter.yaml <<EOF
parameter_defaults:
  DockerInsecureRegistryAddress:
  - $LOCAL_IP:8787
  ContainerImagePrepare:
  - push_destination: "$LOCAL_IP:8787"
    set:
      tag: "current-tripleo"
      namespace: "docker.io/tripleomaster"
      name_prefix: "centos-binary-"
      name_suffix: ""
EOF

# Dirty hack to ease ssh to overcloud nodes
# Now we can just "ssh overcloud-controller-0"
cat > ~/.ssh/config <<EOF
Host *
User heat-admin
StrictHostkeyChecking no
UserKnownHostsFile /dev/null
EOF
chmod 600 ~/.ssh/config
