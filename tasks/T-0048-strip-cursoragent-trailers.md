---
id: T-0048
title: Удалить трейлеры cursoragent из истории main
status: claimed
form: infra
priority: high
owner: mixey1201
lease_until: 2026-11-01T18:32:11Z
branch: task/T-0048-strip-cursoragent-trailers
paths:
  - AGENTS.md
depends_on:
  - T-0047
created: 2026-11-01
---

## Контекст

GitHub показывает `cursoragent` как соавтора из-за 26 сообщений с
`Co-authored-by: Cursor <cursoragent@cursor.com>` (первый `95727a1`, последний
`d67c091` на момент постановки). T-0047 внесло одноразовое исключение в
`AGENTS.md` п. 10 для `git push --force-with-lease` после этой переписи.
Перепись выполняется **вне рабочей копии**, в свежем клоне. Деревья файлов
не меняются; `paths` нужен только для снятия исключения после успеха.

## Шаги

1. Зеркальная копия: `git clone --mirror` репозитория.
2. Свежий клон; `git-filter-repo --message-callback` удаляет **только** строки
   `Co-authored-by: Cursor <cursoragent@cursor.com>`. Авторов, коммиттеров,
   остальные трейлеры и содержимое файлов не трогать.
3. Проверки до пуша:
   - `git log --all -i --grep=cursoragent` пуст;
   - `git diff --stat <старый-main> HEAD` пуст;
   - число коммитов в `main` не изменилось.
4. `git push --force-with-lease=main:<SHA-на-момент-бэкапа> origin main`.
   Если GitHub ruleset отклонит — остановиться и запросить admin.
5. После успешного обновления `main` снять исключение T-0047 из `AGENTS.md`
   отдельным коммитом в этой же задаче (единственная правка файлов).

## Acceptance criteria

- [ ] В reachable истории `main` нет `cursoragent@cursor.com` / `Co-authored-by: Cursor`.
- [ ] Деревья файлов совпадают со старым `main`.
- [ ] Исключение T-0047 удалено из `AGENTS.md`.
- [ ] `pwsh -File scripts/agent/verify.ps1` зелёный (после правки AGENTS.md).

## Проверка

- [ ] `git log --all -i --grep=cursoragent`
- [ ] `git diff --stat <backup-main> origin/main`
- [ ] `pwsh -File scripts/agent/verify.ps1`

## Заметки и история

Открытые PR/клоны коллег нужно будет пересинхронизировать (`git fetch && git reset --hard origin/main`).
`refs/pull/*` не переписываются — старые SHA могут ещё показывать cursoragent на страницах PR.
