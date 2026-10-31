---
id: T-0019
title: LevelDirector — регистрация игрока и респавн по checkpoint_reset
status: claimed
form: infra
priority: high
owner: opencode
lease_until: 2026-10-31T21:39:28Z
branch: task/T-0019-level-director
paths:
  - scripts/LevelDirector.gd
depends_on: [T-0003, T-0004, T-0009]
created: 2026-10-31
---

## Контекст

`Obstacle` эмитит `checkpoint_reset`, но слушателя нет. `ShapeShiftManager.register_player` /
`last_checkpoint` / `set_checkpoint` есть, на уровнях не вызываются. Нужен общий скрипт директора
уровня (без правки `.tscn` в этой задаче — инстанс в T-0021…T-0023).

## Шаги

1. `scripts/LevelDirector.gd` — `extends Node`, `class_name LevelDirector`.
2. `@export` / `@onready` путь к игроку (`Player` / группа `player`); в `_ready`:
   `add_to_group` на игрока при необходимости, `ShapeShiftManager.register_player(player)`.
3. Найти все `Obstacle` в дереве (группа или `find_children`) и подписаться на `checkpoint_reset`.
4. Обработчик: перенести игрока на `ShapeShiftManager.last_checkpoint` (если нулевой —
   на `@export var spawn_point: Vector2` / Marker2D); сбросить velocity; не вызывать
   `reload_current_scene()`.
5. Опционально: Area2D/Marker чекпоинта через сигнал или метод `notify_checkpoint(pos)` —
   минимально достаточно читать/писать `set_checkpoint` при входе в именованные зоны, если
   зоны появятся позже; в этой задаче — API `set_checkpoint` + респавн.

## Acceptance criteria

- [ ] После `_ready` `ShapeShiftManager.get_player()` не null при наличии игрока в сцене
- [ ] `checkpoint_reset` телепортирует на чекпоинт без reload сцены
- [ ] Нет рекурсии при повторном входе в Obstacle (у Obstacle уже есть `_reset_pending`)

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Godot headless без SCRIPT/Parse Error

## Заметки и история
