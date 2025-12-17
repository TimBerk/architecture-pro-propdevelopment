#!/usr/bin/env bash
set -euo pipefail

RBAC_DIR="./rbac"
if [ ! -d "${RBAC_DIR}" ]; then
  echo "Каталог ${RBAC_DIR} не найден. Создайте его и положите туда rbac-roles.yaml и rbac-bindings-*.yaml"
  exit 1
fi

echo "Создаем тестовый namespace sales"
kubectl create namespace sales

echo "Применяем ClusterRole и Role/ClusterRoleBinding манифесты из ${RBAC_DIR}..."

if [ -f "${RBAC_DIR}/rbac-roles.yaml" ]; then
  kubectl apply -f "${RBAC_DIR}/rbac-roles.yaml"
else
  echo "Файл ${RBAC_DIR}/rbac-roles.yaml не найден — пропускаем создание ролей."
fi

for f in "${RBAC_DIR}"/rbac-bindings-*.yaml; do
  if [ -f "$f" ]; then
    echo "Применяем биндинги: $f"
    kubectl apply -f "$f"
  fi
done

echo "RBAC манифесты применены."

echo "Проверка применения ролей."
kubectl get clusterrole | grep -E 'support|developer|devops|admins' || echo "Нет кастомных ClusterRole"
kubectl get clusterrolebinding | grep -E 'developers-cluster-binding|devops-cluster-binding|admins-cluster-binding' || echo "Нет кастомных ClusterRoleBinding"

echo "Проверка прав для пользователя alice"
# должно быть YES
kubectl --context=alice-context auth can-i get pods -n sales
kubectl --context=alice-context auth can-i list services -n sales

# должно быть NO
kubectl --context=alice-context auth can-i create pods -n sales
kubectl --context=alice-context auth can-i get secrets -n sales

echo "Проверка прав для пользователя alice"
# должно быть YES
kubectl --context=bob-context auth can-i create deployments.apps -n sales
kubectl --context=bob-context auth can-i delete pods -n sales

# должно быть NO
kubectl --context=bob-context auth can-i get secrets -n sales

