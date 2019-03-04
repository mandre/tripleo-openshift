#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd $HOME

sudo yum -y install \
  ansible \
  curl \
  telnet \
  vim

# This is needed to run a local checkout of the Tripleo-UI
# curl --silent --location https://rpm.nodesource.com/setup_8.x | sudo bash -
# sudo yum -y install nodejs

# Dirty hack to ease ssh to overcloud nodes
# Now we can just "ssh overcloud-controller-0"
cat > $HOME/.ssh/config <<EOF
Host *
User heat-admin
StrictHostkeyChecking no
UserKnownHostsFile /dev/null
EOF
chmod 600 $HOME/.ssh/config

mkdir -p $HOME/.local/bin
find $SCRIPTDIR -maxdepth 1 -type f -perm +a=x -print0 | xargs -0 -I {} mv {} $HOME/.local/bin

if [ -x $SCRIPTDIR/prepare_host_custom.sh ]; then
  $SCRIPTDIR/prepare_host_custom.sh
fi

# these avoid errors for the cherry-picks patches
if [ ! -f $HOME/.gitconfig ]; then
  git config --global user.email "theboss@foo.bar"
  git config --global user.name "TheBoss"
fi
