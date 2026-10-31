---
id: T-0002
title: Карта ввода и настройки проекта (input map, имя проекта, main scene)
status": claimed
form: infra
priority: high
owner": agent-alpha
lease_until": 2026-10-31T12:36:57Z
branch": task/T-0002-input-map
paths:
  - project.godot
depends_on: [T-0001]
created: 2026-10-31
---

## Контекст

Сейчас в `project.godot`:

* `config/name="Lesson01_GodotIntro"`, описание «Занятие 1 — Знакомство с Godot Engine» — наследие туториала,
  в заголовке окна видно чужое название;
* `run/main_scene="uid://crs113cokr4v8"` указывает на `scenes/Level_Bird_Rooftops.tscn`, а не на `MainMenu.tscn`;
* нет секции `[input]`, хотя `README.md` строит управление на `UI_DOWN`/`UI_UP` и упоминает прыжок и смену формы.

`UI_*` — встроенные действия интерфейса: они конфликтуют с навигацией по меню (стрелки/Enter) и могут
меняться движком. Для геймплея нужны собственные действия.

## Шаги

1. Переименовать проект: `config/name="Ghost"`, осмысленный `config/description`.
2. Переключить `run/main_scene` на `scenes/MainMenu.tscn` (uid берётся из первой строки сцены).
3. Добавить секцию `[input]` с действиями:
   `move_left`, `move_right`, `move_up`, `move_down`, `jump`, `crawl`, `shapeshift`, `pause`.
4. Клавиши: `move_*` — WASD и стрелки, `jump` — Space, `crawl` — Ctrl или S, `shapeshift` — Q/1/2/3, `pause` — Esc.
5. Описать итог в `docs/INPUT_MAP.md` (сам файл создаётся в T-0001, здесь только уточнение под реальные клавиши).
6. Открыть проект в Godot 4.7 и убедиться, что Project Settings → Input Map показывает все действия.

## Acceptance criteria

- [ ] `config/name="Ghost"`, описание соответствует игре
- [ ] Игра запускается с `MainMenu.tscn`
- [ ] Все перечисленные действия есть в Input Map и назначены
- [ ] `docs/INPUT_MAP.md` совпадает с `project.godot`

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . --headless --quit` без ошибок

## Заметки и история
