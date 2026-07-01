#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-openclaw}"
DEPLOYMENT="${DEPLOYMENT:-openclaw}"
SECRET_NAME="${SECRET_NAME:-github-cli-auth}"
VALIDATION_REPO="${VALIDATION_REPO:-Autus-Solutions/autus-infra}"

usage() {
  cat <<'USAGE'
Bootstrap persistent GitHub CLI auth for Atomus/OpenClaw.

Sources, in priority order:
  1. GH_TOKEN environment variable
  2. --token-stdin

Examples:
  export KUBECONFIG="$HOME/.kube/autus-microk8s.config"
  GH_TOKEN=... ./scripts/bootstrap-openclaw-gh-auth.sh

  printf '%s' "$TOKEN_FROM_GITHUB_SECRET" | ./scripts/bootstrap-openclaw-gh-auth.sh --token-stdin

Environment:
  NAMESPACE        Kubernetes namespace. Default: openclaw
  DEPLOYMENT       Kubernetes deployment. Default: openclaw
  SECRET_NAME      Kubernetes secret. Default: github-cli-auth
  VALIDATION_REPO  GitHub repo used for gh validation. Default: Autus-Solutions/autus-infra
USAGE
}

TOKEN_STDIN=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --token-stdin)
      TOKEN_STDIN=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

need_cmd kubectl

github_token="${GH_TOKEN:-}"

if [[ -z "$github_token" && "$TOKEN_STDIN" == "true" ]]; then
  IFS= read -r github_token
fi

if [[ -z "$github_token" ]]; then
  cat >&2 <<EOF
No GitHub token source available.

Set GH_TOKEN or pipe the token with --token-stdin.
EOF
  exit 1
fi

if [[ -z "$github_token" ]]; then
  echo "Resolved GitHub token is empty." >&2
  exit 1
fi

kubectl create secret generic "$SECRET_NAME" \
  -n "$NAMESPACE" \
  --from-literal=GH_TOKEN="$github_token" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl set env "deployment/$DEPLOYMENT" \
  -n "$NAMESPACE" \
  --from="secret/$SECRET_NAME"

kubectl rollout status "deployment/$DEPLOYMENT" -n "$NAMESPACE"

kubectl exec -n "$NAMESPACE" "deploy/$DEPLOYMENT" -- gh auth status
kubectl exec -n "$NAMESPACE" "deploy/$DEPLOYMENT" -- gh repo view "$VALIDATION_REPO" >/dev/null

echo "OpenClaw GitHub CLI auth is active for $VALIDATION_REPO."
