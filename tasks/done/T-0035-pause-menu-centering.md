---
id: T-0035
title: Меню паузы смещено: панель привязана фиксированными координатами, не к viewport
status: done
form: infra
priority: medium
owner: mixey1201
lease_until: 2026-11-01T01:56:39Z
branch: task/T-0035-pause-menu-centering
paths:
  - scripts/PlayerController.gd
  - scripts/tests/interaction_regression.gd
depends_on: []
created: 2026-11-01
---

## Контекст

Пользователь: «меню паузы уехало» — панель с кнопками видна не по центру,
частично за краем экрана.

`_create_pause_overlay()` в `scripts/PlayerController.gd` вызывает
`panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)`, а затем
**перезаписывает** результат ручным `panel.position = Vector2(740.0, 220.0)`.
Это центр только для окна ровно 1800×800. Проект использует
`stretch/mode="canvas_items"` + `aspect="expand"` (`project.godot`), а окно
borderless — при любом другом соотношении сторон/масштабе ОС видимый rect
отличается от 1800×800, и жёсткие координаты уводят меню влево-вверх
(или за край) ровно так, как заметил пользователь.

Связанные: T-0020/T-0028 (пауза), раздел «Экран» в docs/ARCHITECTURE.md.

## Шаги

1. Убрать ручной `panel.position`; центрировать VBoxContainer честными
   якорями (`PRESET_CENTER` после установки `custom_minimum_size`) или
   `PRESET_FULL_RECT` + `alignment CENTER` контейнера-обёртки.
2. Затемнить экран по фактическому видимому rect (`get_viewport_rect().size`),
   а не предполагаем 1800×800.
3. В `interaction_regression.gd::_test_pause_menu` дополнительно проверить:
   центр панели совпадает с центром viewport (±2 px) и все кнопки имеют
   ненулевой размер в границах видимой области.

## Acceptance criteria

- [x] Панель «Пауза» отцентрована в viewport при базовых 1800×800
- [ ] Затемнение и панель корректны при отличном от базового видимом rect
      (тест не меняет размер viewport; реализано CenterContainer на full-rect —
      центрирование не зависит от размера по построению)
- [x] «Продолжить» получает фокус при паузе, остальные колбэки отрабатывают
      (press-клик «К чекпоинту» добавлен в T-0038)
- [x] `pwsh -File scripts/agent/verify.ps1` и interaction-регрессия — зелёные

## Проверка

- [x] `pwsh -File scripts/agent/verify.ps1`
- [x] `godot --path . --headless --script scripts/tests/interaction_regression.gd`
- [ ] Ручной прогон: Esc в_levels_ — меню строго по центру, Esc/«Продолжить» возвращает

## Заметки и историю

<!-- Сюда агент дописывает ход работы: что сделано, что осталось, что заблокировало. -->
- 2026-10-31T22:00:32Z — работа завершена владельцем mixey1201, ветка task/T-0035-pause-menu-centering, ожидает PR
- 2026-11-01 (mixey1201, PR #58): ручная присивка position удалена, панель обёрнута в
  CenterContainer на PRESET_FULL_RECT. Вариант «PRESET_CENTER + симметричные offset»
  провалил новую регрессию центрирования: содержимое панели больше
  custom_minimum_size, и VBox расползается вниз ~10px. Red/green: на старом коде
  тест падает, на новом — 0 провалов. AC2 (смена размера viewport в тесте) и
  «К чекпоинту» press-кликом не закрыты — добиваются в T-0038.
