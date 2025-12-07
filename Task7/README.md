# Задание 7. Аудит и обеспечение соответствия политике безопасности контейнеров (PSP / PodSecurity / OPA Gatekee

В кластере происходят развёртывания подов, которые нарушают требования безопасной конфигурации. Ваша задача — выявить такие случаи и организовать аудит.

## Что нужно сделать:

1. Создайте namespace audit-zone с уровнем PodSecurity restricted.
2. Разверните три манифеста с нарушениями в `insecure-manifests/`:
   * 01-privileged-pod.yaml — включает `privileged: true`.
   * 02-hostpath-pod.yaml — монтирует `hostPath`.
   * 03-root-user-pod.yaml — запускается от root (UID 0).
3. Убедитесь, что манифесты НЕ проходят валидацию в audit-zone (если всё верно, admission controller их заблокирует).
4. Исправьте манифесты, чтобы они соответствовали политике, сохраните в `secure-manifests/`.
5. Настройте OPA Gatekeeper с набором правил:
   * Нельзя использовать `privileged: true`.
   * Только `runAsNonRoot: true`.
   * `readOnlyRootFilesystem: true` обязательно.
   * `hostPath` запрещён.

Пример манифеста:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-privileged
  namespace: audit-zone
spec:
  containers:
    - name: nginx
      image: nginx
      securityContext:
        privileged: true
```

Аналогично — hostPath и UID 0.

## Как проверить самостоятельно:

* Политики работают — небезопасные поды отклоняются.
* Безопасные поды проходят валидацию.
* Gatekeeper активно применяет ограничения.
* PodSecurity Admission включён и действует.

Когда вы выполните задание, у вас должна получиться такая структура файлов:

```bash
Task7/
├── 01-create-namespace.yaml
├── insecure-manifests/
│   ├── 01-privileged-pod.yaml
│   ├── 02-hostpath-pod.yaml
│   └── 03-root-user-pod.yaml
├── secure-manifests/
│   ├── 01-secure.yaml
│   ├── 02-secure.yaml
│   └── 03-secure.yaml
├── gatekeeper/
│   ├── constraint-templates/
│   │   ├── privileged.yaml
│   │   ├── hostpath.yaml
│   │   └── runasnonroot.yaml
│   └── constraints/
│       ├── privileged.yaml
│       ├── hostpath.yaml
│       └── runasnonroot.yaml
├── verify/
│   ├── verify-admission.sh
│   └── validate-security.sh
├── README_FOR_REVIEWER.md
```
