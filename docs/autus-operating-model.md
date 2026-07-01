# Modelo Operacional Da Infraestrutura Autus

Este documento define como a Autus opera infraestrutura quando OpenClaw/Atomus
roda dentro do mesmo cluster MicroK8s que ajuda a gerenciar.

## Decisao Executiva

OpenClaw/Atomus e uma superficie operacional interna, nao a fonte raiz de
verdade da infraestrutura.

```text
Fonte de verdade externa
  -> recria e governa o cluster
Cluster MicroK8s
  -> executa workloads Autus
OpenClaw/Atomus
  -> opera, coordena, audita e acelera trabalho dentro do cluster
```

Isso mantem Atomus util como operador da empresa sem criar uma dependencia
circular onde o unico caminho de recuperacao depende de um pod rodando no
cluster que falhou.

## Camadas

### Camada 0: Fonte De Verdade Externa

Deve sobreviver a um rebuild completo do cluster.

- `Autus-Solutions/autus-infra`
- Vault externo, como 1Password
- Configuracoes de organizacao e repositorios GitHub
- GitHub Environments e Actions secrets
- Acesso a dominio, DNS e provedor
- Backups armazenados fora do cluster

A camada 0 possui o material de recuperacao. Nao armazene a unica copia de uma
credencial, manifest, imagem ou backup critico dentro do Kubernetes.

### Camada 1: Infraestrutura Runtime

O cluster MicroK8s da Autus executa os workloads.

- Add-ons MicroK8s: `dns`, `storage`, `ingress` e opcionalmente `cert-manager`
- Namespace oficial da plataforma: `autus`
- Namespaces de produto ou cliente, como `ebl`, quando isolamento operacional
  for necessario
- Kubernetes Secrets como copias runtime
- PVCs para workloads stateful
- Ingress, services, deployments e configmaps

A camada 1 deve ser recriavel a partir da camada 0 mais o acesso ao provedor.

### Camada 2: OpenClaw / Atomus

OpenClaw e a inteligencia operacional da Autus.

- Coordena agentes e trabalho operacional
- Usa GitHub CLI, workflows de repositorio e runbooks
- Revisa e melhora infraestrutura
- Aplica mudancas escopadas quando credenciais estao disponiveis
- Mantem contexto executivo da empresa

OpenClaw pode manter copias operacionais de credenciais, mas nao a unica copia
duravel.

### Camada 3: Produtos E Workloads De Clientes

Exemplos:

- Servicos da Eclética Beer Lab
- Aplicacoes Autus
- APIs, automacoes, workers e servicos MCP de clientes

Esses workloads consomem o modelo compartilhado de deploy do `autus-infra`.

## Politica De Namespace

O namespace oficial da plataforma Autus e:

```text
autus
```

Use `autus` para workloads centrais da Autus, incluindo runtime operacional,
servicos internos e deploys oficiais da plataforma.

Use namespaces especificos, como `ebl`, apenas quando houver necessidade clara
de isolamento por produto, cliente, ciclo de migracao ou requisitos operacionais.
Quando isso acontecer, o `KUBE_CONFIG`, `ghcr-pull-secret` e app secrets devem
existir no namespace especifico do workload.

## Propriedades De Recuperacao

A infraestrutura Autus esta saudavel apenas quando todos estes pontos sao
verdadeiros:

- O cluster pode ser recriado sem exigir OpenClaw online.
- `autus-infra` contem os scripts, workflows, templates e runbooks canonicos.
- O vault guarda a fonte de verdade para credenciais e tokens de operador.
- GitHub Actions consegue fazer deploy no cluster por `KUBE_CONFIG`
  namespace-scoped.
- Kubernetes Secrets runtime podem ser recriados a partir de GitHub/vault.
- GHCR guarda imagens duraveis fora do ciclo de vida do MicroK8s.
- O estado do OpenClaw tem persistencia em PVC e estrategia de backup externo.

## Caminho De Controle Via GitHub Actions

Caminho preferencial de deploy:

```text
Repositorio GitHub
  -> workflow reutilizavel de Autus-Solutions/autus-infra
  -> imagem GHCR
  -> GitHub Environment KUBE_CONFIG
  -> namespace MicroK8s
  -> validacao de rollout
```

O GitHub Environment `production` deve guardar secrets de acesso ao cluster,
como `KUBE_CONFIG`. Organization secrets como `AUTUS_GHCR_PULL_USERNAME` e
`AUTUS_GHCR_PULL_TOKEN` fornecem credenciais reutilizaveis de pull do GHCR.

## Caminho De Recuperacao Do OpenClaw

Depois de um rebuild do cluster:

1. Fazer bootstrap do MicroK8s com `docs/cluster-bootstrap-microk8s.md`.
2. Recriar namespaces e storage classes.
3. Restaurar Kubernetes Secrets necessarios a partir do vault.
4. Fazer deploy dos manifests do OpenClaw.
5. Restaurar acesso SSH GitHub do OpenClaw a partir do vault.
6. Validar `gh`, Git SSH e persistencia do workspace dos agentes.
7. Retomar operacoes Atomus.

OpenClaw deve ser recuperavel, nao magico. Se o runtime desaparecer, a Autus
deve continuar tendo instrucoes e credenciais para traze-lo de volta.

## Checklist Prioritaria Atual

- [ ] Armazenar um `KUBE_CONFIG` namespace-scoped para `autus` no GitHub
      Environment `production` de `Autus-Solutions/autus-infra`.
- [ ] Sincronizar `ghcr-pull-secret` no namespace `autus` pelo workflow
      reutilizavel de GHCR pull secret.
- [ ] Decidir se Eclética continua isolada em `ebl` ou migra para `autus`.
- [ ] Confirmar que os app secrets da Eclética existem no namespace `ebl`.
- [ ] Fazer merge das branches de migracao da Eclética depois que pull secret e
      app secrets existirem.
- [ ] Adicionar cobertura de backup externo para o estado persistido do
      OpenClaw.
- [ ] Mover tokens long-lived e chaves SSH para o vault como fonte de verdade.
- [ ] Manter Kubernetes Secrets apenas como copias runtime.

## Nao Objetivos

- Nao transformar OpenClaw no unico lugar onde credenciais de infra existem.
- Nao tratar o registry local do MicroK8s como fonte duravel de imagens.
- Nao armazenar secrets brutos neste repositorio.
- Nao depender de estado manual de pod como plano de recuperacao.
