---
id: T-0035
title: Меню паузы смещено: панель привязана фиксированными координатами, не к viewport
status: claimed
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

- [ ] Панель «Пауза» отцентрована в viewport при базовых 1800×800
- [ ] Затемнение и панель корректны при отличном от базового видимом rect
      (тест меняет размер окна/viewport и сверяет центр)
- [ ] «Продолжить»/«К чекпоинту» кликабельны (grab_focus + нажатие в регрессии)
- [ ] `pwsh -File scripts/agent/verify.ps1` и interaction-регрессия — зелёные

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . --headless --script scripts/tests/interaction_regression.gd`
- [ ] Ручной прогон: Esc в_levels_ — меню строго по центру, Esc/«Продолжить» возвращает

## Заметки и историю

<!-- Сюда агент дописывает ход работы: что сделано, что осталось, что заблокировало. -->
