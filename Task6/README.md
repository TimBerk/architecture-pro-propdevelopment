# Задание 6. Аудит активности пользователей и обнаружение инцидентов

Вам необходимо настроить аудит активности пользователей, чтобы своевременно обнаруживать аномалии, попытки несанкционированного доступа и другие угрозы.

## Что нужно сделать

**Шаг 1**. Настройте среду Minikube с включённым audit-policy.yaml и экспортом лога (/var/log/audit.log).

☝️Конфигурации нужно подключить «снаружи».
Minikube не поддерживает прямое редактирование kube-apiserver.yaml в minikube ssh, потому что этот файл генерируется динамически и изменения «затираются». Правильный способ — настроить файл конфигурации на хостовой машине, «примонтировать» папку с файлом конфигурации и с помощью флага --extra-configв команде minikube start подключить папку. 

```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  - level: RequestResponse
    verbs: \["create", "delete", "update", "patch", "get", "list"\]
    resources:
      - group: ""
        resources: \["pods", "secrets", "configmaps", "serviceaccounts", "roles", "rolebindings"\]
  - level: Metadata
    resources:
      - group: "\*"
        resources: \["\*"\] 
```

**Шаг 2**. Запустите скрипт симуляции действий.

```bash
bash simulate-incident.sh
```

Скрипт выполняет следующие действия:
* Доступ к secrets от system:serviceaccount:monitoring.
* Создание привилегированного пода.
* Использование kubectl exec в чужом поде.
* Удаление audit-policy.
* Создание RoleBinding без согласования.

```bash
#!/bin/bash

kubectl create ns secure-ops
kubectl config set-context --current --namespace=secure-ops

kubectl create sa monitoring
kubectl run attacker-pod --image=alpine --command -- sleep 3600
kubectl auth can-i get secrets --as=system:serviceaccount:secure-ops:monitoring

kubectl get secret -n kube-system $(kubectl get secrets -n kube-system | grep default-token | head -n1 | awk '{print $1}') --as=system:serviceaccount:secure-ops:monitoring

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: privileged-pod
spec:
  containers:
  - name: pwn
    image: alpine
    command: ["sleep", "3600"]
    securityContext:
      privileged: true
  restartPolicy: Never
EOF

kubectl exec -n kube-system $(kubectl get pods -n kube-system | grep coredns | awk '{print $1}' | head -n1) -- cat /etc/resolv.conf

kubectl delete -f /etc/kubernetes/audit-policy.yaml --as=admin

cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: escalate-binding
subjects:
- kind: ServiceAccount
  name: monitoring
  namespace: secure-ops
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
EOF
```

**Шаг 3**. Проведите анализ `audit.log`.

Найдите и распишите:
* Кто инициировал каждое из действий.
* Какие действия могли быть вредоносными.
* Что можно считать компрометацией кластера.
* Какие ошибки допускает политика RBAC.

Для анализа подготовьте скрипт.

На проверку вам нужно передать три артефакта:

1. `analysis.md`: краткий отчёт по выявленным событиям.

    ```md
    Шаблон отчёта:
    # Отчёт по результатам анализа Kubernetes Audit Log
    
    ## Подозрительные события
    
    1. Доступ к секретам:
       - Кто: ...
       - Где: ...
       - Почему подозрительно: ...
    
    2. Привилегированные поды:
       - Кто: ...
       - Комментарий: ...
    
    3. Использование kubectl exec в чужом поде:
       - Кто: ...
       - Что делал: ...
    
    4. Создание RoleBinding с правами cluster-admin:
       - Кто: ...
       - К чему привело: ...
    
    5. Удаление audit-policy.yaml:
       - Кто: ...
       - Возможные последствия: ...
    
    ## Вывод
    
    ...
    ```

2. `audit-extract.json`: выжимка из `audit.log`, содержащая подозрительные события.
3. Скрипт фильтрации `audit.log`, написанный на Bash или Python.

## Как проверить самостоятельно

1. Проверка на события доступа к secrets:

    ```bash
    jq 'select(.objectRef.resource=="secrets" and .verb=="get")' audit.log 
    ```

2. Проверка на kubectl exec в чужие поды:

    ```bash
    jq 'select(.verb=="create" and .objectRef.subresource=="exec")' audit.log 
    ```

3. Привилегированные поды:

    ```bash
    jq 'select(.objectRef.resource=="pods" and .requestObject.spec.containers[].securityContext.privileged==true)' audit.log 
    ```

