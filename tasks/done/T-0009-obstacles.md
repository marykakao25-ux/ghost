---
id: T-0009
title: Препятствия и чекпоинты (Obstacle.gd)
status: done
form: infra
priority: medium
owner: opencode
lease_until: 2026-10-31T21:10:59Z
branch: task/T-0009-obstacles
paths:
  - scripts/Obstacle.gd
  - scenes/Obstacle.tscn
depends_on: [T-0003]
created: 2026-10-31
---

## Контекст

`scripts/Obstacle.gd` — заглушка. По `README.md` это общий скрипт препятствий (коробки, брёвна,
скамейки, лужи, ветки): `obstacle_type: Enum(CRAWL_UNDER, JUMP_OVER, FLY_AROUND, HAZARD)` и возврат
на чекпоинт при неправильном взаимодействии.

Ассеты для препятствий уже есть: `assets/environment/tileset_spooky/` — `box_to_cat.png`,
`box_to_dog.png`, `log.png`, `bench.png`, `branch.png`, `puddle.png`, `pit.png`, `lantern.png`,
`grass.png`, `grass_to_dog.png`, `tile.png`, `air.png`.

## Шаги

1. `Obstacle.gd` — `extends Area2D`, `class_name Obstacle`, экспортируемые `obstacle_type: ObstacleType`
   и `allowed_forms: Array[String]`.
2. Сигнал `checkpoint_reset(reason: String)`; сам рестарт уровня выполняет менеджер, а не препятствие.
3. `_on_body_entered(body)` — если форма тела не входит в `allowed_forms`, эмитит сигнал
   (для `HAZARD` — всегда).
4. `scenes/Obstacle.tscn` — базовый переиспользуемый узел с `CollisionShape2D`.
5. Никаких прямых вызовов `get_tree().reload_current_scene()` из скрипта препятствия.

## Acceptance criteria

- [ ] Препятствие реагирует только на «неправильную» форму
- [ ] `HAZARD` срабатывает всегда
- [ ] Рестарт не вызывает рекурсии сигналов

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`

## Заметки и история
- 2026-10-31T17:14:05Z — работа завершена владельцем opencode, ветка task/T-0009-obstacles, ожидает PR
