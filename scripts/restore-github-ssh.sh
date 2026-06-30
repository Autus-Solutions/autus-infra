#!/usr/bin/env bash
set -euo pipefail

KEY_NAME="${GITHUB_SSH_KEY_NAME:-autus_github_ed25519}"
SSH_DIR="${SSH_DIR:-$HOME/.ssh}"
KEY_PATH="$SSH_DIR/$KEY_NAME"
KNOWN_HOSTS_PATH="$SSH_DIR/known_hosts"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [[ -n "${GITHUB_SSH_PRIVATE_KEY_B64:-}" ]]; then
  printf '%s' "$GITHUB_SSH_PRIVATE_KEY_B64" | base64 -d > "$KEY_PATH"
elif [[ -n "${GITHUB_SSH_PRIVATE_KEY:-}" ]]; then
  printf '%s\n' "$GITHUB_SSH_PRIVATE_KEY" > "$KEY_PATH"
else
  echo "Missing GITHUB_SSH_PRIVATE_KEY or GITHUB_SSH_PRIVATE_KEY_B64." >&2
  exit 1
fi

chmod 600 "$KEY_PATH"

touch "$KNOWN_HOSTS_PATH"
chmod 644 "$KNOWN_HOSTS_PATH"
if ! ssh-keygen -F github.com -f "$KNOWN_HOSTS_PATH" >/dev/null; then
  ssh-keyscan github.com >> "$KNOWN_HOSTS_PATH" 2>/dev/null
fi

cat > "$SSH_DIR/config" <<EOF
Host github.com
  HostName github.com
  User git
  IdentityFile $KEY_PATH
  IdentitiesOnly yes
  StrictHostKeyChecking yes
  UserKnownHostsFile $KNOWN_HOSTS_PATH
EOF
chmod 600 "$SSH_DIR/config"

echo "GitHub SSH key restored at $KEY_PATH."
echo "Run: ssh -T git@github.com"
