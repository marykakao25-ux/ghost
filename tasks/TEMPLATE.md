---
id: T-0000
title: Краткое название задачи в одну строку
status: todo            # todo | claimed | in-progress | review | done | blocked
form: infra             # cat | dog | bird | infra | art | audio | docs
priority: medium        # high | medium | low
owner: null             # кто взял задачу (заполняется скриптом claim.ps1)
lease_until: null       # ISO-8601 UTC, ставится автоматически, TTL 4 часа
branch: null            # ветка работы, например task/T-0000-short-name
paths:                  # КОНТРАКТ: задача имеет право менять ТОЛЬКО эти пути
  - docs/example.md
depends_on: []          # id задач, которые должны быть done до начала этой
created: 2026-01-01
---

## Контекст

Зачем нужна задача и на что она опирается. Ссылки на README.md, docs/ARCHITECTURE.md,
номера строк, скриншоты. Агент должен понять задачу ТОЛЬКО из этого файла.

## Шаги

1. ...
2. ...

## Acceptance criteria

- [ ] Наблюдаемый результат 1
- [ ] Наблюдаемый результат 2
- [ ] Проект открывается в Godot 4.7 без ошибок парсинга и без новых предупреждений

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1` — зелёный
- [ ] Сцена запускается: `godot --path . scenes/<scene>.tscn` (если применимо)

## Заметки и история

<!-- Сюда агент дописывает ход работы: что сделано, что осталось, что заблокировало. -->
