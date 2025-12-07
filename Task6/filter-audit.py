#!/usr/bin/env python3
import json
import sys
from pathlib import Path


def is_suspicious(event: dict) -> bool:
    verb = event.get('verb')
    obj = event.get('objectRef') or {}
    req = event.get('requestObject') or {}
    resource = obj.get('resource')
    subresource = obj.get('subresource')
    namespace = obj.get('namespace', '')
    name = obj.get('name', '')

    # 1. Доступ к секретам (get secrets)
    if resource == 'secrets' and verb == 'get':
        return True

    # 2. kubectl exec (subresource=exec)
    if verb == 'create' and subresource == 'exec':
        return True

    # 3. Привилегированные pod'ы (privileged: true в spec.containers[].securityContext)
    if resource == 'pods':
        spec = req.get('spec') or {}
        containers = spec.get('containers') or []
        for c in containers:
            sc = c.get('securityContext') or {}
            if sc.get('privileged') is True:
                return True

    # 4. RoleBinding, дающий cluster-admin
    if resource == 'rolebindings':
        role_ref = req.get('roleRef') or {}
        if role_ref.get('name') == 'cluster-admin':
            return True

    # 5. Удаление / изменение политики аудита или критичной конфигурации
    if verb in ('delete', 'update', 'patch'):
        if 'audit-policy' in str(name):
            return True
        if resource == 'configmaps' and namespace == 'kube-system':
            return True

    return False


def main():
    audit_path = Path(sys.argv[1] if len(sys.argv) > 1 else 'audit.log')
    out_path = Path(sys.argv[2] if len(sys.argv) > 2 else 'audit-extract.json')

    if not audit_path.is_file():
        print(f'Файл {audit_path} не найден', file=sys.stderr)
        sys.exit(1)

    result = []

    with audit_path.open('r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue

            if is_suspicious(event):
                result.append(event)

    with out_path.open('w', encoding='utf-8') as out:
        json.dump(result, out, ensure_ascii=False, indent=2)

    print(f'Подозрительные события сохранены в {out_path}')


if __name__ == '__main__':
    main()
