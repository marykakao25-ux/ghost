---
id: T-0024
title: Переходы между уровнями — LevelExit и связка кот→пёс→ворон
status: todo
form: infra
priority: medium
owner: null
lease_until: null
branch: null
paths:
  - scripts/LevelExit.gd
  - scenes/LevelExit.tscn
  - scenes/Level_Cat_Cemetry.tscn
  - scenes/Level_Dog_Park.tscn
  - scenes/Level_Bird_Rooftops.tscn
depends_on: [T-0021, T-0022, T-0023]
created: 2026-10-31
---

## Контекст

`ShapeShiftManager.trigger_level_transition(next_scene)` готов, но на уровнях нет триггеров.
Один агент последовательно вешает выходы: Cat → Dog → Bird. Разблокировка следующей формы —
при входе на уровень или при касании выхода (`unlock_form`).

`paths` сознательно включает три сцены уровней — параллелить нельзя (правило «одна сцена — одна
задача» ослаблено здесь ради атомарного потока MVP).

## Шаги

1. `LevelExit.gd` — Area2D; `@export var next_scene: String`; `@export var unlock_form: int = -1`.
2. При `body_entered` игрока: опционально `unlock_form`, затем `trigger_level_transition(next_scene)`.
3. `LevelExit.tscn` — переиспользуемый сенсор.
4. Инстанс на конце Cat → `Level_Dog_Park.tscn`; Dog → `Level_Bird_Rooftops.tscn`;
   Bird → `res://scenes/Finale.tscn` (файл сцены добавляет T-0025 сразу после; до merge T-0025
   переход птицы может логировать ошибку `ResourceLoader` — это ожидаемо).
5. Не ломать уже расставленный геймплей уровней больше, чем нужно для выхода.

## Acceptance criteria

- [ ] Прохождение конца кошачьего уровня грузит парк пса
- [ ] Конец пса → крыши ворона
- [ ] Переход сохраняет прогресс через ShapeShiftManager.save_progress
- [ ] Нет `reload_current_scene` в LevelExit

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Ручной прогон трёх переходов (можно чит-телепортом к Exit)

## Заметки и история
- 2026-10-31T18:01:26Z — лок снят принудительно (был owner=opencode): Преждевременный захват: T-0022/T-0023 ещё не готовы; работы нет, освобождаю сцены для цепочки B
