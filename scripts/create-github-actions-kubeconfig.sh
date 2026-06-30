#!/usr/bin/env bash
set -euo pipefail

namespace="${1:-}"
service_account="${2:-github-actions-deployer}"

if [ -z "$namespace" ]; then
  echo "usage: $0 <namespace> [service-account]" >&2
  exit 2
fi

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f - <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${service_account}
  namespace: ${namespace}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: ${service_account}
  namespace: ${namespace}
rules:
  - apiGroups: [""]
    resources: ["configmaps", "secrets", "services", "pods", "pods/log"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: ${service_account}
  namespace: ${namespace}
subjects:
  - kind: ServiceAccount
    name: ${service_account}
    namespace: ${namespace}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: ${service_account}
YAML

token="$(kubectl create token "$service_account" -n "$namespace")"
cluster_name="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')"
server="$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
certificate_authority_data="$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')"
context_name="autus-${namespace}"

cat <<YAML
apiVersion: v1
kind: Config
clusters:
  - name: ${cluster_name}
    cluster:
      server: ${server}
      certificate-authority-data: ${certificate_authority_data}
users:
  - name: ${service_account}
    user:
      token: ${token}
contexts:
  - name: ${context_name}
    context:
      cluster: ${cluster_name}
      namespace: ${namespace}
      user: ${service_account}
current-context: ${context_name}
YAML

