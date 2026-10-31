---
id: T-0004
title: ShapeShiftManager — смена формы и переход между уровнями
status: todo
form: infra
priority: high
owner: null
lease_until: null
branch: null
paths:
  - scripts/ShapeShiftManager.gd
  - project.godot
depends_on: [T-0003]
created: 2026-10-31
---

## Контекст

`scripts/ShapeShiftManager.gd` — заглушка. По `README.md` он либо Autoload-синглтон, либо менеджер
уровней; сейчас не то и не другое. Autoload требует правки `project.godot` — поэтому эта задача
единственная, кроме T-0002, касается `project.godot`.

> **Внимание:** полагается на T-0002 (секция `[input]` и имя проекта). Секцию `[input]` не трогать,
> только добавить `[autoload]`.

## Шаги

1. Добавить в `project.godot` секцию `[autoload]`:
   `ShapeShiftManager="*res://scripts/ShapeShiftManager.gd"`.
2. `ShapeShiftManager.gd` — `extends Node`, `class_name` не нужен (Autoload уже глобальный).
3. `signal form_changed(from_form: int, to_form: int)`.
4. `change_form(new_form)` — проигрывает эффект вспышки (создаёт `GPUParticles2D`/`CPUParticles2D`
   под `FormPivot`, удаляет через `finished`), затем вызывает `player.set_form(new_form)`.
5. `trigger_level_transition(next_scene: String)` — сохраняет прогресс в `user://progress.cfg`,
   грузит следующую сцену через `get_tree().change_scene_to_file`.
6. Прогресс: `unlocked_forms` (Array[int]) и `last_checkpoint`, методы `save_progress/load_progress`.

## Acceptance criteria

- [ ] Autoload виден в Project Settings → Globals
- [ ] Смена формы проигрывает эффект ровно один раз
- [ ] `trigger_level_transition` грузит указанную сцену и не падает при отсутствии файла

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . --headless --quit` без ошибок

## Заметки и история
- 2026-10-31T08:46:05Z — работа завершена владельцем agent-beta, ветка task/T-0004-shapeshift-manager, ожидает PR
- 2026-10-31 — возврат в todo: статус «done» был артефактом сквозного теста claim→release (T-0001), код задачи не писался. `ShapeShiftManager.gd` по-прежнему заглушка.

