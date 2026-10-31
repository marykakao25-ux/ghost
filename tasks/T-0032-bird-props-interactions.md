---
id: T-0032
title: Ветки из фона, воздух и фонари на уровне ворона
status: todo
form: bird
priority: high
owner: null
lease_until: null
branch: null
paths:
  - scenes/Level_Bird_Rooftops.tscn
  - scripts/WindZone.gd
  - scenes/WindZone.tscn
  - scripts/Obstacle.gd
  - scenes/Obstacle.tscn
  - scripts/LevelPresentation.gd
  - scripts/tests/demo_regression.gd
  - scripts/tests/interaction_regression.gd
depends_on: [T-0031]
created: 2026-11-01
---

## Контекст

Фон ворона — `assets/environment/halloween_props/bird_location.png` (деревья).
`branch.png` должен торчать из этих деревьев; ворон облетает ветки.
Также: `air.png` + WindZone, `lantern.png` снизу вверх как опасные столбы.

| Ассет | Взаимодействие |
|---|---|
| `branch.png` + деревья фона | облёт; удар → reset |
| `air.png` | визуал WindZone, толкает ворона |
| `lantern.png` | фонари снизу; облетать / HAZARD |

## Шаги

1. Расставить branch по кронам на bird_location; FLY_AROUND / reset при касании.
2. Зоны ветра с текстурой air.png и работающим apply_wind_force.
3. Фонари снизу экрана вверх — коллизия/hazard.
4. Обновить objectives HUD; регрессии.

## Acceptance criteria

- [ ] Ветки визуально связаны с деревьями фона; облёт работает
- [ ] Поток воздуха заметен и толкает ворона
- [ ] Фонари снизу — облетаемые/опасные
- [ ] verify и регрессии зелёные

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Прогон bird-уровня вручную или регрессией

## Заметки и история
