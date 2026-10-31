---
id: T-0014
title: claims-guard — не создавать issue на squash-merge PR человеком
status: done
form: infra
priority: high
owner: mixey1201
lease_until: 2026-10-31T19:46:35Z
branch: task/T-0014-claims-guard-pr-merge
paths:
  - .github/workflows/claims-guard.yml
depends_on: []
created: 2026-10-31
---

## Контекст

`claims-guard.yml` сейчас пропускает только `github.actor == github-actions[bot]`.
Squash-merge через UI идёт от человека → ложные issues (#13, #16, #18, #21; прецедент #10).
Реальные прямые push (без PR) должны по-прежнему открывать issue (как #20).

API: `GET /repos/{owner}/{repo}/commits/{sha}/pulls` — для merge-коммита PR список
не пуст и у PR есть `merged_at`; для чистого push — пусто.

## Шаги

1. В шаге «Сообщить о нарушении» после проверки bot: запросить associated pulls для `$SHA`.
2. Если есть PR с `merged_at` — выйти без создания issue (лог: штатный merge).
3. Иначе — создавать issue как сейчас.
4. Комментарий в шапке workflow обновить: merge человеком тоже штатный путь.

## Acceptance criteria

- [ ] Push с associated merged PR не создаёт issue
- [ ] Прямой push без PR по-прежнему создаёт issue
- [ ] Отката коммитов по-прежнему нет (наблюдательный режим)

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Ревью diff workflow в PR

## Заметки и история
- 2026-10-31T15:50:01Z — работа завершена владельцем mixey1201, ветка task/T-0014-claims-guard-pr-merge, ожидает PR