4. Удаление или изменение audit policy:

    ```bash
    grep -i 'audit-policy' audit.log
    ```

Когда вы выполните задание, у вас должно получиться три файла: `analysis.md` — краткий отчёт по выявленным событиям, `audit-extract.json` — выжимка из `audit.log` с подозрительными событиями и скрипт фильтрации `audit.log` на Bash или Python.

# Отчёт по результатам анализа Kubernetes Audit Log

При использовании стандартного bash-скрипта - любые логи отсутствуют. Пришлось изменить скрипт под использование в ОС - Windows.

Для запуска кластера используется скрипт: `run.sh`.

### Подозрительные события

1. Доступ к секретам:
    - Кто: в приведённом фрагменте логов событий с ресурсом `secrets` нет, поэтому по этим данным доступ к секретам не зафиксирован.
    - Где: N/A — обращения к `secrets` в данном срезе audit log отсутствуют.
    - Почему подозрительно: при появлении событий `verb: "get"` и `resource: "secrets"` от сервисных аккаунтов прикладных namespace (например, `system:serviceaccount:secure-ops:monitoring`) такие действия следует считать подозрительными, так как это попытка прочитать чувствительные данные, часто за пределами своего namespace.
2. Привилегированные поды:
    - Кто: пользователь `minikube-user`, входящий в группы `system:masters` и `system:authenticated`. Создал pod `privileged-pod` в namespace `secure-ops` с контейнером `pwn`, у которого в `spec.containers[].securityContext.privileged` установлено значение `true`.
    - Комментарий: создание привилегированного pod’а даёт контейнеру доступ к ресурсам хост-узла и фактически снимает значительную часть изоляции, что позволяет выполнять операции на уровне ноды и использовать pod для дальнейшей эскалации привилегий или закрепления в кластере. Такие действия допустимы только для строго ограниченного админского контекста и должны триггерить алерты.
3. Использование kubectl exec в чужом поде:
    - Кто: в предоставленном фрагменте audit log нет событий с `objectRef.subresource: "exec"`, поэтому фактическое использование `kubectl exec` по этим данным не зафиксировано.
    - Что делал: N/A — для `exec` в audit log обычно видно `verb: "create"`, `resource: "pods"`, `subresource: "exec"` и команду, запускаемую внутри контейнера, что позволяет отследить интерактивный доступ внутрь pod’а и возможные попытки обхода стандартного мониторинга.
4. Создание RoleBinding с правами cluster-admin:
    - Кто: в предоставленном срезе логов нет событий с `resource: "rolebindings"` и `requestObject.roleRef.name: "cluster-admin"`, поэтому само создание эскалирующего RoleBinding здесь не видно.
    - К чему привело: в общем случае создание `RoleBinding`, который связывает сервисный аккаунт (например, `monitoring` в `secure-ops`) с `ClusterRole/cluster-admin`, приводит к тому, что этот сервисный аккаунт получает полный административный доступ ко всем ресурсам кластера, что считается критической ошибкой RBAC и прямой эскалацией привилегий.
5. Удаление audit-policy.yaml:
    - Кто: пользователь `minikube-user`, действующий через `--as=admin` (в поле `impersonatedUser` указан `username: "admin"`), инициировал операцию `delete` ресурса `configmaps/kube-root-ca.crt` в namespace `kube-system`.
    - Возможные последствия: хотя здесь удаляется `ConfigMap kube-root-ca.crt`, а не сама audit‑policy, подобные операции с критичными объектами в `kube-system` при выполнении от имени `admin` создают риск нарушения базовых механизмов безопасности (root CA, политика аудита и т. п.), могут привести к потере доверенной цепочки сертификатов или отключению/ослаблению аудита и часто используются как шаг по сокрытию следов после эскалации.

### Вывод

В анализируемом фрагменте audit log чётко зафиксировано создание привилегированного pod’а `privileged-pod` в namespace `secure-ops` пользователем с правами `system:masters`, а также попытка удаления критичного `ConfigMap` в `kube-system` от имени `admin`, что указывает на высокую степень привилегий и потенциальную эскалацию до уровня управления системными компонентами.  Даже при отсутствии в этом срезе явных событий `exec` и `RoleBinding/cluster-admin`, комбинация привилегированного pod’а и операций удаления конфигурации в `kube-system` уже свидетельствует о высоком риске компрометации кластера и требует немедленного пересмотра RBAC‑политик, ограничения создания привилегированных pod’ов и усиления контроля за операциями администраторов.