---
id: T-0036
title: Убрать ручное переключение форм (Q и 1/2/3) — только автоматическое вселение
status: todo
form: infra
priority: medium
owner: null
lease_until: null
branch: null
paths:
  - scripts/PlayerController.gd
  - scripts/LevelPresentation.gd
  - docs/INPUT_MAP.md
  - scripts/tests/interaction_regression.gd
depends_on: [T-0034]
created: 2026-11-01
---

## Контекст

Вопрос пользователя: «Зачем кнопка для переключения героя? Убрать.»
Подтверждено решением: убрать **все** ручные переключения (Q — цикл по
открытым формам, 1/2/3 — прямой выбор), оставив канонический способ —
автоматическое вселение в idle-хоста на `LevelExit` (T-0024/T-0029/T-0033)
и смену формы директором уровня при старте.

Сейчас ручная смена живёт в `scripts/PlayerController.gd::_unhandled_input`
(обработчики `shapeshift`, `shapeshift_cat`, `shapeshift_dog`,
`shapeshift_bird`) и в `_get_next_unlocked_form()`. Подсказка в HUD
`scripts/LevelPresentation.gd::_process`: «… / Q · 1 · 2 · 3 — открытые
формы». Движение и пауза (`pause`) не затрагиваются.

Секцию `[input]` в `project.godot` **не трогаем**: AGENTS.md, п. 4.6,
разрешает менять её только задачам T-0002/T-0004. Действия
`shapeshift*` остаются объявленными, но необработанными; INPUT_MAP помечает
их зарезервированными.

## Шаги

1. В `_unhandled_input` оставить только `pause`; удалить ветки
   `shapeshift*` и мёртвый `_get_next_unlocked_form()`.
2. В HUD убрать «Q · 1 · 2 · 3» из строки формы (`_form_label`), оставить
   текущее имя формы; тексты целей (OBJECTIVES) про ручное переключение не
   упоминают — проверить.
3. docs/INPUT_MAP.md: пометить `shapeshift`, `shapeshift_cat/dog/bird` как
   «объявлено, не обрабатывается — смена формы только вселением»;
   дату/историю обновить.
4. Регрессия: `interaction_regression.gd` — смена формы руками не меняет
   `current_form`; `ShapeShiftManager.change_form()` по-прежнему работает.
   (Если существующие тесты давили shapeshift-клавиши — перевести на
   прямой вызов менеджера.)

## Acceptance criteria

- [ ] Q, 1, 2, 3 в игре не меняют форму (проверка в регрессии)
- [ ] Автосмена при вселении/старте уровней работает как раньше
- [ ] В HUD нет упоминаний Q/1/2/3; пауза Esc не задета
- [ ] docs/INPUT_MAP.md отражает фактические обработчики
- [ ] `pwsh -File scripts/agent/verify.ps1` и оба SceneTree-теста — зелёные

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . --headless --script scripts/tests/interaction_regression.gd`
- [ ] Ручной прогон: на cat-уровне нажать Q/1/2/3 — ничего; дойти до
      хоста-пса — вселение состоялось

## Заметки и историю

<!-- Сюда агент дописывает ход работы: что сделано, что осталось, что заблокировало. -->
