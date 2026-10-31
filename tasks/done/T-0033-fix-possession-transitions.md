---
id: T-0033
title: Починить вселение в интро и переход на следующий уровень
status: done
form: infra
priority: high
owner: mixey1201
lease_until: 2026-11-01T00:33:55Z
branch: task/T-0033-fix-possession-transitions
paths:
  - scenes/Intro.gd
  - scenes/Intro.tscn
  - scripts/LevelExit.gd
  - scenes/LevelExit.tscn
  - scripts/tests/demo_regression.gd
  - scripts/tests/interaction_regression.gd
depends_on: [T-0032]
created: 2026-11-01
---

## Контекст

После T-0029: призрак проходит сквозь idle-кота (дистанция по X/Y с порогом 110 при разнесении по Y),
медленный; в уровнях нет перехода при касании хоста LevelExit.

## Шаги

1. Intro: быстрый призрак; вселение по пересечению силуэтов (не строгий distance < 110).
2. LevelExit: надёжное срабатывание body_entered / overlap для крупного игрока; переход на next_scene.
3. Регрессии на интро-вселение и выход.

## Acceptance criteria

- [x] Подход призрака к коту запускает вселение и Level_Cat
- [x] Призрак ощутимо быстрее прежнего (не «ползёт»)
- [x] Касание idle-хоста на уровне переключает сцену
- [x] verify / регрессии зелёные

## Проверка

- [x] `pwsh -File scripts/agent/verify.ps1`
- [ ] Ручной прогон: меню → интро → кот → хост-пёс

## Заметки и история
- 2026-10-31T20:44:58Z — работа завершена владельцем mixey1201, ветка task/T-0033-fix-possession-transitions, ожидает PR
