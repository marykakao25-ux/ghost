---
id: T-0003
title: PlayerController — CharacterBody2D, делегирование формы, коллизии
status: done
form: infra
priority: high
owner: cursor
lease_until: 2026-10-31T18:45:36Z
branch: task/T-0003-player-controller
paths:
  - scripts/PlayerController.gd
  - scenes/Player.tscn
depends_on: [T-0002]
created: 2026-10-31
---

## Контекст

`scripts/PlayerController.gd` — заглушка (`extends Node`, 14 байт). По `README.md` это главный
менеджер игрока, но он должен быть `CharacterBody2D`, а не `Node`.

Сейчас в проекте вообще нет сцены игрока: ни одна из четырёх сцен не содержит `CharacterBody2D`
и не ссылается ни на один скрипт. Эта задача создаёт сцену игрока и контроллер.

## Шаги

1. Создать `scenes/Player.tscn`: `CharacterBody2D` (имя корня `Player`) с детьми
   `AnimatedSprite2D`, `CollisionShape2D`, `FormPivot` (Node2D для эффектов смены формы).
2. `scripts/PlayerController.gd` — `extends CharacterBody2D`, класс `class_name PlayerController`.
3. Поля: `current_form: Form` (enum `CAT/DOG/BIRD`), `current_movement: Node`,
   `@onready animated_sprite`, `@onready collision_shape`.
4. `_physics_process(delta)` делегирует в `current_movement.move(self, delta)`, если компонент задан,
   иначе применяет гравитацию по умолчанию.
5. `set_form(form)` переключает компонент движения (`MovementCat/Dog/Bird`) и размер коллизии
   (кот — маленький `CapsuleShape2D`, пёс — средний, ворон — `CircleShape2D`), сохраняя позицию ног
   (чтобы игрок не «телепортировался» при смене формы).
6. Никаких прямых обращений к узлам соседних сцен: только `get_node` к своим детям.

## Acceptance criteria

- [ ] `scenes/Player.tscn` открывается без ошибок, корень — `CharacterBody2D`
- [ ] `PlayerController.gd` парсится без ошибок и предупреждений
- [ ] Смена формы не проваливает игрока сквозь пол
- [ ] Скрипт не содержит `UI_*` действий

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . scenes/Player.tscn` — сцена запускается

## Заметки и история
- 2026-10-31T14:51:07Z — работа завершена владельцем cursor, ветка task/T-0003-player-controller, ожидает PR
