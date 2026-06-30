# Autus Infrastructure

Infraestrutura Kubernetes e CI/CD reutilizavel para projetos da Autus Solutions.

Este repositorio generaliza a infraestrutura observada nos projetos da Eclética Beer Lab e remove acoplamentos especificos como:

- namespace fixo `ebl`;
- imagens `ebc-*`;
- hosts `*.ecletica.beer`;
- registry inseguro em `VPS_IP:32000`;
- secrets versionados em manifests;
- actions pinadas em `master`.

## Modelo alvo

- Registry padrao: GitHub Container Registry (`ghcr.io`).
- Deploy padrao: Kubernetes/MicroK8s via `KUBE_CONFIG`.
- Configuracao por ambiente: GitHub Environments, repository variables e Kubernetes Secrets.
- Manifests renderizados no CI a partir de templates versionados.
- Rollout validado antes de concluir o pipeline.

## Estrutura

```text
.github/workflows/
  reusable-k8s-build-deploy.yml
k8s/templates/
  deployment.yaml.tpl
  ingress.yaml.tpl
scripts/
  render-k8s.py
  restore-github-ssh.sh
examples/
  service-api.yml
  service-web.yml
  service-worker.yml
  service-mcp.yml
docs/
  cluster-bootstrap-microk8s.md
  persistent-github-access.md
  migration-from-ecletica.md
```

## Como usar em um repo de produto

Crie um workflow no repositório da aplicação chamando o workflow reutilizável:

```yaml
name: Deploy API

on:
  workflow_dispatch:
  push:
    branches: ["main"]

jobs:
  deploy:
    uses: Autus-Solutions/autus-infra/.github/workflows/reusable-k8s-build-deploy.yml@main
    with:
      app_name: autus-api
      namespace: autus-prod
      dockerfile: ./Dockerfile
      context: .
      container_port: 8080
      ingress_hosts: api.autus.solutions
      environment_name: production
      enable_probes: "true"
    secrets:
      KUBE_CONFIG: ${{ secrets.KUBE_CONFIG }}
```

Servicos sem endpoint HTTP de saude, como workers, devem usar:

```yaml
with:
  enable_probes: "false"
  ingress_hosts: ""
```

Aplicacoes com build args Docker podem declarar:

```yaml
with:
  build_args: |
    NEXT_PUBLIC_APP_URL=${{ vars.NEXT_PUBLIC_APP_URL }}
    NEXT_PUBLIC_API_URL=${{ vars.NEXT_PUBLIC_API_URL }}
```

Ingresses com issuer ou anotacoes especificas podem passar:

```yaml
with:
  tls_secret_name: app-tls
  ingress_annotations: |
    cert-manager.io/issuer: app-issuer
    cert-manager.io/issuer-kind: OriginIssuer
    cert-manager.io/issuer-group: cert-manager.k8s.cloudflare.com
```

## Secrets e variables esperados

GitHub Secrets:

- `KUBE_CONFIG`: kubeconfig com acesso ao namespace alvo.

Para gerar um kubeconfig namespace-scoped no MicroK8s, use:

```bash
./scripts/create-github-actions-kubeconfig.sh autus-prod > /tmp/autus-prod-kubeconfig.yaml
```

Kubernetes Secrets por app:

- `<app_name>-secrets`: secrets da aplicacao, criado fora do CI.

Credenciais de operador/runtime:

- GitHub SSH deve ter fonte de verdade fora do cluster, como 1Password ou outro vault.
- Kubernetes Secrets e arquivos em `~/.ssh` dentro de pods sao apenas copias operacionais.
- Veja `docs/persistent-github-access.md` para restauracao apos rebuild do cluster.

GitHub Variables opcionais:

- `KUBE_CONTEXT`: contexto Kubernetes, se o kubeconfig possuir mais de um.
- `INGRESS_CLASS_NAME`: padrao `public`.
- `TLS_CLUSTER_ISSUER`: padrao vazio. Use quando houver cert-manager com ClusterIssuer.

## Comando local para testar renderizacao

```bash
APP_NAME=autus-api \
NAMESPACE=autus-prod \
IMAGE=ghcr.io/autus-solutions/autus-api:local \
CONTAINER_PORT=8080 \
INGRESS_HOSTS=api.autus.solutions \
python3 scripts/render-k8s.py
```
