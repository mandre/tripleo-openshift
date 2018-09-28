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
sudo yum -y install centos-release-openshift-origin310
# FIXME pin to 3.10.41 since version 3.10.43 breaks deployment
sudo yum -y install openshift-ansible-playbooks-3.10.41

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

  # Clean up previous osa inventory dir before deployment
  # https://review.openstack.org/#/c/600028/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/28/600028/14 && git cherry-pick FETCH_HEAD

  # Configure haproxy for openshift infra
  # https://review.openstack.org/#/c/601241/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/41/601241/16 && git cherry-pick FETCH_HEAD

  # Fix inventory files for newer openshift-ansible
  # https://review.openstack.org/#/c/603577/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/77/603577/5 && git cherry-pick FETCH_HEAD

  # Introduce OpenShiftGlusterNodeVars heat param
  # https://review.openstack.org/#/c/604724/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/24/604724/3 && git cherry-pick FETCH_HEAD

  # Make glusterfs the default sc when deploying with CNS
  # https://review.openstack.org/#/c/604725/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/25/604725/3 && git cherry-pick FETCH_HEAD

  # Consolidate openshift-ansible global variables
  # https://review.openstack.org/#/c/604726/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/26/604726/3 && git cherry-pick FETCH_HEAD

  # Add heat param for openshift prerequisites playbook
  # https://review.openstack.org/#/c/604338/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/38/604338/4 && git cherry-pick FETCH_HEAD

  # Do not wipe disks on OpenShift gluster nodes
  # https://review.openstack.org/#/c/605127/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/27/605127/2 && git cherry-pick FETCH_HEAD

  # Remove unused networks from OpenShift roles
  # https://review.openstack.org/#/c/604727/
  # git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/27/604727/3 && git cherry-pick FETCH_HEAD

  # Use openshift-ansible container instead of RPMs
  # https://review.openstack.org/#/c/583868/
  # git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/68/583868/18 && git cherry-pick FETCH_HEAD

  # Use glusterfs for registry when deploying with CNS
  # https://review.openstack.org/#/c/605825/
  git fetch https://git.openstack.org/openstack/tripleo-heat-templates refs/changes/25/605825/3 && git cherry-pick FETCH_HEAD

  popd
fi

if [ ! -d $HOME/tripleo-common ]; then
  git clone git://git.openstack.org/openstack/tripleo-common $HOME/tripleo-common

  # Apply any patches needed
  pushd $HOME/tripleo-common

  sudo rm -Rf /usr/lib/python2.7/site-packages/tripleo_common*
  sudo python setup.py install
  # sudo cp /usr/share/tripleo-common/sudoers /etc/sudoers.d/tripleo-common
  # docker restart mistral_executor
  # docker restart mistral_engine
  # # this loads the actions via entrypoints
  # sudo mistral-db-manage populate

  # mistral cron-trigger-delete publish-ui-logs-hourly
  # for workbook in $(openstack workbook list -f value -c Name | grep tripleo); do
  #   openstack workbook delete $workbook
  # done
  # for workflow in $(openstack workflow list -f value -c Name | grep tripleo); do
  #   openstack workflow delete $workflow
  # done
  # for workbook in $(ls /usr/share/openstack-tripleo-common/workbooks/*); do
  #   openstack workbook create $workbook
  # done
  # # Restore cron trigger with updated publish_ui_logs_to_swift workflow
  # # This ensure we're not affected by https://bugs.launchpad.net/tripleo/+bug/1754061
  # mistral cron-trigger-create --pattern "0 * * * *" publish-ui-logs-hourly tripleo.plan_management.v1.publish_ui_logs_to_swift

  popd
fi

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

if [ ! -d $HOME/puppet/tripleo ]; then
  git clone git://git.openstack.org/openstack/puppet-tripleo $HOME/puppet/tripleo

  # Apply any patches needed
  pushd $HOME/puppet/tripleo

  upload-puppet-modules -d $HOME/puppet/ -c openshift-artifacts

  popd
fi

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
