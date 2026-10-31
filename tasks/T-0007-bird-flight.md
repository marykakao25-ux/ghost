---
id: T-0007
title: Ворон — полёт и сопротивление ветру (MovementBird, WindZone)
status: claimed
form: bird
priority: medium
owner: opencode
lease_until: 2026-10-31T21:02:32Z
branch: task/T-0007-bird-flight
paths:
  - scripts/MovementBird.gd
  - scripts/WindZone.gd
depends_on: [T-0003]
created: 2026-10-31
---

## Контекст

`scripts/MovementBird.gd` и `scripts/WindZone.gd` — заглушки. Обе относятся к полёту ворона и связаны
напрямую (зона ветра передаёт вектор в компонент движения), поэтому объединены в одну задачу:
их нельзя безопасно править параллельно.

Ошибка в `README.md`: там сказано «обработка движения по оси X (`UI_UP`, `UI_DOWN`, ...)» — это ось Y.
Использовать действия `move_*` из `docs/INPUT_MAP.md`, а не `UI_*`.

Спрайтов ворона в репозитории нет — графика в T-0011.

## Шаги

1. `MovementBird.gd`: `class_name MovementBird`, `FLY_SPEED`, `WIND_RESISTANCE`, `MAX_VERTICAL_SPEED`.
2. `move(player, delta)` — движение по обеим осям без гравитации, инерция, ограничение скорости.
3. `apply_wind_force(force: Vector2)` — добавляет смещение с учётом `WIND_RESISTANCE`;
   сила затухает, если зона неактивна.
4. `WindZone.gd` — `Area2D` с `wind_direction: Vector2` и `wind_strength: float`; в
   `_physics_process` передаёт суммарную силу всем воронам в зоне (`body_entered/body_exited` в список).
5. Анимации `bird_idle` / `bird_fly` — переключать по вертикальной скорости.

## Acceptance criteria

- [ ] Ворон летает по четырём направлениям
- [ ] Ветер влияет на полёт, но не уносит за пределы уровня
- [ ] При выходе из зоны сила ветра сбрасывается

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Проверка в сцене `scenes/Level_Bird_Rooftops.tscn`

## Заметки и история
