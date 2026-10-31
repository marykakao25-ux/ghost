---
id: T-0034
title: Движение без components после вселения — set_form молча отказывается из-за overlap
status: claimed
form: infra
priority: high
owner: mixey1201
lease_until: 2026-11-01T01:30:53Z
branch: task/T-0034-form-switch-movement
paths:
  - scripts/PlayerController.gd
  - scripts/ShapeShiftManager.gd
  - scripts/LevelDirector.gd
  - scenes/Level_Dog_Park.tscn
  - scenes/Level_Bird_Rooftops.tscn
  - scripts/tests/interaction_regression.gd
  - scripts/tests/demo_regression.gd
depends_on: []
created: 2026-11-01
---

## Контекст

Пользователь: «не работает движение после переключения на другого героя» —
после автоматического вселения (интро → кот, хост-пёс, хост-ворон) игрок стоит
и не реагирует на ходьбу/прыжок.

Причина в `scripts/PlayerController.gd`:
* `set_form()` при неудаче `can_set_form()` выходит **до** `_swap_movement()`,
  оставляя `current_movement == null`; тогда `_physics_process` применяет только
  резервную гравитацию — ввод не читается вовсе;
* `can_set_form()` спрашивает пересечение новой формы с геометрией в точке
  спавна, а форма у всех героев крупная (кот/пёс ~1/5 экрана, ворон радиус 66);
  на стартовых позициях уровней пересечение регулярно есть — в этом прямо
  признаётся комментарий в `scripts/tests/interaction_regression.gd`
  («set_form в _ready часто откатывается из-за overlap»);
* тесты маскируют дефект ручным патчем (`_load_level` сам вызывает
  `set_form(0)`, когда `current_movement == null`), поэтому регрессии зелёные,
  а игра сломана;
* `ShapeShiftManager.change_form()` проставляет `current_form`/`unlocked_forms`
  **до** вызова `player.set_form()` и при отказе игрока рассинхронизируется:
  повторный `change_form()` той же формы возвращает false как no-op, и герой
  остаётся без движения до перезагрузки уровня.

Связанные: docs/ARCHITECTURE.md (схема Player.tscn, делегирование движения),
T-0028/T-0033 (история вселения).

## Шаги

1. Воспроизвести в `interaction_regression.gd`: после загрузки уровня
   **без** ручного патча требовать `current_movement != null` и сдвиг по X от
   нажатого `move_right` (физический кадр, не прямой вызов `move()`).
2. Сделать применение формы необратимым для управления: движение и спрайт
   меняются всегда; смену коллайдера при overlap откладывать и повторять в
   `_physics_process`, пока форма не встанет без пересечения (или игрок сам
   выйдет из тесного места).
3. Синхронизировать `ShapeShiftManager.current_form` с фактической формой
   игрока (через сигнал `form_changed`), а не с намерением; убрать
   первопричину ложного no-op.
4. Инлайн-скрипты Dog/Bird-уровней не пишут `ShapeShiftManager.current_form`
   в обход подтверждения игрока — только unlock + change_form/set_form.
5. Удалить маскирующий патч из тестов; прогнать `demo_regression.gd`.

## Acceptance criteria

- [ ] На cat/dog/bird уровнях после входа игрока `current_movement != null`
      без каких-либо ручных доводок из тестов
- [ ] Зажатый `move_right` сдвигает игрока вперёд на каждом из трёх уровней
      сразу после старта и после каждой смены формы (регрессия)
- [ ] `ShapeShiftManager.current_form` равен фактической форме игрока после
      любой попытки смены, включая отказ
- [ ] Отказ смены из-за overlap больше не лишает игрока управления: движение
      доступно, форма коллизии догоняется в ближайшие кадры
- [ ] `pwsh -File scripts/agent/verify.ps1`, оба SceneTree-теста — зелёные;
      `godot --headless --quit` без SCRIPT ERROR

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . --headless --script scripts/tests/interaction_regression.gd`
- [ ] `godot --path . --headless --script scripts/tests/demo_regression.gd`
- [ ] Ручной прогон: меню → интро (вселение в кота) → walkthrough до хоста-пса

## Заметки и историю

<!-- Сюда агент дописывает ход работы: что сделано, что осталось, что заблокировало. -->
