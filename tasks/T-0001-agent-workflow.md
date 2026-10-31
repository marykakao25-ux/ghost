---
id: T-0001
title: Инфраструктура ИИ-процесса (AGENTS.md, docs, скрипты агентов)
status: in-progress
form: infra
priority: high
owner: cline
lease_until: null
branch: chore/agent-workflow
paths:
  - AGENTS.md
  - CLAUDE.md
  - GEMINI.md
  - .cursor/rules
  - .github/copilot-instructions.md
  - .github/PULL_REQUEST_TEMPLATE.md
  - .github/workflows
  - docs
  - tasks
  - scripts/agent
  - README.md
  - .gitignore
depends_on: []
created: 2026-10-31
---

## Контекст

В репозитории не было ни одного файла с инструкциями для ИИ-агентов, а данные о задачах
и правила ветвления не были формализованы. Из-за этого два агента могли одновременно править
один файл и терять работу друг друга.

Эта задача вводит:

* `AGENTS.md` — единые инструкции для всех агентов + тонкие обёртки под конкретные инструменты;
* `docs/` — архитектура, стиль GDScript, карта ввода, учёт ассетов и лицензий;
* `tasks/` — очередь задач, лизы (`tasks/claims/`), завершённые (`tasks/done/`);
* `scripts/agent/` — `claim`, `release`, `status`, `heartbeat`, `force-release`, `verify`;
* блокировку по схеме A+B (см. `tasks/README.md`).

## Шаги

1. Написать канон `AGENTS.md` и обёртки для Cursor / Copilot / Claude / Gemini.
2. Описать задачи в `tasks/` с контрактом `paths`.
3. Реализовать скрипты захвата/освобождения задачи.
4. Добавить CI-стражи `agent-guard.yml` и `claims-guard.yml`.
5. Исправить ошибки в `README.md` (см. историю задачи) и расхождения с реальным репозиторием.
6. Проверить сквозной сценарий: двойной захват одной задачи должен падать на лок-ветке.

## Acceptance criteria

- [x] `AGENTS.md` описывает запреты, рабочий цикл и Definition of Done и доступен всем агентам
- [x] `scripts/agent/claim.ps1` блокирует задачу через ветку `claim/T-XXXX` (слой B) и лиз-файл (слой A)
- [x] Повторный захват той же задачи тем же/другим агентом отвергается
- [x] Задача с пересекающимися `paths` не берётся
- [x] `verify.ps1 -SelfTest` зелёный
- [ ] На GitHub включён Ruleset для `main` (force-push/удаление запрещены) — вручную владельцем репозитория

## Проверка

- [x] `pwsh -File scripts/agent/verify.ps1 -SelfTest`
- [x] `pwsh -File scripts/agent/verify.ps1`
- [x] Сквозной тест claim → повторный claim (ожидается отказ) → release

## Заметки и история
