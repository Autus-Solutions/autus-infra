#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Create or update a Kubernetes opaque Secret from environment variables.

Usage:
  create-k8s-secret-from-env.sh <namespace> <secret-name> <ENV_NAME> [ENV_NAME...]

Each named environment variable must be present and non-empty. Values are read
from the current process environment and are not printed.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 3 ]]; then
  usage >&2
  exit 2
fi

namespace="$1"
secret_name="$2"
shift 2

if [[ -z "$namespace" || -z "$secret_name" ]]; then
  echo "namespace and secret-name are required." >&2
  exit 2
fi

args=()
for env_name in "$@"; do
  if [[ -z "$env_name" ]]; then
    echo "empty environment variable name." >&2
    exit 2
  fi

  if [[ -z "${!env_name:-}" ]]; then
    echo "Required environment variable is empty or unavailable: $env_name" >&2
    exit 1
  fi

  args+=(--from-literal="$env_name=${!env_name}")
done

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic "$secret_name" \
  -n "$namespace" \
  "${args[@]}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Kubernetes Secret $namespace/$secret_name is synced."
