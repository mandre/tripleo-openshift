#!/bin/bash -x

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source $SCRIPTDIR/common.sh

echo -e "parameter_defaults:\n  CAMap:"|tee /home/stack/inject-trust-anchor-hiera.yaml
UC_SSL_CERT=`sed ':a;N;$!ba;s/\n/\n        /g' /etc/pki/ca-trust/source/anchors/cm-local-ca.pem`
echo -n -e "    undercloud-ca:\n      content: |\n        "|tee -a /home/stack/inject-trust-anchor-hiera.yaml
echo "$UC_SSL_CERT"|tee -a /home/stack/inject-trust-anchor-hiera.yaml
