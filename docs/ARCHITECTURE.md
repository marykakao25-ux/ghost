# Архитектура

Файл описывает **фактическое** состояние репозитория, а не замысел. Если `README.md` противоречит
этому файлу — верьте этому файлу и заведите `infra`-задачу на исправление README.

## Стек

| Параметр | Значение | Источник |
|---|---|---|
| Движок | Godot 4.7 | `project.godot`: `config/features=PackedStringArray("4.7")` |
| Рендерер | `gl_compatibility` (mobile — тоже) | `project.godot` |
| Экран | 1800×800, `canvas_items`, `expand`, окно не ресайзится | `project.godot` |
| Язык | GDScript | `scripts/*.gd` |
| Главная сцена | `scenes/MainMenu.tscn` | `run/main_scene="uid://cv7qr47g7l5ej"` |

## Что реализовано на сегодня

| Компонент | Состояние |
|---|---|
| Сцены уровней | 3 заготовки без Player и физической геометрии; ещё не играбельны (T-0021…T-0023) |
| Меню | Кнопки «Играть» / «Выход», переход в сцену кота |
| Скрипты (`scripts/*.gd`) | Реализованы контроллер, три компонента движения, менеджер, зрение, препятствие и ветер |
| Спрайты кота | 4 набора PNG + 4 сцены `anim_cat_*.tscn` со `SpriteFrames` |
| Спрайты пса, ворона, призрака | PNG и сцены анимаций в `assets/sprites/dog/`, `bird/`, `gg/`; финального уровня ещё нет |
| Тайлсет окружения | 13 PNG в `assets/environment/tileset_spooky/` |
| Музыка | 2 mp3 в `assets/audio/` (лицензии — см. `docs/ASSETS.md`) |
| Сцена игрока | `scenes/Player.tscn`, CharacterBody2D с контроллером |
| Шейдеры | `assets/shaders/ghost_vision.gdshader`, управление через GhostVisionShader (CanvasLayer) |
| Input map | 11 действий в `project.godot`, см. INPUT_MAP.md |
| Препятствия | `scenes/Obstacle.tscn`, Area2D с `checkpoint_reset(reason)`; рестарт выполняет внешний обработчик |

Сборка компонентов в уровни ещё впереди. Регистрацию игрока и респавн добавляет T-0019,
ввод смены формы и паузу — T-0020, ломаемую коробку — T-0018.
MovementDog пока ищет именованные анимации в текущих SpriteFrames вместо загрузки пакетов
с анимацией `default`; исправление — T-0017. Наличие input action не означает наличие обработчика.

## Схема Player.tscn

```
Player (CharacterBody2D, scripts/PlayerController.gd)
├── AnimatedSprite2D        спрайты текущей формы
├── CollisionShape2D        коллизия, меняется при смене формы
└── FormPivot (Node2D)      точка для эффекта вспышки при трансформации
```

`PlayerController` создаёт компонент движения (`MovementCat/Dog/Bird`) как дочерний Node
с именем `Movement`, держит его в `current_movement` и вызывает `move(player, delta)`.
При смене формы старый компонент освобождается, новый создаётся без пересоздания Player.
Каждый компонент сам вызывает `move_and_slide()`; при отсутствии метода move работает
резервная гравитация контроллера. Формы — enum `PlayerController.Form`, а не строки.

## Связь файлов

| Файл | Ответственность | Зависит от |
|---|---|---|
| `scripts/PlayerController.gd` | set_form, коллизия, резервная гравитация, делегирование движения | `Movement*.gd`, `Player.tscn` |
| `scripts/MovementCat.gd` | бег, прыжок, подползание, `night_vision_enabled` | `PlayerController`, `INPUT_MAP` |
| `scripts/MovementDog.gd` | разгон, высокий прыжок, ломание коробок | `PlayerController` |
| `scripts/MovementBird.gd` | полёт по обеим осям, ветер | `PlayerController`, `WindZone` |
| `scripts/ShapeShiftManager.gd` | Autoload: смена формы, переход уровней, прогресс | `PlayerController` |
| `scripts/GhostVisionShader.gd` | экранная маска темноты с конусом | `assets/shaders/ghost_vision.gdshader` |
| `scripts/Obstacle.gd` | Area2D: допустимые формы cat/dog/bird, HAZARD, сигнал с защитой от рекурсии | `PlayerController`, внешний обработчик чекпоинта |
| `scripts/WindZone.gd` | `Area2D`, передаёт вектор ветра воронам в зоне | `MovementBird` |

## Сцены и их корневые узлы

| Файл | Корень | Замечание |
|---|---|---|
| `scenes/MainMenu.tscn` | `MainMenu` (Node2D) | главная сцена, кнопки и музыка, скрипт `scenes/MainMenu.gd` |
| `scenes/Level_Cat_Cemetry.tscn` | `LevelCatCemetry` | имя файла с опечаткой («Cemetry») |
| `scenes/Level_Dog_Park.tscn` | `LevelDogBird` | корень назван не по файлу |
| `scenes/Level_Bird_Rooftops.tscn` | `LevelBirdRooftops` | заготовка уровня ворона |
| `scenes/Player.tscn` | `Player` (CharacterBody2D) | спрайт, коллизия и FormPivot |
| `scenes/Obstacle.tscn` | `Obstacle` (Area2D) | прямоугольная зона 32×32; по умолчанию разрешён кот |

## Формы и их механики

| Форма | Скорость | Прыжок | Особое | Ограничение |
|---|---|---|---|---|
| Кот | средняя | обычный | подползание, ночное зрение | не ломает коробки |
| Пёс | высокая | высокий | вызывает break_apart у breakable на скорости | сцена коробки ещё не создана (T-0018) |
| Ворон | полёт | нет | игнорирует гравитацию, зависит от ветра | нет опоры на землю |

ShapeShiftManager — Autoload: регистрирует игрока, меняет формы с эффектом вспышки,
хранит `last_checkpoint` и прогресс в `user://progress.cfg`, загружает следующую сцену
через `trigger_level_transition(next_scene)`. В уровнях пока нет подключений этого API.
WindZone передаёт силу MovementBird; ограничение скорости уже есть, геометрических границ
и собранных зон на уровне ворона пока нет.

## Правила изменения

* Новую глобальную систему (Autoload, новый input action, изменение рендера) добавлять только
  через `infra`-задачу с `paths: [project.godot]`.
* Каждая новая сцена — в `scenes/`, каждый новый скрипт — в `scripts/`, каждая новая картинка —
  в `assets/sprites/<форма>/` или `assets/environment/`.
* UID ресурсов меняются только движком; файлы `*.import` и `*.uid` руками не правятся.
