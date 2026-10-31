---
id: T-0022
title: Играбельный уровень пса — пол, Jump/Breakable, LevelDirector
status: todo
form: dog
priority: high
owner: null
lease_until: null
branch: null
paths:
  - scenes/Level_Dog_Park.tscn
depends_on: [T-0019, T-0020, T-0017, T-0018, T-0006]
created: 2026-10-31
---

## Контекст

`Level_Dog_Park.tscn` сейчас — только `AudioStreamPlayer`, корень ошибочно назван `LevelDogBird`.
Нужен минимальный парк: пол, игрок (форма DOG или смена на месте), брёвна/JUMP_OVER Obstacle,
ломаемые коробки BreakableBox, LevelDirector.

## Шаги

1. Переименовать корень сцены в `LevelDogPark` (не путать с bird).
2. Пол с коллизией; декор из `tileset_spooky` (log, grass_to_dog, box_to_dog).
3. Инстанс Player + LevelDirector; старт в форме пса или CAT с возможностью shapeshift на DOG
   (форма должна быть unlocked — при необходимости вызвать unlock через менеджер из директора
   уровня **только если** это можно сделать без правки ShapeShiftManager; иначе стартовать DOG).
4. Инстансы `BreakableBox.tscn` на пути разгона.
5. `Obstacle` JUMP_OVER / HAZARD (pit) с `allowed_forms` под пса.
6. Не трогать Cat/Bird сцены и скрипты вне инстансов.

## Acceptance criteria

- [ ] Пёс бегает, прыгает, ломает коробки на скорости ≥ BREAK_SPEED
- [ ] Корень сцены = `LevelDogPark`
- [ ] Респавн через Obstacle + LevelDirector работает
- [ ] Diff только `scenes/Level_Dog_Park.tscn`

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Открытие сцены в Godot без SCRIPT/Parse Error
- [ ] Ручной smoke: разгон → break, прыжок через бревно

## Заметки и история
