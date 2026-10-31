---
id: T-0033
title: Починить вселение в интро и переход на следующий уровень
status: todo
form: infra
priority: high
owner: null
lease_until: null
branch: null
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

- [ ] Подход призрака к коту запускает вселение и Level_Cat
- [ ] Призрак ощутимо быстрее прежнего (не «ползёт»)
- [ ] Касание idle-хоста на уровне переключает сцену
- [ ] verify / регрессии зелёные

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Ручной прогон: меню → интро → кот → хост-пёс

## Заметки и история
