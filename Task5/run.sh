#!/usr/bin/env bash
set -euo pipefail

echo "Создаем labels"
kubectl run front-end-app        --image=nginx --labels role=front-end        --port 80 --expose
kubectl run back-end-api-app    --image=nginx --labels role=back-end-api     --port 80 --expose
kubectl run admin-front-end-app --image=nginx --labels role=admin-front-end  --port 80 --expose
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --port 80 --expose

echo "Проверяем labels"
kubectl get pods -n sales --show-labels
kubectl get svc  -n sales

echo "Запрещаем всё"
kubectl apply -f deny-all.yaml

echo "Разрешаем только нужные пары"
kubectl apply -f non-admin-api-allow.yaml
