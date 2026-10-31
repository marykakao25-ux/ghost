---
id: T-0018
title: BreakableBox — ломаемая коробка для MovementDog
status: todo
form: dog
priority: high
owner: null
lease_until: null
branch: null
paths:
  - scripts/BreakableBox.gd
  - scenes/BreakableBox.tscn
depends_on: [T-0006, T-0009]
created: 2026-10-31
---

## Контекст

`MovementDog.check_obstacle_break` ломает тела из группы `breakable` с методом `break_apart()`.
`Obstacle.gd` — Area2D-сенсор форм/чекпоинта, не физическая коробка. Нужен отдельный узел.

Текстура: `assets/environment/tileset_spooky/box_to_dog.png` (не коммитить копии PNG — только ссылка).

## Шаги

1. `scripts/BreakableBox.gd` — `extends StaticBody2D` (или `AnimatableBody2D`), `class_name BreakableBox`.
2. В `_ready`: `add_to_group("breakable")`.
3. `break_apart()` — отключить коллизию, спрятать/очередить `queue_free()` (без рестарта сцены).
4. `scenes/BreakableBox.tscn` — Sprite2D + CollisionShape2D + скрипт.
5. Не править уровни (инстанс — T-0022) и не менять `MovementDog.gd` / `Obstacle.gd`.

## Acceptance criteria

- [ ] Узел в группе `breakable` и отвечает на `break_apart()`
- [ ] После ломания коллизия не блокирует игрока
- [ ] Сцена открывается в Godot без ошибок

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Godot headless / открытие `scenes/BreakableBox.tscn`

## Заметки и история
