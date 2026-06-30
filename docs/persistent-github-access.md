# Persistent GitHub Access For Autus Runtimes

The SSH key inside an OpenClaw/Codex pod is operational state only. It is not the durable source of truth. If the Kubernetes cluster, node, namespace, pod, or PVC is deleted, credentials stored only inside the pod can be lost.

Use this model:

```text
1Password or external vault
  -> Kubernetes Secret or runtime env
    -> ~/.ssh inside the OpenClaw/Codex pod
      -> GitHub SSH authentication
```

## Recommended Source Of Truth

Store the private key in a vault outside the cluster.

Recommended 1Password item:

```text
Vault: Autus Infrastructure
Item: Autus OpenClaw GitHub SSH Key
Field: private_key
Field: public_key
Field: fingerprint
Field: github_scope
```

The public key should be registered in GitHub as one of these:

- Account SSH key for the Autus automation/operator account, if the runtime needs access to multiple repositories.
- Repository deploy key with write access, if the runtime should only push to one repository such as `Autus-Solutions/autus-infra`.

## Create The Key

Generate the key on a trusted machine or in the runtime once, then move the private key into the vault.

```bash
ssh-keygen -t ed25519 \
  -C "autus-openclaw-github-$(date +%Y%m%d)" \
  -f ./autus_github_ed25519 \
  -N ""
```

Save `autus_github_ed25519` as `private_key` in the vault. Save `autus_github_ed25519.pub` as `public_key`.

Do not commit the private key to Git.

## Restore Into A Runtime

The runtime can restore SSH access from either a raw private key or a base64 private key.

Raw private key:

```bash
export GITHUB_SSH_PRIVATE_KEY="$(op read 'op://Autus Infrastructure/Autus OpenClaw GitHub SSH Key/private_key')"
./scripts/restore-github-ssh.sh
```

Base64 private key:

```bash
export GITHUB_SSH_PRIVATE_KEY_B64="$(op read 'op://Autus Infrastructure/Autus OpenClaw GitHub SSH Key/private_key' | base64 -w0)"
./scripts/restore-github-ssh.sh
```

Validate:

```bash
ssh -T git@github.com
```

GitHub usually returns a message saying authentication succeeded and shell access is not provided.

## Kubernetes Secret Copy

If the runtime should restore automatically at pod startup, create a Kubernetes Secret from the vault during cluster bootstrap:

```bash
microk8s kubectl create secret generic github-ssh \
  -n openclaw \
  --from-literal=GITHUB_SSH_PRIVATE_KEY="$(op read 'op://Autus Infrastructure/Autus OpenClaw GitHub SSH Key/private_key')" \
  --dry-run=client -o yaml | microk8s kubectl apply -f -
```

Then inject the secret as an environment variable and run `scripts/restore-github-ssh.sh` before Git operations.

The Kubernetes Secret is only a runtime copy. If the cluster is destroyed, recreate it from the external vault.

## Disaster Recovery

After rebuilding the VPS or MicroK8s cluster:

1. Reinstall OpenClaw/Codex runtime.
2. Authenticate the vault CLI or inject the vault service account token.
3. Recreate the `github-ssh` Kubernetes Secret from the vault.
4. Start the runtime.
5. Run `scripts/restore-github-ssh.sh`.
6. Validate with `ssh -T git@github.com`.
7. Continue Git operations, for example:

```bash
cd /home/node/.openclaw/workspace/work_sessions/autus-infra
git push -u origin main
```

## Rotation

Rotate the key when an operator leaves, a runtime is compromised, or access scope changes.

1. Generate a new key.
2. Register the new public key in GitHub.
3. Update the vault item.
4. Recreate the Kubernetes Secret from the vault.
5. Restart the runtime or rerun `scripts/restore-github-ssh.sh`.
6. Remove the old public key from GitHub.
