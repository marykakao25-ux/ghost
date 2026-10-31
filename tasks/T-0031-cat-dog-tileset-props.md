---
id: T-0031
title: Брёвна, коробки, лужи и овраги из tileset_spooky на кот/пёс
status: todo
form: infra
priority: high
owner: null
lease_until: null
branch: null
paths:
  - scenes/Level_Cat_Cemetry.tscn
  - scenes/Level_Dog_Park.tscn
  - scripts/Obstacle.gd
  - scenes/Obstacle.tscn
  - scripts/BreakableBox.gd
  - scenes/BreakableBox.tscn
  - scripts/LevelPresentation.gd
  - scripts/tests/demo_regression.gd
  - scripts/tests/interaction_regression.gd
depends_on: [T-0030]
created: 2026-11-01
---

## Контекст

На уровнях кота и пса мало реальных пропов из `assets/environment/tileset_spooky/`.
Новые PNG не добавлять — только существующие файлы папки.

| Ассет | Роль |
|---|---|
| `box_to_cat.png` | коробки / лазы кота |
| `puddle.png` | лужи = HAZARD / reset |
| `log.png` | JUMP_OVER для пса |
| `box_to_dog.png` + BreakableBox | ящики |
| `pit.png` | овраг / провал |

Gameplay-узлы со спрайтами из tileset (не прятать единственный визуал в Presentation).

## Шаги

1. Cat: расставить box_to_cat, puddle как рабочие препятствия/опасности.
2. Dog: log, box_to_dog/BreakableBox, pit.
3. Сохранить читаемость после удлинения уровня (T-0030).
4. Обновить тесты на наличие/поведение пропов.

## Acceptance criteria

- [ ] На cat-уровне видны и работают коробки/лужи из tileset
- [ ] На dog-уровне — бревно, ящики, овраг из tileset
- [ ] Нет новых PNG вне tileset_spooky
- [ ] verify и регрессии зелёные

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Визуально в редакторе/игре пропы совпадают с файлами tileset

## Заметки и история
