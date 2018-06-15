Some convenience wrapper scripts that are copied to the undercloud after quickstart has run.

Set up baremetal racks.  Files/configurations specific to a set of
hardware are in the subdirectories.  The intention is to use this
by setting:

export TARGET=quickstart
./01_install_undercloud.sh
./02_configure_undercloud.sh
./03_prepare_overcloud.sh
./04_deploy_overcloud.sh

Then to deploy openshift:

./05_prepare_openshift.sh
./06_deploy_openshift.sh
./07_openshift_ansible.sh

Finally we can create (but not deploy) another openshift plan, this
is what will be deployed live via the UI in the demo:
./08_prepare_openshift_demo_plan.sh
