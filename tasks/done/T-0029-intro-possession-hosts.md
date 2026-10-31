---
id: T-0029
title: Интро призрака, вселение в сосуды и масштаб героя
status: done
form: infra
priority: high
owner: mixey1201
lease_until: 2026-11-01T00:08:05Z
branch: task/T-0029-intro-possession-hosts
paths:
  - scenes/MainMenu.gd
  - scenes/MainMenu.tscn
  - scenes/Intro.tscn
  - scenes/Intro.gd
  - scenes/HostVessel.tscn
  - scripts/HostVessel.gd
  - scripts/LevelExit.gd
  - scenes/LevelExit.tscn
  - scripts/PlayerController.gd
  - scripts/MovementCat.gd
  - scripts/MovementDog.gd
  - scripts/MovementBird.gd
  - scripts/ShapeShiftManager.gd
  - scripts/LevelPresentation.gd
  - scenes/Level_Cat_Cemetry.tscn
  - scenes/Level_Dog_Park.tscn
  - scenes/Level_Bird_Rooftops.tscn
  - scenes/Player.tscn
  - scripts/tests/demo_regression.gd
  - scripts/tests/interaction_regression.gd
depends_on: [T-0028]
created: 2026-11-01
---

## Контекст

README описывает лор («призрак хочет почувствовать себя живым»), но игра стартует сразу котом,
а выход — зелёная дверь LevelExit. Нужны интро, вселение в idle-сосуды и крупный герой.

Целевой видимый рост (высота экрана 800 px):

| Форма | Доля | ≈ высота |
|---|---|---|
| Призрак | 1/4 | ~200 px |
| Кот / пёс | 1/5 | ~160 px |
| Ворон | 1/6 | ~133 px |

`dog_idle` — лёжка: только у неподвижного хоста. Управляемый пёс — run/jump.

## Шаги

1. Intro-сцена: текст про желание чувствовать жизнь; призрак подходит к idle-кошке и вселяется.
2. MainMenu «Играть» → Intro → Level_Cat после вселения.
3. Заменить смысл выхода: HostVessel (idle пёс/ворон) вместо «двери»; касание = вселение + переход.
4. Масштаб спрайтов/коллайдеров по таблице; crawl-коллайдер кота согласовать.
5. MovementDog: не использовать lying idle у активной формы.
6. Обновить objectives HUD (вселение, не «зелёный выход»).
7. Обновить регрессии.

## Acceptance criteria

- [ ] Видно интро/тему «хочет почувствовать себя живым»
- [ ] Призрак вселяется в idle-кота, затем геймплей котом
- [ ] Конец cat/dog — idle-следующий зверь + вселение/переход
- [ ] Управляемый пёс не проигрывает lying idle
- [ ] Видимый рост ≈ 1/4 · 1/5 · 1/6 высоты экрана (±10%)
- [ ] verify.ps1 и регрессии зелёные

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `godot --path . --headless --quit` без SCRIPT/Parse Error
- [ ] `scripts/tests/demo_regression.gd` и `interaction_regression.gd`

## Заметки и история
- 2026-10-31T20:18:59Z — работа завершена владельцем mixey1201, ветка task/T-0029-intro-possession-hosts, ожидает PR
