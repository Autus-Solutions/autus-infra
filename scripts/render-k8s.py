#!/usr/bin/env python3
from pathlib import Path
from string import Template
import os
import sys


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_DIR = ROOT / "k8s" / "templates"
OUTPUT_DIR = ROOT / "rendered"


def env(name, default=""):
    return os.environ.get(name, default)


def required(name):
    value = env(name)
    if not value:
        print(f"missing required environment variable: {name}", file=sys.stderr)
        sys.exit(2)
    return value


def render(template_name, destination_name, values):
    source = TEMPLATE_DIR / template_name
    destination = OUTPUT_DIR / destination_name
    content = Template(source.read_text()).safe_substitute(values)
    destination.write_text(content)
    print(destination)


def main():
    app_name = required("APP_NAME")
    namespace = required("NAMESPACE")
    image = required("IMAGE")
    container_port = required("CONTAINER_PORT")
    ingress_hosts = env("INGRESS_HOSTS")
    health_path = env("HEALTH_PATH", "/health")
    ingress_class_name = env("INGRESS_CLASS_NAME", "public")
    tls_cluster_issuer = env("TLS_CLUSTER_ISSUER")
    config_map_name = env("CONFIG_MAP_NAME", f"{app_name}-config")
    secret_name = env("SECRET_NAME", f"{app_name}-secrets")
    replicas = env("REPLICAS", "1")
    cpu_request = env("CPU_REQUEST", "100m")
    memory_request = env("MEMORY_REQUEST", "128Mi")
    cpu_limit = env("CPU_LIMIT", "1")
    memory_limit = env("MEMORY_LIMIT", "512Mi")

    OUTPUT_DIR.mkdir(exist_ok=True)
    for stale_file in OUTPUT_DIR.glob("*.yaml"):
        stale_file.unlink()

    values = {
        "APP_NAME": app_name,
        "NAMESPACE": namespace,
        "IMAGE": image,
        "CONTAINER_PORT": container_port,
        "HEALTH_PATH": health_path,
        "CONFIG_MAP_NAME": config_map_name,
        "SECRET_NAME": secret_name,
        "REPLICAS": replicas,
        "CPU_REQUEST": cpu_request,
        "MEMORY_REQUEST": memory_request,
        "CPU_LIMIT": cpu_limit,
        "MEMORY_LIMIT": memory_limit,
        "INGRESS_CLASS_NAME": ingress_class_name,
        "TLS_CLUSTER_ISSUER": tls_cluster_issuer,
        "TLS_ANNOTATION": f"cert-manager.io/cluster-issuer: {tls_cluster_issuer}" if tls_cluster_issuer else "",
        "FIRST_INGRESS_HOST": ingress_hosts.split(",")[0].strip() if ingress_hosts else "",
        "INGRESS_RULES": build_ingress_rules(ingress_hosts, app_name),
        "TLS_HOSTS": build_tls_hosts(ingress_hosts),
    }

    render("deployment.yaml.tpl", "deployment.yaml", values)
    if ingress_hosts:
        render("ingress.yaml.tpl", "ingress.yaml", values)


def build_ingress_rules(hosts, app_name):
    if not hosts:
        return ""
    blocks = []
    for host in [item.strip() for item in hosts.split(",") if item.strip()]:
        blocks.append(
            f"""  - host: "{host}"
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: {app_name}
              port:
                name: http"""
        )
    return "\n".join(blocks)


def build_tls_hosts(hosts):
    if not hosts:
        return ""
    return "\n".join(f'        - "{item.strip()}"' for item in hosts.split(",") if item.strip())


if __name__ == "__main__":
    main()
