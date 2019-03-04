#!/bin/bash

QUICKSTART_CHECKOUT_DIR=$HOME/tripleo-quickstart
QUICKSTART_WORKING_DIR=$HOME/.quickstart-shiftstack

usage () {
    echo "Usage: $0 [options] <virthost>"
    echo ""
    echo "  virthost            a physical machine hosting the libvirt VMs of the TripleO"
    echo "                      deployment, required argument"
    echo ""
    echo "Basic options:"
    echo "  -m, --mirror <url>  use local centos mirror to save time/bandwidth"
    echo "  --no-check-deps     do not check for and install missing dependencies"
    echo "  -v, --verbose       invoke ansible-playbook with --ansible-debug"
    echo "  -h, --help          print this help and exit"
}

OPTS=`getopt -o hvm: --long help,verbose,mirror:,no-check-deps -- "$@"`
eval set -- "$OPTS"

while true; do
  case "$1" in
    -h | --help)
      usage; exit ;;
    -v | --verbose)
      export ANSIBLE_DEBUG=1; shift ;;
    -m | --mirror)
      shift
      export NODEPOOL_CENTOS_MIRROR=$1; shift ;;
    --no-check-deps)
      SKIP_DEPS_CHECK=1; shift ;;
    --) shift ; break ;;
    * ) break ;;
  esac
done

TARGET_HOST=$1
if [ "x$TARGET_HOST" = "x" ]; then
  TARGET_HOST=$(hostname)
fi

if [ ! -d $QUICKSTART_CHECKOUT_DIR ]; then
  git clone git://git.openstack.org/openstack/tripleo-quickstart $QUICKSTART_CHECKOUT_DIR
else
  pushd $QUICKSTART_CHECKOUT_DIR
  git checkout quickstart-extras-requirements.txt
  git checkout master
  git pull
  popd
fi

# these avoid errors for the cherry-picks below
if [ ! -f $HOME/.gitconfig ]; then
  git config --global user.email "theboss@foo.bar"
  git config --global user.name "TheBoss"
fi

QUICKSTART_CONFIG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIGDIR="$QUICKSTART_CONFIG_DIR/quickstart"

if [ ! $SKIP_DEPS_CHECK ]; then
  $QUICKSTART_CHECKOUT_DIR/quickstart.sh --install-deps
fi

QUICKSTART_CMD="$QUICKSTART_CHECKOUT_DIR/quickstart.sh \
  -w $QUICKSTART_WORKING_DIR \
  --teardown all \
  --release master-tripleo-ci \
  --extra-vars @$CONFIGDIR/config.yml \
  --nodes $CONFIGDIR/nodes.yml \
  --environment $QUICKSTART_WORKING_DIR/config/environments/dev_privileged_libvirt.yml \
  --no-clone \
  --clean \
  ${EXTRA_ARGS} \
  $TARGET_HOST"

echo $QUICKSTART_CMD
$QUICKSTART_CMD

if [ $? -eq 0 ]; then
  echo "Quickstart run completed, copying scripts"
  scp -r -F $QUICKSTART_WORKING_DIR/ssh.config.ansible $QUICKSTART_CONFIG_DIR stack@undercloud:/home/stack/
  echo "Preparing host"
  ssh -F $QUICKSTART_WORKING_DIR/ssh.config.ansible undercloud "echo -e 'export OPENSHIFT_AIO=0\nexport OPENSHIFT_CNS=0' > tripleo-openshift-env"
  ssh -F $QUICKSTART_WORKING_DIR/ssh.config.ansible undercloud "echo 'source tripleo-openshift-env' >> .bashrc"
  ssh -F $QUICKSTART_WORKING_DIR/ssh.config.ansible undercloud "/home/stack/tripleo-openshift/undercloud_scripts/prepare_host.sh"
else
  echo "Error quickstart run failed :("
  exit 1
fi

echo "---"
echo "Now we SSH to the undercloud to run the openshift deployment:"
echo "ssh -F $QUICKSTART_WORKING_DIR/ssh.config.ansible undercloud"
echo "  . stackrc"
echo "  cd tripleo-openshift/undercloud_scripts/"
echo "  And run the different scripts in order."
