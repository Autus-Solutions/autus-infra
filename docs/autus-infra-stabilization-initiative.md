# Autus Infra Stabilization Initiative

## Objetivo
Nenhum serviço crítico da Autus depender exclusivamente do registry local do MicroK8s (`localhost:32000`).

## Trilhas

1. **Governança de credenciais**
   - [X] `KUBE_CONFIG`, `AUTUS_ATOMUS_GH_TOKEN`, `AUTUS_GHCR_PULL_TOKEN` estabelecidos como Repository Secrets para contornar limitações do GitHub Free
   - [X] Sem tokens crus expostos em repo ou chat

2. **Bootstrap GHCR por namespace**
   - [X] Criar `ghcr-pull-secret` em `ebl`
   - [X] Criar `ghcr-pull-secret` em `autus`

3. **Eclética como primeiro corte**
   - [X] Preparar templates kubernetes base no `autus-infra`
   - [X] Habilitar reusable workflow para `ebc-web`
   - [X] Definir estratégia de Overlay para Ingress (`kubernetes/overlays/ebl/ingress-ebc-web.yaml`)
   - [X] Validar Rollout completo e Health da Web
   - [X] Resolver Build constraints para os containers .NET (API, Worker, MCP) e re-executar

4. **Serviços Autus e internos**
   - [X] Criar repositório `autus-landing-page` no GitHub Autus-Solutions
   - [X] Migrar `autus/landing-page` (atualmente lendo de `localhost:32000`) para GHCR via `autus-infra`
   - [ ] Classificar os demais workloads (OpenClaw UI, Pokedex, etc) e adequar a arquitetura
