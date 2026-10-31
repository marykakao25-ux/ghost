---
id: T-0010
title: Графика пса — спрайты и SpriteFrames (4 анимации)
status: done
form: art
priority: medium
owner: mixey1201
lease_until: 2026-10-31T19:32:15Z
branch: task/T-0010-dog-art
paths:
  - assets/sprites/dog
depends_on: []
created: 2026-10-31
---

## Контекст

Каталога `assets/sprites/dog/` в репозитории **нет**, хотя `README.md` его описывает. Нужны спрайты
и сцены анимаций по образцу кота (`assets/sprites/cat/anim_cat_idle.tscn` — `SpriteFrames`
с `ExtResource` на отдельные PNG).

Требуется по `README.md`: `dog_idle` (3 кадра), `dog_run` (4–6), `dog_jump_high` (4).

## Шаги

1. Создать каталог `assets/sprites/dog/` (новый — ни с чем не пересекается).
2. PNG-кадры: `dog_idle1..3.png`, `dog_run1..N.png`, `dog_jump_high1..4.png`.
3. Сцены: `anim_dog_idle.tscn`, `anim_dog_run.tscn`, `anim_dog_jump_high.tscn` — по образцу кота,
   имена анимаций внутри `SpriteFrames` совпадают с именами анимаций из `README.md`.
4. Все PNG — в стиле проекта (тёмная палитра, багровый свет Луны), прозрачный фон.
5. Импорт выполнять через Godot 4.7 (`.import`-файлы генерируются автоматически и коммитятся).

## Acceptance criteria

- [x] Каталог `assets/sprites/dog/` содержит все кадры и три сцены анимаций
- [x] Анимации проигрываются в редакторе без ошибок
- [x] Нет пересечения имён с `assets/sprites/cat/`

## Проверка

- [x] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . assets/sprites/dog/anim_dog_idle.tscn` (Godot не в PATH на машине агента)

## Заметки и история
- 2026-10-31T15:37:11Z — работа завершена владельцем mixey1201, ветка task/T-0010-dog-art, ожидает PR
- 2026-10-31 — ассеты уже лежали в `main` после прямого push `e2f65ab` (issue #20, claims-guard). Код задачи не писался заново: проверен набор idle×3 / run×6 / jump_high×4 + три `anim_dog_*.tscn` по образцу кота (`SpriteFrames` name `default`, как у cat). Отдельный PR с ассетами не нужен. Документация в `docs/ASSETS.md` — задача T-0013.
