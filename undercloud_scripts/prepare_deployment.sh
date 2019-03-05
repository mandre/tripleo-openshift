#!/bin/bash

SCRIPTDIR=$(python -c "import os;print os.path.dirname(os.path.realpath('$0'))")
source $SCRIPTDIR/common.sh

echo "Preparing openshift environment with:
OPENSHIFT_AIO=${OPENSHIFT_AIO:-}
OPENSHIFT_CNS=${OPENSHIFT_CNS:-}
OPENSHIFT_DOWNSTREAM=${OPENSHIFT_DOWNSTREAM:-}
"

pull_requirements.sh

if [[ $OPENSHIFT_DOWNSTREAM -eq 1 ]]; then
cat > $HOME/containers-prepare-parameter.yaml <<EOF
parameter_defaults:
  ContainerImagePrepare:
    # Image label which allows the versioned tag to be looked up from the <tag>
    # image.
  - tag_from_label: "{version}-{release}"
    # Do not re-tag images for openshift, BZ#1659183
    excludes:
    - openshift
    # Uncomment to serve images from the undercloud registry. Images will be
    # copied to the undercloud registry during preparation.
    # To copy/serve from a different local registry, set the value to
    # <address>:<port> of the registry service.
    # push_destination: true

    # Substitutions to be made when processing the template file
    # <prefix>/share/tripleo-common/container-images/overcloud_containers.yaml.j2
    set:
      # Container image name components for OpenStack images.
      namespace: registry.access.redhat.com/rhosp14
      name_prefix: openstack-
      name_suffix: ''
      tag: latest

      # Substitute neutron images based on driver. Can be <null>, 'ovn' or
      # 'odl'. This is usually set automatically by detecting if odl or ovn
      # services are deployed.
      neutron_driver: null

      # Container image name components for Ceph images.
      # Only used if Ceph is deployed.
      ceph_namespace: registry.access.redhat.com/rhceph
      ceph_image: rhceph-3-rhel7
      ceph_tag: latest

      # Container image name components for OpenShift images.
      # Only used if OpenShift is deployed.
      openshift_etcd_namespace: registry.access.redhat.com/rhel7
      openshift_etcd_image: etcd
      openshift_etcd_tag: latest
      openshift_gluster_namespace: registry.access.redhat.com/rhgs3
      openshift_gluster_image: rhgs-server-rhel7
      openshift_gluster_block_image: rhgs-gluster-block-prov-rhel7
      openshift_gluster_tag: v3.11
      openshift_heketi_namespace: registry.access.redhat.com/rhgs3
      openshift_heketi_image: rhgs-volmanager-rhel7
      openshift_heketi_tag: v3.11
      # Namespace must be set to skip openshift images re-tagging
      openshift_namespace: registry.access.redhat.com/openshift3
      openshift_cockpit_namespace: registry.access.redhat.com/openshift3
      openshift_asb_namespace: registry.access.redhat.com/openshift3
      openshift_cluster_monitoring_namespace: registry.access.redhat.com/openshift3
      openshift_configmap_reload_namespace: registry.access.redhat.com/openshift3
      openshift_prometheus_operator_namespace: registry.access.redhat.com/openshift3
      openshift_prometheus_config_reload_namespace: registry.access.redhat.com/openshift3
      openshift_kube_rbac_proxy_namespace: registry.access.redhat.com/openshift3
      openshift_kube_state_metrics_namespace: registry.access.redhat.com/openshift3
      openshift_grafana_namespace: registry.access.redhat.com/openshift3

  # Process openshift images without retagging them
  - includes:
    - openshift
    # Uncomment to serve images from the undercloud registry. Images will be
    # copied to the undercloud registry during preparation.
    # To copy/serve from a different local registry, set the value to
    # <address>:<port> of the registry service.
    # push_destination: true

    # Substitutions to be made when processing the template file
    # <prefix>/share/tripleo-common/container-images/overcloud_containers.yaml.j2
    set:
      # Container image name components for OpenShift images.
      # Only used if OpenShift is deployed.
      openshift_namespace: registry.access.redhat.com/openshift3
      openshift_tag: v3.11
      openshift_prefix: ose
      openshift_cockpit_namespace: registry.access.redhat.com/openshift3
      openshift_cockpit_image: registry-console
      openshift_cockpit_tag: v3.11
      openshift_asb_namespace: registry.access.redhat.com/openshift3
      openshift_asb_tag: v3.11
      openshift_cluster_monitoring_namespace: registry.access.redhat.com/openshift3
      openshift_cluster_monitoring_image: ose-cluster-monitoring-operator
      openshift_cluster_monitoring_tag: v3.11
      openshift_configmap_reload_namespace: registry.access.redhat.com/openshift3
      openshift_configmap_reload_image: ose-configmap-reloader
      openshift_configmap_reload_tag: v3.11
      openshift_prometheus_operator_namespace: registry.access.redhat.com/openshift3
      openshift_prometheus_operator_image: ose-prometheus-operator
      openshift_prometheus_operator_tag: v3.11
      openshift_prometheus_config_reload_namespace: registry.access.redhat.com/openshift3
      openshift_prometheus_config_reload_image: ose-prometheus-config-reloader
      openshift_prometheus_config_reload_tag: v3.11
      openshift_prometheus_tag: v3.11
      openshift_prometheus_alertmanager_tag: v3.11
      openshift_prometheus_node_exporter_tag: v3.11
      openshift_oauth_proxy_tag: v3.11
      openshift_kube_rbac_proxy_namespace: registry.access.redhat.com/openshift3
      openshift_kube_rbac_proxy_image: ose-kube-rbac-proxy
      openshift_kube_rbac_proxy_tag: v3.11
      openshift_kube_state_metrics_namespace: registry.access.redhat.com/openshift3
      openshift_kube_state_metrics_image: ose-kube-state-metrics
      openshift_kube_state_metrics_tag: v3.11
      openshift_grafana_namespace: registry.access.redhat.com/openshift3
      openshift_grafana_tag: v3.11
