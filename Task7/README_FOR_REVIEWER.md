# README_FOR_REVIEWER

## Шаг 1. Namespace и PodSecurity Admission

1. Применить namespace и метки Pod Security Standards:
    ```bash
    kubectl apply -f 01-create-namespace.yaml
    ```
2. Проверить наличие меток:
    ```bash
    kubectl get ns audit-zone --show-labels
    ```

Ожидается, что у namespace `audit-zone` будут лейблы `pod-security.kubernetes.io/enforce=restricted` и соответствующая версия, что включает PodSecurity Admission на уровне namespace.


## Шаг 2. Проверка PodSecurity Admission (verify-admission.sh)

1. Запустить скрипт:
    ```bash
    bash verify/verify-admission.sh
    ```
2. Ожидаемое поведение:
    - Применение манифестов из `insecure-manifests/` в `audit-zone` приводит к ошибкам валидации (privileged, hostPath, UID 0 — нарушают профиль `restricted`).
    - Применение манифестов из `secure-manifests/` проходит успешно, Pod’ы создаются.

Таким образом видно, что PodSecurity Admission корректно блокирует небезопасные конфигурации на уровне namespace.


## Шаг 3. Установка и проверка Gatekeeper

1. Установить Gatekeeper в кластер (по официальной инструкции).
    ```bash
    kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/v3.16.0/deploy/gatekeeper.yaml
    kubectl -n gatekeeper-system get pods
    ```
2. Применить шаблоны ограничений:
    ```bash
    kubectl apply -f gatekeeper/constraint-templates/
    ```
3. Применить сами ограничения:
    ```bash
    kubectl apply -f gatekeeper/constraints/
    ```

Шаблоны описывают Rego‑правила, а Constraints включают их для namespace `audit-zone`.


## Шаг 4. Проверка Gatekeeper (validate-security.sh)

1. Запустить скрипт:
   ```bash
   bash verify/validate-security.sh
   ```
2. Ожидаемое поведение:
    - Манифесты из `insecure-manifests/` в `audit-zone` отклоняются уже Gatekeeper’ом, даже если они прошли бы PodSecurity (например, в другом namespace).
    - Манифесты из `secure-manifests/` успешно создаются, т. к. удовлетворяют:
        - `securityContext.privileged: false` (или отсутствует),
        - отсутствию `hostPath`,
        - `runAsNonRoot: true`,
        - `readOnlyRootFilesystem: true`.

Gatekeeper реализует дополнительные политики, поверх PodSecurity Admission.