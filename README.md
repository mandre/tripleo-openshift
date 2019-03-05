# tripleo-openshift

Configs/scripts for setting up an environment to deploy OpenShift with TripleO
with tripleo-quickstart.

./qs_doit.sh 

Now we SSH to the undercloud to run the openshift deployment::

  ssh -F $HOME/.quickstart-shiftstack/ssh.config.ansible undercloud

Adjust the `$HOME/tripleo-openshift-env` file to match the desired deployment. The options are:

* OPENSHIFT\_AIO: set it to `1` to deploy openshift on an all-in-one node.
* OPENSHIFT\_CNS: set it to `1` to deploy openshift with glusterfs. This needs
  at least 3 worker nodes and 3 infra nodes.
* OPENSHIFT\_DOWNSTREAM: set it to `1` to deploy OCP instead of origin.

Finally run `prepare_deployment.sh` to generate the configuration files and
`deploy_openshift.sh` to deploy openshift.
