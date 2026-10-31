---
id: T-0025
title: Финальная сцена — облик призрака (assets/sprites/gg)
status: claimed
form: infra
priority: medium
owner: opencode
lease_until: 2026-10-31T22:02:02Z
branch: task/T-0025-finale-ghost-form
paths:
  - scenes/Finale.tscn
  - scenes/Finale.gd
depends_on: [T-0024]
created: 2026-10-31
---

## Контекст

По README финал: дух синтезирует три формы и обретает видимый облик. Спрайты `assets/sprites/gg/`
уже в репозитории и описаны в ASSETS.md, но нигде не используются. После T-0024 выход с bird-уровня
должен вести сюда.

## Шаги

1. `scenes/Finale.tscn` + `Finale.gd` — короткая сцена: спрайт gg, текст на русском
   («Ты вспомнил, каково это — чувствовать»), кнопка «В меню» → MainMenu.
2. `PROCESS_MODE` кнопок — всегда активны.
3. Если T-0024 ещё указывает на MainMenu — обновить путь выхода птицы на Finale **только если**
   `Level_Bird_Rooftops.tscn` окажется в `paths`… В этой задаче `paths` **не** включают bird-уровень.
   Значит: либо T-0024 уже ставит `Finale.tscn`, либо завести follow-up; в шагах T-0024 выбран
   путь на Finale — эта задача обязана создать файл до/вместе с ожиданием ссылки.
4. Не добавлять новый Autoload; не менять `project.godot` (main_scene остаётся MainMenu).

## Acceptance criteria

- [ ] Сцена `res://scenes/Finale.tscn` существует и открывается без ошибок
- [ ] Показан спрайт из `assets/sprites/gg/`
- [ ] Есть возврат в MainMenu
- [ ] Diff только Finale.tscn / Finale.gd

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Godot: открыть Finale.tscn

## Заметки и история
