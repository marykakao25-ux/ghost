---
id: T-0013
title: Документировать ассеты dog/bird/gg/location в docs/ASSETS.md
status: todo
form: docs
priority: medium
owner: null
lease_until: null
branch: null
paths:
  - docs/ASSETS.md
depends_on: []
created: 2026-10-31
---

## Контекст

После прямого push `e2f65ab` (issue #20) в `main` лежат ассеты пса, ворона, `assets/sprites/gg/`
и маркеры `*_location.png` в `halloween_props`, но строк в `docs/ASSETS.md` нет. Правило файла:
каждый ассет должен быть в таблице. T-0010/T-0011 закрыты по содержимому; документация — эта задача.

## Шаги

1. Добавить в таблицу «Текущие ассеты» строки для:
   - `assets/sprites/dog/*.png` и `anim_dog_*.tscn`
   - `assets/sprites/bird/*.png` и `anim_bird_*.tscn`
   - `assets/sprites/gg/*.png`
   - `assets/environment/halloween_props/{cat,dog,bird}_location.png`
2. В «Структура, требуемая задачей» отметить T-0010/T-0011 как выполненные (2 анимации у ворона).
3. Источник: внутренняя графика команды (как у cat), если иное не известно.

## Acceptance criteria

- [ ] Все новые пути из `e2f65ab` описаны в таблице ASSETS.md
- [ ] Секция «Структура, требуемая задачей» согласована с закрытыми T-0010/T-0011
- [ ] `pwsh -File scripts/agent/verify.ps1` зелёный

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`

## Заметки и история
