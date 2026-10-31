---
id: T-0015
title: Синхронизировать README/ARCHITECTURE/INPUT_MAP с фактом репозитория
status: claimed
form: docs
priority: high
owner: opencode
lease_until: 2026-10-31T21:29:01Z
branch: task/T-0015-docs-sync-architecture
paths:
  - docs/ARCHITECTURE.md
  - docs/INPUT_MAP.md
  - README.md
depends_on: []
created: 2026-10-31
---

## Контекст

T-0001…T-0014 закрыты: скрипты реализованы, input map есть, `main_scene` = MainMenu,
ассеты dog/bird/gg на месте. Документы всё ещё описывают «заглушки», «нет [input]»,
«нет спрайтов пса/ворона» и устаревшую главную сцену. Агенты и люди читают ложь.

## Шаги

1. `docs/ARCHITECTURE.md` — таблица «Что реализовано»: скрипты, Player.tscn, шейдер,
   Obstacle, WindZone, формы-ассеты; явно отметить, что **уровни ещё не играбельны**
   (нет Player/коллизий на сценах) — это закрывают T-0021…T-0023.
2. `docs/INPUT_MAP.md` — убрать «секции [input] нет»; сверить таблицу действий с `project.godot`.
3. `README.md` — блок «Текущее состояние» и «Быстрый старт» (F5 → MainMenu); структура
   проекта: dog/, bird/, shaders/, Obstacle.tscn; не обещать готовый геймплей уровней.
4. Не менять `project.godot` и сцены.

## Acceptance criteria

- [ ] ARCHITECTURE отражает факт кода (не «все 8 — заглушки»)
- [ ] INPUT_MAP не утверждает отсутствие input map
- [ ] README согласован с ARCHITECTURE; противоречий «верьте README» нет

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Diff только по трём файлам из `paths`

## Заметки и история
