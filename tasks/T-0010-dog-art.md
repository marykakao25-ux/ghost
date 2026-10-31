---
id: T-0010
title: Графика пса — спрайты и SpriteFrames (4 анимации)
status: todo
form: art
priority: medium
owner: null
lease_until: null
branch: null
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

- [ ] Каталог `assets/sprites/dog/` содержит все кадры и три сцены анимаций
- [ ] Анимации проигрываются в редакторе без ошибок
- [ ] Нет пересечения имён с `assets/sprites/cat/`

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . assets/sprites/dog/anim_dog_idle.tscn`

## Заметки и история
