# GitHub Actions Setup

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

Use uma service account com acesso limitado ao namespace do projeto quando possivel.

## 3. Configurar variables no GitHub Environment

Environment recomendado:

```text
production
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
microk8s kubectl create namespace autus-prod --dry-run=client -o yaml | microk8s kubectl apply -f -

microk8s kubectl create secret generic autus-api-secrets \
  -n autus-prod \
  --from-literal=ConnectionStrings__Database='trocar' \
  --from-literal=ASPNETCORE_ENVIRONMENT='Production' \
  --dry-run=client -o yaml | microk8s kubectl apply -f -
```

ConfigMap opcional:

```bash
microk8s kubectl create configmap autus-api-config \
  -n autus-prod \
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
microk8s kubectl get deploy,pod,svc,ingress -n autus-prod
microk8s kubectl rollout status deployment/autus-api -n autus-prod
microk8s kubectl logs -n autus-prod deploy/autus-api --tail=200
```

