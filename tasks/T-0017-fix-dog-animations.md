---
id: T-0017
title: MovementDog — анимации через preload anim_dog_*.tscn (как у кота)
status: claimed
form: dog
priority: high
owner: opencode
lease_until: 2026-10-31T21:35:01Z
branch: task/T-0017-fix-dog-animations
paths:
  - scripts/MovementDog.gd
depends_on: [T-0006, T-0010]
created: 2026-10-31
---

## Контекст

`MovementDog._update_animation` ищет имена `dog_idle` / `dog_run` / `dog_jump_high` в
`player.animated_sprite.sprite_frames`. У ассетов T-0010 анимация внутри `SpriteFrames`
называется `default` (как у кота). В итоге пёс не переключает кадры.

Эталон: `scripts/MovementCat.gd` — preload `anim_cat_*.tscn`, подмена `sprite_frames`, `play("default")`.

## Шаги

1. Preload `anim_dog_idle.tscn`, `anim_dog_run.tscn`, `anim_dog_jump_high.tscn`.
2. Кэш `SpriteFrames` при `_ready` / первом `move`.
3. Переключать пакеты по состоянию (idle / run / jump), не полагаясь на имена внутри frames.
4. `flip_h` по знаку `velocity.x` сохранить.
5. Не трогать PNG и `.tscn` ассетов (вне `paths`).

## Acceptance criteria

- [ ] При беге/прыжке/простое подставляются соответствующие `anim_dog_*.tscn`
- [ ] Нет ошибок, если спрайт временно null
- [ ] Diff только `scripts/MovementDog.gd`

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Godot headless `--quit` без SCRIPT/Parse Error

## Заметки и история
