---
id: T-0026
title: Заменить аудио без лицензии на свободные треки
status: done
form: audio
priority: medium
owner: mixey1201
lease_until: 2026-10-31T22:50:15Z
branch: task/T-0026-audio-replace-licensed
paths:
  - assets/audio/
  - docs/ASSETS.md
  - scenes/MainMenu.tscn
  - scenes/Level_Cat_Cemetry.tscn
  - scenes/Level_Dog_Park.tscn
  - scenes/Level_Bird_Rooftops.tscn
depends_on: []
created: 2026-10-31
---

## Контекст

Оба mp3 в `assets/audio/` без подтверждённой лицензии; в имени «Golden Brown» — водяной знак
`lightaudio.ru`. `docs/ASSETS.md` прямо запрещает публикацию до замены. Имена с кириллицей/URL
нарушают правила ASSETS.md.

Можно выполнять параллельно с геймплеем; перед публичным релизом хакатона — обязательно.

## Шаги

1. Подобрать 1–2 трека CC0/CC-BY (Kenney / Freesound / OpenGameArt); скачать в `assets/audio/`
   с `snake_case` латиницей, без доменов в имени.
2. Обновить ссылки `AudioStreamPlayer` в MainMenu и трёх уровнях.
3. Удалить старые mp3 и их `.import` из репозитория.
4. Переписать строки в `docs/ASSETS.md` (источник, лицензия, автор для CC-BY).
5. Импорт через Godot 4.7; руками `.import` не править сверх того, что создал редактор.

## Acceptance criteria

- [ ] В `assets/audio/` нет файлов с неподтверждённой лицензией / водяными знаками в имени
- [ ] ASSETS.md описывает новые треки
- [ ] Меню и уровни играют новый эмбиент без битых uid
- [ ] Размер каждого трека ≤ 5 МБ

## Проверка

- [ ] `pwsh -File scripts/agent/verify.ps1`
- [ ] Запуск MainMenu и одного уровня — звук есть, в консоли нет ошибок загрузки stream

## Заметки и история
- 2026-10-31T18:54:15Z — работа завершена владельцем mixey1201, ветка task/T-0026-audio-replace-licensed, ожидает PR
