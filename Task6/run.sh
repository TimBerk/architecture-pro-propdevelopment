#!/bin/bash
set -euo pipefail

echo "Подготовка политики"
mkdir -p ~/.minikube/files/etc/ssl/certs
cat <<EOF > ~/.minikube/files/etc/ssl/certs/audit-policy.yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    verbs: ["create", "delete", "update", "patch", "get", "list"]
    resources:
      - group: ""
        resources: ["pods", "secrets", "configmaps", "serviceaccounts", "roles", "rolebindings"]
  - level: Metadata
    resources:
      - group: ""
        resources: ["*"]
EOF

echo "Старт Minikube с указанием настроек"
MSYS_NO_PATHCONV=1 minikube start \
  --extra-config=apiserver.audit-policy-file=/etc/ssl/certs/audit-policy.yaml \
  --extra-config=apiserver.audit-log-path=-

echo "Проверка файла в Minikube с указанием настроек"
minikube ssh "sudo head -2 /etc/ssl/certs/audit-policy.yaml"

echo "Проверка работы кластера"
kubectl get nodes
