---
id: T-0049
title: Откат исключения T-0047 и отмена очереди T-0048
status: todo
form: infra
priority: high
owner: null
lease_until: null
branch: null
paths:
  - AGENTS.md
  - tasks/T-0048-strip-cursoragent-trailers.md
  - tasks/done/T-0048-strip-cursoragent-trailers.md
depends_on: []
created: 2026-11-01
---

## Контекст

Владелец попросил откатить изменения, связанные с переписью истории и
исключением force-push. `main` не переписывался (ruleset отклонил
non-fast-forward). Нужно вернуть п. 10 `AGENTS.md` к запрету без исключения
и закрыть T-0048 как отменённую (перенос в `tasks/done/`, не удаление).

T-0047 уже в `tasks/done/` — файл задачи не удалять.

## Шаги

1. Удалить из `AGENTS.md` абзац одноразового исключения T-0047 под пунктом 10.
2. Перенести `tasks/T-0048-strip-cursoragent-trailers.md` в `tasks/done/` со
   `status: done` и заметкой об отмене по запросу владельца.
3. Не трогать git-историю `main` и не делать force-push.

## Acceptance criteria

- [ ] В `AGENTS.md` п. 10 снова только запрет force-push / reset --hard / clean -xfd.
- [ ] T-0048 лежит в `tasks/done/` со `status: done`.
- [ ] `pwsh -File scripts/agent/verify.ps1` зелёный.

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] `git diff --check`

## Заметки и история

Поставлена для отката сессии переписи cursoragent.
