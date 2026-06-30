# MicroK8s Cluster Bootstrap for GitHub Actions

Este guia cria um kubeconfig com permissao namespace-scoped para o GitHub Actions.

## 1. Preparar add-ons

Na VPS:

```bash
microk8s status --wait-ready
microk8s enable dns storage ingress
```

Se usar cert-manager:

```bash
microk8s enable cert-manager
```

## 2. Criar kubeconfig de deploy

Use `kubectl` apontando para o cluster:

```bash
alias kubectl='microk8s kubectl'
```

Gere o kubeconfig:

```bash
./scripts/create-github-actions-kubeconfig.sh autus-prod > /tmp/autus-prod-kubeconfig.yaml
```

O conteudo de `/tmp/autus-prod-kubeconfig.yaml` deve ser cadastrado no GitHub Secret:

```text
KUBE_CONFIG
```

## 3. Permissoes concedidas

O service account gerado pode operar apenas no namespace informado.

Recursos permitidos:

- `deployments`
- `replicasets`
- `services`
- `ingresses`
- `configmaps`
- `secrets`
- `pods`
- `pods/log`

Escopo:

- `get`
- `list`
- `watch`
- `create`
- `update`
- `patch`

Nao ha permissao para deletar recursos.

## 4. Validacao

```bash
KUBECONFIG=/tmp/autus-prod-kubeconfig.yaml kubectl get deploy,svc,ingress -n autus-prod
```

## 5. Rotacao

Para rotacionar o acesso:

```bash
./scripts/create-github-actions-kubeconfig.sh autus-prod > /tmp/autus-prod-kubeconfig-rotated.yaml
```

Depois atualize o secret `KUBE_CONFIG` no GitHub.

