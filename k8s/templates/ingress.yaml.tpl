apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${APP_NAME}
  namespace: ${NAMESPACE}
  labels:
    app.kubernetes.io/name: ${APP_NAME}
    app.kubernetes.io/part-of: autus-solutions
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "300"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "300"
    ${TLS_ANNOTATION}
spec:
  ingressClassName: ${INGRESS_CLASS_NAME}
  rules:
${INGRESS_RULES}
  tls:
    - hosts:
${TLS_HOSTS}
      secretName: ${APP_NAME}-tls

