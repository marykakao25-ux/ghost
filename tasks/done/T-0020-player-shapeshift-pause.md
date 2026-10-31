---
id: T-0020
title: PlayerController — ввод shapeshift* и пауза pause
status: done
form: infra
priority: high
owner: opencode
lease_until: 2026-10-31T21:42:16Z
branch: task/T-0020-player-shapeshift-pause
paths:
  - scripts/PlayerController.gd
depends_on: [T-0002, T-0003, T-0004]
created: 2026-10-31
---

## Контекст

В `project.godot` есть `shapeshift`, `shapeshift_cat/dog/bird`, `pause`, но
`PlayerController` их не читает. Без этого нельзя сменить форму в рантайме и поставить паузу.
`ShapeShiftManager.change_form` уже есть.

Пауза UI — минимально: `get_tree().paused = true/false` на `pause`; процесс игрока/оверлея —
`PROCESS_MODE_ALWAYS` только если нужен unpause с той же клавиши (не трогать MainMenu.tscn).

## Шаги

1. В `_physics_process` или `_unhandled_input`: `shapeshift_cat/dog/bird` →
   `ShapeShiftManager.change_form(Form.*)`; `shapeshift` — цикл по разблокированным формам
   (`is_form_unlocked`).
2. Не использовать `UI_*`.
3. `pause` — переключить `get_tree().paused`; обеспечить возможность снять паузу тем же действием
   (`process_mode` на игроке или отдельный всегда-живой узел-ребёнок, созданный из кода).
4. В `_ready`: `add_to_group("player")` для поиска директором/шейдером.
5. Не менять коллизии/формы сверх необходимого для ввода.

## Acceptance criteria

- [ ] Клавиши 1/2/3 и Q меняют форму через ShapeShiftManager (с учётом unlock)
- [ ] Esc (pause) ставит и снимает паузу
- [ ] Игрок в группе `player`
- [ ] Diff только `scripts/PlayerController.gd`

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Godot headless без SCRIPT/Parse Error

## Заметки и история
- 2026-10-31T17:44:46Z — работа завершена владельцем opencode, ветка task/T-0020-player-shapeshift-pause, ожидает PR
