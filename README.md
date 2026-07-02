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
- OpenClaw/Atomus como operador interno recuperavel, nao como raiz de confianca da infraestrutura.
- Fontes de verdade externas ao cluster para GitHub, vault, manifests, imagens e credenciais de recuperacao.
- Namespace padrao da plataforma Autus: `autus`.

## Estrutura

```text
.github/workflows/
  reusable-k8s-build-deploy.yml
  reusable-ghcr-pull-secret.yml
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
  autus-operating-model.md
  cluster-bootstrap-microk8s.md
  migrate-microk8s-registry-to-ghcr.md
  persistent-github-access.md
  migration-from-ecletica.md
```

## Modelo operacional Autus

OpenClaw/Atomus pode rodar dentro do MicroK8s da Autus, mas a infraestrutura
deve continuar recuperavel sem depender de um pod OpenClaw ativo.

Leia `docs/autus-operating-model.md` antes de alterar bootstrap, secrets,
workflows, backups ou credenciais de operador.

Namespace oficial da plataforma Autus:

```text
autus
```

Namespaces de produto ou cliente, como `ebl`, podem existir para isolamento
operacional, mas nao devem ser tratados como padrao da plataforma.

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
      namespace: autus
      dockerfile: ./Dockerfile
      context: .
      container_port: 8080
      ingress_hosts: api.autus.solutions
      environment_name: production
      enable_probes: "true"
      secret_name: autus-api-secrets
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

Namespaces que puxam imagens GHCR privadas devem receber um pull secret e declarar:

```yaml
with:
  image_pull_secret_name: ghcr-pull-secret
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

GitHub Secrets de ambiente ou repositorio:

- `KUBE_CONFIG`: kubeconfig com acesso ao namespace alvo.

GitHub Secrets organizacionais em `Autus-Solutions`:

- `AUTUS_GHCR_PULL_USERNAME`: usuario ou machine user com acesso de leitura aos packages GHCR.
- `AUTUS_GHCR_PULL_TOKEN`: token com `read:packages` para gerar o pull secret do cluster.

Essas secrets devem ser disponibilizadas para o repositorio `Autus-Solutions/autus-infra` e, quando o deploy rodar diretamente em repos da organizacao Autus, para os repos consumidores que chamarem o workflow reutilizavel. Repos fora da organizacao, como repos ainda mantidos em `ecleticabeerlab`, nao recebem secrets organizacionais da Autus automaticamente; nesse caso, sincronize o pull secret pelo workflow deste repositorio de infra ou replique a secret na organizacao/repo dono do workflow.

Para gerar um kubeconfig namespace-scoped no MicroK8s, use:

```bash
./scripts/create-github-actions-kubeconfig.sh autus > /tmp/autus-kubeconfig.yaml
```

Kubernetes Secrets por app:

- `<app_name>-secrets`: secrets da aplicacao, criado fora do CI.
- `secret_name`: input opcional do workflow para apontar o `envFrom.secretRef`
  para uma Secret nativa do Kubernetes com outro nome. Se omitido, usa
  `<app_name>-secrets`.
- `ghcr-pull-secret`: pull secret gerado automaticamente a partir das secrets organizacionais do GHCR.

Credenciais de operador/runtime:

- GitHub SSH deve ter fonte de verdade fora do cluster, como 1Password ou outro vault.
- Kubernetes Secrets e arquivos em `~/.ssh` dentro de pods sao apenas copias operacionais.
- Veja `docs/persistent-github-access.md` para restauracao apos rebuild do cluster.

GitHub Variables opcionais:

- `KUBE_CONTEXT`: contexto Kubernetes, se o kubeconfig possuir mais de um.
- `INGRESS_CLASS_NAME`: padrao `public`.
- `TLS_CLUSTER_ISSUER`: padrao vazio. Use quando houver cert-manager com ClusterIssuer.

## Sincronizar GHCR pull secret

Para criar ou atualizar o `ghcr-pull-secret` no cluster, execute o workflow `Reusable GHCR Pull Secret Sync` em `Autus-Solutions/autus-infra` informando o namespace. Para workloads oficiais da Autus, use `autus`.

O mesmo processo pode ser chamado por outro workflow:

```yaml
jobs:
  sync-ghcr-pull-secret:
    uses: Autus-Solutions/autus-infra/.github/workflows/reusable-ghcr-pull-secret.yml@main
    with:
      namespace: autus
      secret_name: ghcr-pull-secret
      environment_name: production
    secrets:
      KUBE_CONFIG: ${{ secrets.KUBE_CONFIG }}
      AUTUS_GHCR_PULL_USERNAME: ${{ secrets.AUTUS_GHCR_PULL_USERNAME }}
      AUTUS_GHCR_PULL_TOKEN: ${{ secrets.AUTUS_GHCR_PULL_TOKEN }}
```

Deploys tambem podem garantir o pull secret automaticamente:

```yaml
with:
  image_pull_secret_name: ghcr-pull-secret
  ensure_image_pull_secret: "true"
secrets:
  AUTUS_GHCR_PULL_USERNAME: ${{ secrets.AUTUS_GHCR_PULL_USERNAME }}
  AUTUS_GHCR_PULL_TOKEN: ${{ secrets.AUTUS_GHCR_PULL_TOKEN }}
```

## Comando local para testar renderizacao

```bash
APP_NAME=autus-api \
NAMESPACE=autus \
IMAGE=ghcr.io/autus-solutions/autus-api:local \
CONTAINER_PORT=8080 \
INGRESS_HOSTS=api.autus.solutions \
python3 scripts/render-k8s.py
```
