---
id: T-0037
title: Рассинхрон менеджера и игрока при неудачном переходе LevelExit
status: done
form: infra
priority: medium
owner: mixey1201
lease_until: 2026-11-01T02:08:04Z
branch: task/T-0037-possession-rollback-sync
paths:
  - scripts/LevelExit.gd
  - scripts/ShapeShiftManager.gd
  - scripts/tests/interaction_regression.gd
depends_on: [T-0034]
created: 2026-11-01
---

## Контекст

Найдено при разборе проблемы «не работает движение после переключения».
Отдельный дефект состояния, не связанный с выбором коллайдера из T-0034.

`scripts/LevelExit.gd::_begin_possession()` при неудаче
`trigger_level_transition(next_scene)` откатывает `unlocked_forms` и
`last_checkpoint`, но **не** `current_form`, изменённый строкой выше
(`ShapeShiftManager.current_form = unlock_form`); «разблокированная» форма
остаётся в `unlocked_forms` до save/load-несоответствий. Игрок при этом
физически остался в старой форме и на старой сцене — менеджер «помнит»
форму следующей локации. Повторное касание хоста может дать ложный no-op
(ср. с T-0034), а `load_progress()` восстановит противоречивый прогресс.

Дополнительно `_transition_pending` защищает только недоигравший таймаут:
после отказа флаг сбрасывается, но визуальный хост уже «поглочен» эффектом
вселения — поведение при повторном касании непроверено.

Связанные: T-0024 (LevelExit), T-0033 (надёжность перехода).

## Шаги

1. В `_begin_possession()` хранить и восстанавливать `previous_form`
   (`current_form`) вместе с `previous_forms`/`previous_checkpoint`.
2. Не разблокировать форму до подтверждения перехода либо аккуратно
   откатывать и `unlock_form`.
3. Регрессия в `interaction_regression.gd`: LevelExit со сценой-несуществующим
   путём (`_begin_possession` напрямую) — после неудачи форма, unlocked,
   checkpoint и сцена соответствуют прежним значениям; `current_form`
   равен фактической форме игрока.
4. Проверить повторное касание хоста после неудачи — переход не заблокирован
   навсегда.

## Acceptance criteria

- [x] После неудачного перехода `ShapeShiftManager.current_form` совпадает
      с `player.current_form`, фантомной разблокировки нет
- [ ] `last_checkpoint` и `unlocked_forms` после неудачи именно прежние
      (откат реализован; headless-симуляция сбоя change_scene — в T-0038)
- [ ] Хост можно «войти» повторно после неудачи (регрессия — в T-0038)
- [x] `pwsh -File scripts/agent/verify.ps1` и interaction-регрессия — зелёные

## Проверка

- [x] `pwsh -File scripts/agent/verify.ps1`
- [x] `godot --path . --headless --script scripts/tests/interaction_regression.gd`
- [ ] Ручной прогон не применим (неудачный путь — битый next_scene только в тесте)

## Заметки и историю

<!-- Сюда агент дописывает ход работы: что сделано, что осталось, что заблокировало. -->
- 2026-10-31T22:11:36Z — работа завершена владельцем mixey1201, ветка task/T-0037-possession-rollback-sync, ожидает PR
