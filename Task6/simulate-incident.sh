#!/bin/bash
set -euo pipefail

kubectl create ns secure-ops 2>/dev/null || true
kubectl config set-context --current --namespace=secure-ops

kubectl create sa monitoring 2>/dev/null || true
kubectl run attacker-pod --image=alpine --command -- sleep 3600 2>/dev/null || true

kubectl auth can-i get secrets --as=system:serviceaccount:secure-ops:monitoring || true

kubectl get secret -n kube-system \
  "$(kubectl get secrets -n kube-system | grep default-token | head -n1 | awk '{print $1}')" \
  --as=system:serviceaccount:secure-ops:monitoring 2>/dev/null || true

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
  namespace: secure-ops
spec:
  containers:
  - name: pwn
    image: alpine
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
  restartPolicy: Never
EOF

kubectl exec attacker-pod -- sh -c "cat /etc/os-release >/dev/null 2>&1 || echo exec-test" || true

kubectl -n kube-system delete configmap kube-root-ca.crt --as=admin 2>/dev/null || true

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: escalate-binding
  namespace: secure-ops
subjects:
- kind: ServiceAccount
  name: monitoring
  namespace: secure-ops
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF

echo "Подготовка логов"
minikube logs | grep "audit.k8s.io/v1" > audit.log

echo "Аудит логов"
python filter-audit.py