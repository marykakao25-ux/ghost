---
id: T-0005
title: Кот — физика движения и подползание (MovementCat)
status: claimed
form: cat
priority: high
owner: mixey1201
lease_until: 2026-10-31T20:31:38Z
branch: task/T-0005-cat-movement
paths:
  - scripts/MovementCat.gd
depends_on: [T-0003]
created: 2026-10-31
---

## Контекст

`scripts/MovementCat.gd` — заглушка (`extends Node`). По `README.md` это компонент физики кота:
бег, прыжок, подползание. Анимации кота уже есть: `assets/sprites/cat/anim_cat_idle.tscn`,
`anim_cat_walk.tscn`, `anim_cat_crawling.tscn`, `anim_cat_jump.tscn` (у каждой — свой `SpriteFrames`).
Строковые имена анимаций внутри `SpriteFrames` см. в этих сценах.

## Шаги

1. `extends Node`, `class_name MovementCat`.
2. Константы: `SPEED`, `JUMP_VELOCITY`, `CRAWL_SPEED`, `ACCELERATION`, `FRICTION`, `GRAVITY`.
3. `move(player: CharacterBody2D, delta: float)` — горизонтальное ускорение/трение, `is_on_floor()`,
   прыжок по `Input.is_action_just_pressed("jump")`.
4. `crawl()` — при удержании `crawl` высота коллизии уменьшается вдвое, скорость — `CRAWL_SPEED`,
   включается анимация подползания. При отпускании — проверка `player.test_move()` на место над головой:
   нельзя встать под низким препятствием.
5. `play_anim(name)` — переключение `SpriteFrames` с проверкой `sprite_frames.has_animation()`.
6. `apply_night_vision()` — **не здесь**: вынести в T-0008 (`GhostVisionShader`), эта задача только
   выставляет флаг `night_vision_enabled`.

## Acceptance criteria

- [ ] Кот бегает, прыгает, подползает под препятствием и не застревает
- [ ] Нельзя встать, стоя под низким проходом
- [ ] Скрипт использует действия `move_left/right`, `jump`, `crawl` (см. `docs/INPUT_MAP.md`)
- [ ] Нет `UI_*` действий

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Проверка в сцене `Level_Cat_Cemetry.tscn`

## Заметки и история
