# Migração da Infra Eclética para Autus

## Origem analisada

Repositorios locais analisados:

- `ecleticabeerlab/ecletica-beer-control-api`
- `ecleticabeerlab/ecletica-beer-control-web`

Arquivos relevantes:

- `.github/workflows/deploy-api.yml`
- `.github/workflows/deploy-worker.yml`
- `.github/workflows/deploy-mcp.yml`
- `.github/workflows/deploy-web.yml`
- `.github/deployments/deployment-api.yaml`
- `.github/deployments/deployment-worker.yaml`
- `.github/deployments/deployment-mcp.yaml`
- `.github/deployments/deployment-web.yaml`
- `.github/deployments/ingress.yaml`

## Decisoes de generalizacao

| Origem Eclética | Padrao Autus |
| --- | --- |
| `namespace: ebl` | `namespace` por ambiente/projeto |
| `ebc-api`, `ebc-web`, `ebc-worker`, `ebc-mcp` | `app_name` parametrico |
| `localhost:32000` / `${{ vars.VPS_IP }}:32000` | `ghcr.io/<owner>/<app>` |
| `development` fixo | branch/tag/SHA do GitHub Actions |
| secrets substituidos em YAML | Kubernetes Secret referenciado por `envFrom` |
| Secret Cloudflare versionado em base64 | Secret externo ao repo |
| `actions/checkout@v3` | `actions/checkout@v4` |
| `actions-hub/kubectl@master` | `kubectl` instalado e executado diretamente |
| sem probes/recursos/securityContext | probes, recursos e securityContext por padrao |

## Riscos corrigidos

- Removido secret material de manifests versionados.
- Eliminada dependencia em action de kubectl referenciada por branch mutavel.
- Evitado registry inseguro no runner do GitHub.
- Imagens passam a ser rastreaveis por SHA e branch.
- Deploy passa a validar rollout antes de encerrar.

## O que continua parametrico

- Dominio publico.
- Nome do namespace.
- Porta do container.
- Path de health check.
- ConfigMap e Secret da aplicacao.
- Ingress class e emissor TLS.

## Recomendacao Autus

Criar o repositorio `Autus-Solutions/autus-infra` e manter este conteudo como fonte comum de CI/CD e manifests reutilizaveis.

Cada produto deve chamar o workflow reutilizavel e manter apenas o Dockerfile e configuracoes especificas da aplicacao no seu proprio repositorio.

