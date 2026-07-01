# MicroK8s Cluster Bootstrap for GitHub Actions

Este guia cria um kubeconfig com permissao namespace-scoped para o GitHub Actions.
Ele faz parte do modelo operacional em `docs/autus-operating-model.md`: o
cluster deve ser recuperavel a partir de GitHub, vault e runbooks externos,
mesmo quando OpenClaw/Atomus estiver offline.

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

Para Eclética Beer Lab:

```bash
./scripts/create-github-actions-kubeconfig.sh ebl > /tmp/ebl-kubeconfig.yaml
```

O conteudo de `/tmp/autus-prod-kubeconfig.yaml` deve ser cadastrado no GitHub Secret:

```text
KUBE_CONFIG
```

Preferencia Autus:

```text
Repository: Autus-Solutions/autus-infra
Environment: production
Secret: KUBE_CONFIG
```

O GitHub Environment guarda a copia operacional usada pelo CI. A fonte de
verdade do acesso de recuperacao deve ficar fora do cluster, por exemplo em
1Password ou outro vault.

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

## 6. Relacao com OpenClaw/Atomus

OpenClaw pode executar e validar esses passos quando tiver credenciais, mas nao
deve ser o unico lugar onde o kubeconfig, tokens ou runbooks existem. Depois de
um rebuild completo do cluster, recrie OpenClaw a partir de manifests e secrets
externos antes de retomar operacoes inteligentes.
