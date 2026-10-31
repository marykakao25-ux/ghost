---
id: T-0012
title: Меню и главная сцена (MainMenu, пауза)
status: done
form: infra
priority: medium
owner: mixey1201
lease_until: 2026-10-31T20:11:00Z
branch: task/T-0012-main-menu
paths:
  - scenes/MainMenu.tscn
  - scenes/MainMenu.gd
depends_on: [T-0002]
created: 2026-10-31
---

## Контекст

`scenes/MainMenu.tscn` сейчас — `Node2D` с одним `AudioStreamPlayer` (сверчки, `autoplay = true`),
без кнопок и без скрипта. При этом `run/main_scene` указывает на уровень ворона (см. T-0002).

## Шаги

1. Сохранить музыку (`AudioStreamPlayer` со сверчками) и добавить `Control`-слой с кнопками
   «Играть», «Настройки», «Выход».
2. «Играть» — `get_tree().change_scene_to_file("res://scenes/Level_Cat_Cemetry.tscn")`.
3. `process_mode` меню — `PROCESS_MODE_ALWAYS`, чтобы пауза не ломала кнопки.
4. Скрипт меню положить рядом со сценой (`scenes/MainMenu.gd`) — каталог `scripts/` в этой задаче
   не разрешён, чтобы не конфликтовать с T-0003/T-0004.
5. Проверить, что меню корректно масштабируется при 1800×800 (`stretch/mode="canvas_items"`).

## Acceptance criteria

- [ ] Меню запускается как главная сцена и показывает три кнопки
- [ ] «Играть» открывает уровень кота
- [ ] Музыка меню не обрывается при переходе (или корректно останавливается — зафиксировать выбор)

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . scenes/MainMenu.tscn`

## Заметки и история
- 2026-10-31T16:18:03Z — работа завершена владельцем mixey1201, ветка task/T-0012-main-menu, ожидает PR
