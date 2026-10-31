---
id: T-0030
title: Camera2D и удлинение уровней под крупного героя
status: done
form: infra
priority: high
owner: mixey1201
lease_until: 2026-11-01T00:20:52Z
branch: task/T-0030-camera-longer-levels
paths:
  - scripts/LevelDirector.gd
  - scripts/LevelPresentation.gd
  - scenes/Player.tscn
  - scenes/Level_Cat_Cemetry.tscn
  - scenes/Level_Dog_Park.tscn
  - scenes/Level_Bird_Rooftops.tscn
  - scripts/tests/demo_regression.gd
  - scripts/tests/interaction_regression.gd
depends_on: [T-0029]
created: 2026-11-01
---

## Контекст

После T-0029 герой крупнее; уровни всё ещё ~1800 px (ровно вьюпорт), камеры нет.
Нужны длина ~3600 px по X и Camera2D со follow и лимитами. Вьюпорт 1800×800 не менять.

## Шаги

1. Добавить Camera2D (на Player или через LevelDirector) с лимитами уровня.
2. Растянуть пол, стены, прогресс HUD до ~3600 px.
3. Сдвинуть хосты/чекпоинты/спавн; поднять crawl/jump под новый коллайдер.
4. Обновить регрессии координат.

## Acceptance criteria

- [ ] Камера следует за героем в пределах уровня
- [ ] Правый край заметно дальше первого экрана (~3600)
- [ ] Хост в конце достижим
- [ ] Крупный герой проходит crawl/jump без клина в старой геометрии
- [ ] verify и регрессии зелёные

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . --headless --quit` без SCRIPT/Parse Error

## Заметки и история
- 2026-10-31T20:23:42Z — работа завершена владельцем mixey1201, ветка task/T-0030-camera-longer-levels, ожидает PR
