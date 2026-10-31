---
id: T-0038
title: Докрыть T-0035/T-0037: регрессии отказа LevelExit и клика паузы; синхрон docs/ARCHITECTURE.md
status: claimed
form: docs
priority: low
owner: mixey1201
lease_until: 2026-11-01T02:18:40Z
branch: task/T-0038-followup-records-docs
paths:
  - docs/ARCHITECTURE.md
  - scripts/tests/interaction_regression.gd
depends_on: [T-0035, T-0037]
created: 2026-11-01
---

## Контекст

T-0035 и T-0037 влиты (PR #58, #60), но их acceptance criteria закрыты не полностью,
а docs/ARCHITECTURE.md после T-0034..T-0037 устарел:

1. T-0035 AC: «К чекпоинту» нажимается кнопкой (не только вызовом колбэка) —
   `_test_pause_menu` проверяет фокус, но не press-клик;
2. T-0037 AC: ветка отказа перехода (rollback unlocked/checkpoint/current_form)
   и «хост можно попробовать снова» не покрыты регрессией — headless не может
   заставить `change_scene_to_file` упасть на существующей сцене, но ранний
   выход по несуществующей `next_scene` — может;
3. ARCHITECTURE.md содержит устаревшие строки: уровни «заготовки без Player и
   физики», «регистрацию добавляет T-0019, паузу/смену — T-0020, коробку — T-0018»
   (все done), «MovementDog ищет именованные анимации — T-0017» (done),
   «в уровнях нет подключений API менеджера» (есть: LevelDirector, инлайн-скрипты,
   LevelExit), «сцены коробки ещё не создана» (есть BreakableBox.tscn), ручная
   смена форм Q/1–3 (удалена в T-0036).

## Шаги

1. `_test_pause_menu`: добавить press-клик кнопки «К чекпоинту»
   (`button.pressed.emit()`), проверить снятие паузы и перенос игрока директором.
2. Новый `_test_host_rollback_retry`: LevelExit.cat-уровня с временно битым
   `next_scene` → `_begin_possession` ничего не меняет (form/unlocked/checkpoint)
   и `_transition_pending == false`; вернуть валидный путь → вселение приводит
   к уровню пса (закрывает T-0037 AC «повторное касание» и «состояние прежнее»).
3. docs/ARCHITECTURE.md: обновить таблицу «Что реализовано», абзацы 32–35,
   строку формы «Пёс» и абзац ShapeShiftManager (реальное состояние после
   T-0034..T-0037); ручной смены форм больше нет.
4. Отметить соответствующие галочки в tasks/done/T-0035, T-0037 и дописать заметку.

## Acceptance criteria

- [ ] Пауза: «К чекпоинту» срабатывает от нажатия кнопки в регрессии
- [ ] Отказ LevelExit: состояние менеджера прежнее, хост доступен для повторной
      попытки (регрессия); успешный повтор доводит до уровня пса
- [ ] docs/ARCHITECTURE.md описывает фактическое состояние (ни одной ссылки на
      T-0017..T-0020 как «ещё предстоит»)
- [ ] `pwsh -File scripts/agent/verify.ps1`, interaction/demo-регрессии — зелёные

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . --headless --script scripts/tests/interaction_regression.gd`
- [ ] `godot --path . --headless --script scripts/tests/demo_regression.gd`

## Заметки и историю

<!-- Сюда агент дописывает ход работы: что сделано, что осталось, что заблокировало. -->
