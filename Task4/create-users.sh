#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="./keys"
mkdir -p "${OUT_DIR}"

# 1. ключи
openssl genrsa -out "${OUT_DIR}/alice.key" 2048
openssl genrsa -out "${OUT_DIR}/bob.key"   2048

# 2. CSR (запусти это НЕ в Git Bash, а в cmd/PowerShell, либо с MSYS_NO_PATHCONV=1)
MSYS_NO_PATHCONV=1 openssl req -new -key "${OUT_DIR}/alice.key" -out "${OUT_DIR}/alice.csr" \
  -subj "/CN=alice/O=grp-support"

MSYS_NO_PATHCONV=1 openssl req -new -key "${OUT_DIR}/bob.key" -out "${OUT_DIR}/bob.csr" \
  -subj "/CN=bob/O=grp-developers"

# 3. подписать CA minikube
MINIKUBE_DIR="$HOME/.minikube"
CA_CERT="${MINIKUBE_DIR}/ca.crt"
CA_KEY="${MINIKUBE_DIR}/ca.key"

openssl x509 -req -in "${OUT_DIR}/alice.csr" -CA "${CA_CERT}" -CAkey "${CA_KEY}" \
  -CAcreateserial -out "${OUT_DIR}/alice.crt" -days 365

openssl x509 -req -in "${OUT_DIR}/bob.csr" -CA "${CA_CERT}" -CAkey "${CA_KEY}" \
  -CAcreateserial -out "${OUT_DIR}/bob.crt" -days 365

# 4. завести users в kubeconfig
kubectl config set-credentials alice \
  --client-certificate="${OUT_DIR}/alice.crt" \
  --client-key="${OUT_DIR}/alice.key" \
  --embed-certs=true

kubectl config set-credentials bob \
  --client-certificate="${OUT_DIR}/bob.crt" \
  --client-key="${OUT_DIR}/bob.key" \
  --embed-certs=true

# 5. связать с АКТУАЛЬНЫМ кластером minikube
CLUSTER_NAME=$(kubectl config view -o jsonpath='{.contexts[?(@.name=="minikube")].context.cluster}')

kubectl config set-context alice-context \
  --cluster="${CLUSTER_NAME}" \
  --user=alice

kubectl config set-context bob-context \
  --cluster="${CLUSTER_NAME}" \
  --user=bob

echo "alice/bob и контексты alice-context/bob-context созданы."
