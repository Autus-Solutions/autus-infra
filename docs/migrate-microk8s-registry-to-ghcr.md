# Migrate MicroK8s Registry to GHCR

This guide moves Autus services from the MicroK8s local registry to GitHub Container Registry.

## Target model

```text
GitHub repository
  -> GitHub Actions reusable workflow
  -> GHCR image
  -> MicroK8s pulls image with ghcr-pull-secret
  -> Kubernetes rollout
```

MicroK8s remains the runtime cluster. GHCR becomes the durable image registry.

## Requirements

- Application workflow uses `Autus-Solutions/autus-infra/.github/workflows/reusable-k8s-build-deploy.yml@main`.
- GitHub Actions has `packages: write`.
- Cluster namespace has a pull secret named `ghcr-pull-secret`.
- The GitHub token stored in that pull secret has `read:packages` access to the GHCR package owner.

For repos still owned by `ecleticabeerlab`, the default image owner is `ecleticabeerlab` because reusable workflows run in the caller repository context.

## Create the pull secret

Run from an operator machine with `kubectl` access to MicroK8s:

```bash
cd autus-infra
GHCR_USERNAME=<github-user-or-machine-user> \
GHCR_TOKEN=<github-token-with-read-packages> \
./scripts/create-ghcr-pull-secret.sh ebl ghcr-pull-secret
```

Do not commit the token. Store the token source-of-truth outside the cluster, such as 1Password or another vault.

## Merge migration branches

After `ghcr-pull-secret` and app secrets exist in namespace `ebl`, merge:

```text
ecleticabeerlab/ecletica-beer-control-api:infra/autus-reusable-actions
ecleticabeerlab/ecletica-beer-control-web:infra/autus-reusable-actions
```

Merging to `development` will build new GHCR images and roll out Kubernetes deployments.

## Validate

```bash
kubectl get deploy -n ebl
kubectl get pod -n ebl -o wide
kubectl rollout status deployment/ecletica-beer-control-api -n ebl
kubectl rollout status deployment/ecletica-beer-control-web -n ebl
kubectl rollout status deployment/ecletica-beer-control-worker -n ebl
kubectl rollout status deployment/ecletica-beer-control-mcp -n ebl
```

Check that images no longer point to the MicroK8s registry:

```bash
kubectl get deploy -n ebl -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'
```

Expected image prefix:

```text
ghcr.io/
```

## Rollback

The old `.github/deployments` manifests in the application repositories are legacy references. Prefer rolling back to a previous GHCR image tag by SHA once at least one GHCR deployment has succeeded.

Use the MicroK8s registry only as an emergency local fallback.
