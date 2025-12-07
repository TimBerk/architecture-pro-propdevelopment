#!/usr/bin/env bash
set -euo pipefail

NS="audit-zone"

echo "== Проверка Gatekeeper =="

echo "-- Установка ConstraintTemplates..."
kubectl apply -f gatekeeper/constraint-templates/

echo "-- Установка Constraints..."
kubectl apply -f gatekeeper/constraints/

echo "-- Проверка: небезопасные поды должны быть отклонены Gatekeeper..."
set +e
kubectl apply -n "${NS}" -f insecure-manifests/01-privileged-pod.yaml
kubectl apply -n "${NS}" -f insecure-manifests/02-hostpath-pod.yaml
kubectl apply -n "${NS}" -f insecure-manifests/03-root-user-pod.yaml
set -e

echo "-- Проверка: безопасные поды должны успешно создаваться..."
kubectl apply -n "${NS}" -f secure-manifests/
