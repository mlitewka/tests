#!/bin/bash

while [[ $# -gt 0 ]]; do
    case $1 in
        --acr-id) acr_id="$2"; shift; shift;; #
        *) echo "Invalid amount of parameters or unrecognized parameter: $2, check script execution."; exit 1;;
    esac
done

set -euo pipefail
set -m
export HISTCONTROL=ignorespace

echo -e "\nNamespaces:"
kubectl get namespaces

echo -e "\nDeploy global exclusions:"
kubectl apply -f ./gatekeeper-config.yaml

echo -e "\nDeploy templates:"
kubectl apply -f ./standard/pod_host_ipc/template.yaml
kubectl apply -f ./standard/pod_host_pid/template.yaml
kubectl apply -f ./standard/pod_host_network/template.yaml
kubectl apply -f ./standard/pod_security_privileged/template.yaml
kubectl apply -f ./standard/pod_capabilities_drop/template.yaml
kubectl apply -f ./standard/pod_capabilities_blacklist/template.yaml
kubectl apply -f ./standard/pod_host_ports/template.yaml
kubectl apply -f ./standard/pod_volume_hostpath/template.yaml
kubectl apply -f ./standard/pod_apparmor/template.yaml
kubectl apply -f ./standard/pod_security_selinux/template.yaml
kubectl apply -f ./standard/pod_security_procmount/template.yaml
kubectl apply -f ./standard/pod_security_sysctls/template.yaml
kubectl apply -f ./standard/pod_volume_allowed/template.yaml
kubectl apply -f ./standard/pod_security_allowprivilegeescalations/template.yaml
kubectl apply -f ./standard/pod_security_runasroot/template.yaml
kubectl apply -f ./standard/pod_security_runasgroup/template.yaml
kubectl apply -f ./standard/pod_security_fsgroup/template.yaml
kubectl apply -f ./standard/pod_seccomp/template.yaml
kubectl apply -f ./standard/pod_security_readonlyrootfilessystem/template.yaml
kubectl apply -f ./standard/pod_hostaliases/template.yaml
kubectl apply -f ./standard/pod_automountserviceaccounttoken/template.yaml
kubectl apply -f ./standard/general_resources_request_cpu/template.yaml
kubectl apply -f ./standard/general_resources_request_memory/template.yaml
kubectl apply -f ./standard/general_resources_limit_cpu/template.yaml
kubectl apply -f ./standard/general_resources_limit_memory/template.yaml
kubectl apply -f ./standard/pod_container_imagetag/template.yaml
kubectl apply -f ./standard/storageclass_constraint/template.yaml
kubectl apply -f ./standard/pod_container_repos/template.yaml
kubectl apply -f ./custom/service_type/template.yaml
kubectl apply -f ./standard/general_deny_deployment_to_namespace/template.yaml

# Wait for API
sleep 10

echo -e "\nDeploy Constraints:"
kubectl apply -f ./standard/pod_host_ipc/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_host_pid/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_host_network/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_security_privileged/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_capabilities_drop/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_capabilities_blacklist/constraint_cap_net_raw.yaml
sleep 3

kubectl apply -f ./standard/pod_capabilities_blacklist/constraint_sys_admin.yaml
sleep 3

kubectl apply -f ./standard/pod_host_ports/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_volume_hostpath/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_apparmor/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_security_selinux/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_security_procmount/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_security_sysctls/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_volume_allowed/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_security_allowprivilegeescalations/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_security_runasroot/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_security_runasgroup/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_security_fsgroup/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_seccomp/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_security_readonlyrootfilessystem/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_hostaliases/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_automountserviceaccounttoken/constraint.yaml
sleep 3

kubectl apply -f ./standard/general_resources_request_cpu/constraint.yaml
sleep 3

kubectl apply -f ./standard/general_resources_request_memory/constraint.yaml
sleep 3

kubectl apply -f ./standard/general_resources_limit_cpu/constraint.yaml
sleep 3

kubectl apply -f ./standard/general_resources_limit_memory/constraint.yaml
sleep 3

kubectl apply -f ./standard/pod_container_imagetag/constraint.yaml
sleep 3

kubectl apply -f ./standard/storageclass_constraint/constraint.yaml
sleep 3

acr_name="${acr_id##*/}.azurecr.io/"
sed -i "s:ALLOWED_REPOSITORY:$acr_name:g" ./standard/pod_container_repos/constraint.yaml

kubectl apply -f ./standard/pod_container_repos/constraint.yaml
sleep 3

kubectl apply -f ./custom/service_type/constraint.yaml
sleep 3

kubectl apply -f ./standard/general_deny_deployment_to_namespace/constraint.yaml
sleep 3

