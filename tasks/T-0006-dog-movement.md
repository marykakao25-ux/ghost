---
id: T-0006
title: Пёс — скорость, высокий прыжок, ломание коробок (MovementDog)
status: claimed
form: dog
priority: medium
owner: opencode
lease_until: 2026-10-31T20:56:44Z
branch: task/T-0006-dog-movement
paths:
  - scripts/MovementDog.gd
depends_on: [T-0003]
created: 2026-10-31
---

## Контекст

`scripts/MovementDog.gd` — заглушка. Пёс — форма скорости и прыгучести: разгон с инерцией,
высокий прыжок, разрушение деревянных коробок на скорости.

Спрайтов пса в репозитории **нет** (каталога `assets/sprites/dog/` не существует) — работа над
графикой вынесена в T-0010. До появления ассетов использовать заглушку-плейсхолдер, не коммитить
временные PNG в этот каталог (это компетенция T-0010; здесь `paths` их не покрывает).

## Шаги

1. `extends Node`, `class_name MovementDog`.
2. Константы: `SPEED`, `JUMP_VELOCITY`, `ACCELERATION`, `DECELERATION`, `GRAVITY`, `BREAK_SPEED`.
3. `move(player, delta)` — разгон с инерцией, прыжок, сохранение переопределённой гравитации для
   «тяжёлого» падения.
4. `check_obstacle_break()` — по сигналу столкновения с телом группы `breakable` проверяет
   `abs(velocity.x) >= BREAK_SPEED` и вызывает `body.break_apart()`; объекты без такого метода игнорируются.
5. Анимации: `dog_idle`, `dog_run`, `dog_jump_high` — брать через `player.animated_sprite`,
   проверять их наличие, чтобы отсутствие ассетов не давало ошибок в консоли.

## Acceptance criteria

- [ ] Пёс разгоняется и прыгает выше кота
- [ ] Коробки ломаются только выше `BREAK_SPEED`
- [ ] Отсутствие спрайтов пса не вызывает ошибок выполнения

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Проверка в сцене `scenes/Level_Dog_Park.tscn`

## Заметки и история
