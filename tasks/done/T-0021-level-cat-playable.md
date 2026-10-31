---
id: T-0021
title: Играбельный уровень кота — пол, Player, Obstacle, зрение, LevelDirector
status: done
form: cat
priority: high
owner: mixey1201
lease_until: 2026-10-31T21:56:31Z
branch: task/T-0021-level-cat-playable
paths:
  - scenes/Level_Cat_Cemetry.tscn
depends_on: [T-0019, T-0020, T-0005, T-0008, T-0009]
created: 2026-10-31
---

## Контекст

`Level_Cat_Cemetry.tscn` — декоративные `Sprite2D` тайлов + музыка, без коллизий и без игрока.
После T-0019/T-0020 можно собрать минимальный проходимый отрезок: пол, Player, препятствия
подползания, шейдер ночного зрения, директор с чекпоинтом.

Имя файла с опечаткой Cemetry **не переименовывать** (uid/ссылки MainMenu).

## Шаги

1. Добавить collidable пол (`StaticBody2D` + shapes) под существующими тайлами или заменить
   ряд на физический пол с теми же текстурами.
2. Инстанс `scenes/Player.tscn`; спавн над полом; форма по умолчанию CAT.
3. Узел со скриптом `LevelDirector` (T-0019); задать spawn/checkpoint.
4. 1–2 `Obstacle` (CRAWL_UNDER, allowed cat) + опционально HAZARD (лужа/яма из тайлов).
5. Инстанс/узел `GhostVisionShader` (CanvasLayer) на уровень.
6. Не менять `project.godot`, скрипты вне инстансов, другие уровни.

## Acceptance criteria

- [ ] F5 → MainMenu → «Играть» → кот стоит на полу и может бегать/прыгать/crawl
- [ ] Obstacle сбрасывает на чекпоинт при «неправильной» форме (после смены на пса/ворона)
- [ ] Ночное зрение видно в форме кота
- [ ] Diff только `scenes/Level_Cat_Cemetry.tscn`

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . scenes/Level_Cat_Cemetry.tscn` без SCRIPT/Parse Error
- [ ] Ручной smoke: пол, crawl, респавн

## Заметки и история
- 2026-10-31T18:00:01Z — работа завершена владельцем mixey1201, ветка task/T-0021-level-cat-playable, ожидает PR
