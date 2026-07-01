# GitHub Actions Setup

Este setup implementa o caminho de controle externo recomendado para a Autus:
GitHub Actions deve conseguir aplicar deploys no MicroK8s mesmo se
OpenClaw/Atomus estiver temporariamente offline.

## 1. Criar o repositorio

Repositorio recomendado:

```text
Autus-Solutions/autus-infra
```

Se estiver usando GitHub CLI:

```bash
gh repo create Autus-Solutions/autus-infra --private --source work_sessions/autus-infra --push
```

Sem GitHub CLI:

```bash
cd work_sessions/autus-infra
git init
git add .
git commit -m "feat: add reusable Autus Kubernetes CI/CD"
git branch -M main
git remote add origin git@github.com:Autus-Solutions/autus-infra.git
git push -u origin main
```

## 2. Configurar secrets no repo consumidor

Em cada repositorio de aplicacao que for fazer deploy:

GitHub Secret:

```text
KUBE_CONFIG
```

Conteudo:

```bash
microk8s config
```

Preferencialmente, gere um kubeconfig limitado ao namespace:

```bash
alias kubectl='microk8s kubectl'
./scripts/create-github-actions-kubeconfig.sh autus > /tmp/autus-kubeconfig.yaml
```

Use o conteudo de `/tmp/autus-kubeconfig.yaml` como `KUBE_CONFIG`.

Importante: `KUBE_CONFIG` tambem deve ser recuperavel de uma fonte externa ao cluster. O GitHub Secret e uma copia operacional para o CI; mantenha o kubeconfig bootstrap, tokens e credenciais de operador em 1Password ou outro vault. Para acesso SSH persistente do runtime ao GitHub, veja `docs/persistent-github-access.md`.

## 3. Configurar variables no GitHub Environment

Environment recomendado:

```text
production
```

Secret obrigatorio no Environment `production` para deploys:

```text
KUBE_CONFIG
```

Variables opcionais:

```text
KUBE_CONTEXT
INGRESS_CLASS_NAME=public
TLS_CLUSTER_ISSUER=letsencrypt-prod
```

## 4. Criar secrets no Kubernetes

Exemplo para uma API:

```bash
microk8s kubectl create namespace autus --dry-run=client -o yaml | microk8s kubectl apply -f -

microk8s kubectl create secret generic autus-api-secrets \
  -n autus \
  --from-literal=ConnectionStrings__Database='trocar' \
  --from-literal=ASPNETCORE_ENVIRONMENT='Production' \
  --dry-run=client -o yaml | microk8s kubectl apply -f -
```

ConfigMap opcional:

```bash
microk8s kubectl create configmap autus-api-config \
  -n autus \
  --from-literal=ASPNETCORE_URLS='http://+:8080' \
  --dry-run=client -o yaml | microk8s kubectl apply -f -
```

## 5. Instalar workflow no repo consumidor

Copie um exemplo de `examples/` para:

```text
.github/workflows/deploy.yml
```

Depois ajuste:

- `app_name`
- `namespace`
- `dockerfile`
- `container_port`
- `health_path`
- `ingress_hosts`
- `environment_name`

## 6. Validar deploy

```bash
microk8s kubectl get deploy,pod,svc,ingress -n autus
microk8s kubectl rollout status deployment/autus-api -n autus
microk8s kubectl logs -n autus deploy/autus-api --tail=200
```
