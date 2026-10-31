---
id: T-0008
title: Ночное зрение кота — 2D-шейдер и маска темноты
status: claimed
form: cat
priority: medium
owner: mixey1201
lease_until: 2026-10-31T20:35:48Z
branch: task/T-0008-night-vision
paths:
  - scripts/GhostVisionShader.gd
  - assets/shaders
depends_on: [T-0005]
created: 2026-10-31
---

## Контекст

`scripts/GhostVisionShader.gd` — заглушка. Нужен экранный эффект: темнота с вырезанным конусом перед
котом (призрачно-зелёный свет). В репозитории нет ни `shader`-файлов, ни `CanvasLayer`/`ColorRect`
под эффект — этой задаче разрешено создать каталог `assets/shaders/`.

## Шаги

1. Создать `assets/shaders/ghost_vision.gdshader` — `canvas_item`-шейдер: маска темноты,
   `uniform` центр/направление конуса/радиус/цвет; в темноте видно силуэты.
2. `scripts/GhostVisionShader.gd` — `extends CanvasLayer` (или `ColorRect` с этим материалом), принимает
   `player: Node2D`, каждый кадр передаёт `global_position` и направление взгляда в uniform.
3. Плавное затухание при включении/выключении ночного зрения (флаг из `MovementCat`).
4. Шейдер обязан работать с `gl_compatibility` (проект переключать на Vulkan нельзя).

## Acceptance criteria

- [ ] Эффект работает в `gl_compatibility` и на разрешении 1800×800
- [ ] Круг/конус света следует за котом без дрожания
- [ ] Отключение зрения возвращает нормальную картинку

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . scenes/Level_Cat_Cemetry.tscn`

## Заметки и история
