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
- Organization secrets exist in `Autus-Solutions`:
  - `AUTUS_GHCR_PULL_USERNAME`
  - `AUTUS_GHCR_PULL_TOKEN`
- Cluster namespace has a pull secret named `ghcr-pull-secret`, generated from those organization secrets.
- The GitHub token stored in `AUTUS_GHCR_PULL_TOKEN` has `read:packages` access to the GHCR package owner.

For repos still owned by `ecleticabeerlab`, the default image owner is `ecleticabeerlab` because reusable workflows run in the caller repository context.

## Register organization secrets

Use a machine user or fine-grained token owner that Autus controls. Grant only package read permissions needed for private GHCR pulls.

Preferred names:

```text
AUTUS_GHCR_PULL_USERNAME
AUTUS_GHCR_PULL_TOKEN
```

With GitHub CLI, an organization owner can register them as organization secrets:

```bash
printf '%s' '<github-user-or-machine-user>' \
  | gh secret set AUTUS_GHCR_PULL_USERNAME --org Autus-Solutions --visibility selected --repos autus-infra

printf '%s' '<github-token-with-read-packages>' \
  | gh secret set AUTUS_GHCR_PULL_TOKEN --org Autus-Solutions --visibility selected --repos autus-infra
```

Do not commit the token. Store the token source-of-truth outside the cluster, such as 1Password or another vault. The GitHub organization secret is the CI copy. The Kubernetes `ghcr-pull-secret` is the runtime copy.

Important: GitHub organization secrets are only available to repositories in that organization. Repos still owned by `ecleticabeerlab` cannot read `Autus-Solutions` organization secrets directly. For those repos, run the pull-secret sync from `Autus-Solutions/autus-infra`, or replicate equivalent secrets in the owning organization until the repos move under Autus.

## Sync the pull secret automatically

Run the workflow `Reusable GHCR Pull Secret Sync` from `Autus-Solutions/autus-infra` with:

```text
namespace: ebl
secret_name: ghcr-pull-secret
environment_name: production
```

That workflow reads:

```text
KUBE_CONFIG
AUTUS_GHCR_PULL_USERNAME
AUTUS_GHCR_PULL_TOKEN
```

and creates or updates `ghcr-pull-secret` in MicroK8s.

## Create the pull secret manually

Run from an operator machine with `kubectl` access to MicroK8s:

```bash
cd autus-infra
AUTUS_GHCR_PULL_USERNAME=<github-user-or-machine-user> \
AUTUS_GHCR_PULL_TOKEN=<github-token-with-read-packages> \
./scripts/create-ghcr-pull-secret.sh ebl ghcr-pull-secret
```

Manual execution is a fallback. Prefer the workflow so namespace bootstrap is repeatable.

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