EOF
else
openstack tripleo container image prepare default \
  --output-env-file $HOME/containers-prepare-parameter.yaml \
  --local-push-destination
fi


# Generate a roles_data with Openshift roles
if [[ $OPENSHIFT_AIO -eq 1 ]]; then
  openstack overcloud roles generate --roles-path $HOME/tripleo-heat-templates/roles -o $HOME/openshift_roles_data.yaml OpenShiftAllInOne
else
  openstack overcloud roles generate --roles-path $HOME/tripleo-heat-templates/roles -o $HOME/openshift_roles_data.yaml OpenShiftMaster OpenShiftWorker OpenShiftInfra
fi

if [[ $OPENSHIFT_DOWNSTREAM -eq 1 ]]; then
  OPENSHIFT_DEPLOYMENT_TYPE=openshift-enterprise
  if [ -e $HOME/openshift_extra_vars ]; then
    source $HOME/openshift_extra_vars
  fi
else
  OPENSHIFT_DEPLOYMENT_TYPE=origin
fi

# Create the openshift config
cat > $HOME/openshift_env.yaml << EOF
# resource_registry:

parameter_defaults:
  CloudName: openshift.localdomain

  OpenShiftMasterCount: 1
  OpenShiftWorkerCount: 3
  OpenShiftInfraCount: 3
  OpenShiftAllInOneCount: 1
  OpenShiftGlusterDisks:
    - /dev/vdb

  OvercloudOpenShiftMasterFlavor: oooq_openshift_master
  OvercloudOpenShiftWorkerFlavor: oooq_openshift_worker
  OvercloudOpenShiftInfraFlavor: oooq_openshift_infra
  OvercloudOpenShiftAllInOneFlavor: oooq_openshift_aio

  DnsServers: ["192.168.23.1"]

  DockerInsecureRegistryAddress: 192.168.24.1:8787

  OpenShiftDeploymentType: $OPENSHIFT_DEPLOYMENT_TYPE

  OpenShiftGlobalVariables:

    # Allow all auth
    # https://docs.openshift.com/container-platform/3.7/install_config/configuring_authentication.html#overview
    openshift_master_identity_providers:
    - name: allow_all
      login: 'true'
      challenge: true
      kind: AllowAllPasswordIdentityProvider

    openshift_disable_check: memory_availability
    $OPENSHIFT_ANSIBLE_EXTRA_VARS
EOF

