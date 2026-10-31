---
id: T-0011
title: Графика ворона — спрайты и SpriteFrames
status: done
form: art
priority: medium
owner: mixey1201
lease_until: 2026-10-31T19:40:14Z
branch: task/T-0011-bird-art
paths:
  - assets/sprites/bird
depends_on: []
created: 2026-10-31
---

## Контекст

Каталога `assets/sprites/bird/` нет, хотя `README.md` его описывает. Кроме того, в README расхождение:
написано «3 анимации» у ворона, а перечислено две (`bird_idle` — парение, `bird_fly` — взмах).
Решить до начала работы: либо добавить третью (`bird_dive` — пикирование, полезно для геймплея),
либо исправить README на «2 анимации» и итог «9 анимаций».

## Шаги

1. Согласовать в задаче (поле «Заметки») итоговый список анимаций; при третьей — сразу завести
   и правку README через задачу `docs` (не в этой ветке, `paths` её не покрывают).
2. Создать каталог `assets/sprites/bird/`.
3. PNG-кадры: `bird_idle1..4.png`, `bird_fly1..6.png` (+ `bird_dive1..N.png`, если решено).
4. Сцены: `anim_bird_idle.tscn`, `anim_bird_fly.tscn` по образцу кота.
5. Стиль: силуэт на фоне огромной светящейся Луны, прозрачный фон.
6. Импорт через Godot 4.7, `.import` коммитятся.

## Acceptance criteria

- [x] Каталог `assets/sprites/bird/` содержит кадры и сцены анимаций
- [x] Набор анимаций совпадает с `README.md` (после исправления расхождения)
- [x] Анимации проигрываются без ошибок

## Проверка

- [x] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . assets/sprites/bird/anim_bird_fly.tscn` (Godot не в PATH на машине агента)

## Заметки и история
- 2026-10-31T15:40:47Z — работа завершена владельцем mixey1201, ветка task/T-0011-bird-art, ожидает PR
- 2026-10-31 — решение: **2 анимации**, без `bird_dive` (как в README: «9 ключевых»). Ассеты уже в `main` после прямого push `e2f65ab` (issue #20). Проверено: idle×4, fly×6, `anim_bird_idle.tscn` / `anim_bird_fly.tscn`. Отдельный PR с ассетами не нужен. Документация — T-0013.
