# quickstart-config

Configs/scripts for setting up an environment to deploy OpenShift with TripleO
with tripleo-quickstart.

./qs_doit.sh 

This will run quickstart and should end like this:

##################################
Virtual Environment Setup Complete
##################################

Access the undercloud by:

    ssh -F /home/shardy/.quickstart/ssh.config.ansible undercloud

Follow the documentation in the link below to complete your deployment.

    http://ow.ly/c44w304begR

##################################
Virtual Environment Setup Complete
##################################



Now we SSH to the undercloud to run the openstack/openshift deployment::

  ssh -F /home/shardy/.quickstart-shiftstack/ssh.config.ansible undercloud
  . stackrc
  cd quickstart-config/openshift_openstack/undercloud_scripts/

And run the different scripts in order.
