#!/usr/bin/env bash
set -euo pipefail

NS="audit-zone"

echo "== Проверка PodSecurity restricted в namespace ${NS} =="

kubectl apply -f 01-create-namespace.yaml

echo "-- Пытаемся применить небезопасные манифесты (должны быть отклонены PodSecurity Admission)..."
set +e
kubectl apply -n "${NS}" -f insecure-manifests/01-privileged-pod.yaml
kubectl apply -n "${NS}" -f insecure-manifests/02-hostpath-pod.yaml
kubectl apply -n "${NS}" -f insecure-manifests/03-root-user-pod.yaml
set -e

echo "-- Применяем безопасные манифесты (должны создаться успешно)..."
kubectl apply -n "${NS}" -f secure-manifests/
