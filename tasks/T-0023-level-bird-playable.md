---
id: T-0023
title: Играбельный уровень ворона — границы, WindZone, Obstacle, LevelDirector
status: todo
form: bird
priority: high
owner: null
lease_until: null
branch: null
paths:
  - scenes/Level_Bird_Rooftops.tscn
depends_on: [T-0019, T-0020, T-0007, T-0009]
created: 2026-10-31
---

## Контекст

`Level_Bird_Rooftops.tscn` — только музыка. Нужен минимальный «небо над крышами»: игрок-ворон,
границы/крыши, зоны ветра, препятствия FLY_AROUND/HAZARD (ветки, фонари), LevelDirector.

## Шаги

1. Платформы/крыши с коллизией (тайлы tile/branch/lantern как декор).
2. Инстанс Player в форме BIRD (или unlock+shapeshift); LevelDirector + spawn в воздухе/на карнизе.
3. 1–2 `WindZone` с разными `wind_direction` / `wind_strength`.
4. `Obstacle` FLY_AROUND (allowed bird) и HAZARD.
5. Границы уровня (стены/потолок StaticBody), чтобы ветер не уносил в бесконечность.
6. Не менять другие уровни и скрипты MovementBird/WindZone (только инстансы).

## Acceptance criteria

- [ ] Ворон летает по 4 направлениям на уровне
- [ ] В WindZone ощущается снос; вне зоны сила затухает
- [ ] HAZARD/неверная форма → респавн через LevelDirector
- [ ] Diff только `scenes/Level_Bird_Rooftops.tscn`

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Открытие сцены без SCRIPT/Parse Error
- [ ] Ручной smoke: ветер + полёт

## Заметки и история
