#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  GHCR_USERNAME=<github-user> GHCR_TOKEN=<token> ./scripts/create-ghcr-pull-secret.sh <namespace> [secret-name]

Creates or updates a Kubernetes docker-registry secret for pulling private GHCR images.

Required:
  GHCR_USERNAME  GitHub user or machine user with package read access.
  GHCR_TOKEN     GitHub token with read:packages access.

Optional:
  GHCR_EMAIL     Docker registry email metadata. Defaults to noreply@autus.solutions.

Example:
  GHCR_USERNAME=autus-bot GHCR_TOKEN=... ./scripts/create-ghcr-pull-secret.sh ebl ghcr-pull-secret
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

namespace="${1:-}"
secret_name="${2:-ghcr-pull-secret}"
email="${GHCR_EMAIL:-noreply@autus.solutions}"

if [ -z "$namespace" ]; then
  usage >&2
  exit 2
fi

if [ -z "${GHCR_USERNAME:-}" ] || [ -z "${GHCR_TOKEN:-}" ]; then
  echo "GHCR_USERNAME and GHCR_TOKEN are required." >&2
  exit 2
fi

kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry "$secret_name" \
  --namespace "$namespace" \
  --docker-server=ghcr.io \
  --docker-username="$GHCR_USERNAME" \
  --docker-password="$GHCR_TOKEN" \
  --docker-email="$email" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl get secret "$secret_name" -n "$namespace"
