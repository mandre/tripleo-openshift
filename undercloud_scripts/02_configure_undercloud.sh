#!/bin/bash

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

# This updates us to the latest UI as well as various other patches
# needed to make all this work.
source $SCRIPTDIR/pull_requirements.sh

# Delete default overcloud plan
openstack overcloud plan delete overcloud
