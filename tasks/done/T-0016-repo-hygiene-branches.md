---
id: T-0016
title: Гигиена веток — чеклист удаления stale task/* после squash
status: done
form: infra
priority: medium
owner: opencode
lease_until: 2026-10-31T21:32:55Z
branch: task/T-0016-repo-hygiene-branches
paths:
  - tasks/README.md
depends_on: []
created: 2026-10-31
---

## Контекст

После squash-merge часто остаются `origin/task/T-XXXX-*` и локальные `task/*` без лиза.
`status.ps1` тогда орёт «работа брошена». На момент аудита: remote `task/T-0006-dog-movement`,
`task/T-0009-obstacles`; локально — старые T-0002/0003/0010/0011.

Удаление веток — git-операция, не diff игры. В задаче фиксируем процедуру в `tasks/README.md`
и выполняем cleanup в рамках PR (где есть права).

## Шаги

1. В `tasks/README.md` добавить короткий раздел «После squash-merge»: удалить remote
   `task/T-XXXX-*` и локальные одноимённые ветки; `claim/*` снимает только `release.ps1`.
2. Удалить известный мусор (если ещё жив):
   - `git push origin --delete task/T-0006-dog-movement task/T-0009-obstacles` (и аналоги);
   - локально: `git branch -D` для мёртвых `task/T-0002-*`, `T-0003-*`, `T-0010-*`, `T-0011-*`.
3. Не трогать `main`, `claim/*` чужих задач, незакрытые `task/*` с активным лизом.

## Acceptance criteria

- [ ] В `tasks/README.md` есть чеклист пост-merge очистки веток
- [ ] Перечисленные stale remote `task/*` от done-задач удалены (или отмечено «уже нет»)
- [ ] `status.ps1` не жалуется на брошенные ветки T-0006/T-0009

## Проверка

- [ ] `pwsh -File scripts/agent/status.ps1`
- [ ] `git ls-remote origin 'refs/heads/task/*'` — нет веток закрытых задач без открытого PR

## Заметки и история
- 2026-10-31T17:34:16Z — работа завершена владельцем opencode, ветка task/T-0016-repo-hygiene-branches, ожидает PR