# TODO(mandre) Use image prepare workflow at deploy time
# It's currently failing to deploy downstream because of manifest issue when
# pulling from registry.access.redhat.com and rsyslogd image that is not
# available downstream
if [[ $OPENSHIFT_DOWNSTREAM -eq 1 ]]; then
  openstack overcloud container image prepare \
    --push-destination 192.168.24.1:8787 \
    --output-env-file $HOME/openshift_docker_images.yaml \
    --output-images-file $HOME/openshift_containers.yaml \
    --set openshift_namespace=registry.access.redhat.com/openshift3 \
    --set openshift_tag="v3.11" \
    --set openshift_prefix="ose" \
    --set openshift_cockpit_namespace="registry.access.redhat.com/openshift3" \
    --set openshift_cockpit_image="registry-console" \
    --set openshift_cockpit_tag="v3.11" \
    --set openshift_etcd_namespace="registry.access.redhat.com/rhel7" \
    --set openshift_etcd_image="etcd" \
    --set openshift_etcd_tag="latest" \
    --set openshift_gluster_namespace="registry.access.redhat.com/rhgs3" \
    --set openshift_gluster_image="rhgs-server-rhel7" \
    --set openshift_gluster_block_image="rhgs-gluster-block-prov-rhel7" \
    --set openshift_gluster_tag="v3.11" \
    --set openshift_heketi_namespace="registry.access.redhat.com/rhgs3" \
    --set openshift_heketi_image="rhgs-volmanager-rhel7" \
    --set openshift_heketi_tag="v3.11" \
    --set openshift_asb_namespace="registry.access.redhat.com/openshift3" \
    --set openshift_asb_tag="v3.11" \
    --set openshift_cluster_monitoring_namespace='registry.access.redhat.com/openshift3' \
    --set openshift_cluster_monitoring_image='ose-cluster-monitoring-operator' \
    --set openshift_cluster_monitoring_tag='v3.11' \
    --set openshift_configmap_reload_namespace='registry.access.redhat.com/openshift3' \
    --set openshift_configmap_reload_image='ose-configmap-reloader' \
    --set openshift_configmap_reload_tag='v3.11' \
    --set openshift_prometheus_operator_namespace='registry.access.redhat.com/openshift3' \
    --set openshift_prometheus_operator_image='ose-prometheus-operator' \
    --set openshift_prometheus_operator_tag='v3.11' \
    --set openshift_prometheus_config_reload_namespace='registry.access.redhat.com/openshift3' \
    --set openshift_prometheus_config_reload_image='ose-prometheus-config-reloader' \
    --set openshift_prometheus_config_reload_tag='v3.11' \
    --set openshift_prometheus_tag='v3.11' \
    --set openshift_prometheus_alertmanager_tag='v3.11' \
    --set openshift_prometheus_node_exporter_tag='v3.11' \
    --set openshift_oauth_proxy_tag='v3.11' \
    --set openshift_kube_rbac_proxy_namespace='registry.access.redhat.com/openshift3' \
    --set openshift_kube_rbac_proxy_image='ose-kube-rbac-proxy' \
    --set openshift_kube_rbac_proxy_tag='v3.11' \
    --set openshift_kube_state_metrics_namespace='registry.access.redhat.com/openshift3' \
    --set openshift_kube_state_metrics_image='ose-kube-state-metrics' \
    --set openshift_kube_state_metrics_tag='v3.11' \
    --set openshift_grafana_namespace='registry.access.redhat.com/openshift3' \
    --set openshift_grafana_tag='v3.11' \
    -e $HOME/tripleo-heat-templates/environments/docker.yaml \
    -e $HOME/tripleo-heat-templates/environments/openshift.yaml \
    -e $HOME/tripleo-heat-templates/environments/openshift-cns.yaml \
    -e $HOME/openshift_env.yaml \
    -r $HOME/openshift_roles_data.yaml
else
  openstack overcloud container image prepare \
    --push-destination 192.168.24.1:8787 \
    --output-env-file $HOME/openshift_docker_images.yaml \
    --output-images-file $HOME/openshift_containers.yaml \
    -e $HOME/tripleo-heat-templates/environments/docker.yaml \
    -e $HOME/tripleo-heat-templates/environments/openshift.yaml \
    -e $HOME/tripleo-heat-templates/environments/openshift-cns.yaml \
    -e $HOME/openshift_env.yaml \
    -r $HOME/openshift_roles_data.yaml
fi
sudo openstack overcloud container image upload --config-file $HOME/openshift_containers.yaml
