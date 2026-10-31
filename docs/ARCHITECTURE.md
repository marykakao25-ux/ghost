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
| Сцены уровней | 3 играбельных уровня (кот/пёс/ворон) + Intro и Finale; в уровнях — LevelDirector, LevelExit-хост, Obstacle, чекпоинты, Presentation (HUD/фон/атмосфера) — T-0021…T-0024 |
| Меню | Кнопки «Играть» / «Выход», музыка, переход через Intro |
| Скрипты (`scripts/*.gd`) | PlayerController, MovementCat/Dog/Bird, ShapeShiftManager, LevelDirector, LevelExit/HostVessel, BreakableBox, Obstacle, WindZone, GhostVisionShader, LevelPresentation; Intro/Finale — сценовые скрипты |
| Спрайты кота | 4 набора PNG + 4 сцены `anim_cat_*.tscn` со `SpriteFrames` |
| Спрайты пса, ворона, призрака | PNG и сцены анимаций в `assets/sprites/dog/`, `bird/`, `gg/`; финальная сцена `scenes/Finale.tscn` (T-0025) |
| Тайлсет окружения | 13 PNG в `assets/environment/tileset_spooky/` |
| Музыка | 2 mp3 в `assets/audio/` (лицензии — см. `docs/ASSETS.md`) |
| Сцена игрока | `scenes/Player.tscn`, CharacterBody2D с контроллером |
| Шейдеры | `assets/shaders/ghost_vision.gdshader` (GhostVisionShader), `assets/shaders/atmosphere.gdshader` (LevelPresentation) |
| Input map | 11 действий в `project.godot`; `shapeshift*` не обрабатываются — ручное переключение убрано (T-0036), см. INPUT_MAP.md |
| Препятствия | `scenes/Obstacle.tscn`, Area2D с `checkpoint_reset(reason)`; обрабатывает LevelDirector |
| Коробки, ветер, выходы | `scenes/BreakableBox.tscn` (T-0018), `scenes/WindZone.tscn` (T-0007), `scenes/LevelExit.tscn` + алиас `scripts/HostVessel.gd` |

Уровни подключены к API менеджера: `LevelDirector` регистрирует игрока
(`register_player`) и респавнит по чекпоинтам; инлайн-скрипты уровней выставляют
форму при старте; `LevelExit` при касании выполняет вселение и переход
(`unlock_form` + `trigger_level_transition`). Пауза, возврат к чекпоинту и
фокус кнопок — в `PlayerController`. Смена формы автоматическая (T-0036):
`ShapeShiftManager.change_form()` → `PlayerController.set_form()`; `set_form`
всегда оставляет игроку компонент движения, а новую форму коллайдера
откладывает до освобождения геометрии (T-0034). Наличие input action
по-прежнему не означает наличия обработчика.

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
| `scenes/Intro.tscn` | `Intro` (Node2D) | пролог призрака, вселение в кота (T-0029) |
| `scenes/Level_Cat_Cemetry.tscn` | `LevelCatCemetry` | уровень кота; имя файла с опечаткой («Cemetry») |
| `scenes/Level_Dog_Park.tscn` | `LevelDogPark` | уровень пса, BreakableBox, Jump-препятствия |
| `scenes/Level_Bird_Rooftops.tscn` | `LevelBirdRooftops` | уровень ворона: крыши, WindZone, потолок и стены |
| `scenes/Finale.tscn` | `Finale` (Control) | эпилог призрака, возврат в меню (T-0025) |
| `scenes/Player.tscn` | `Player` (CharacterBody2D) | спрайт, коллизия и FormPivot; Camera2D добавляет LevelDirector |
| `scenes/Obstacle.tscn` | `Obstacle` (Area2D) | прямоугольная зона 32×32; по умолчанию разрешён кот |
| `scenes/LevelExit.tscn` | `LevelExit` (Area2D) | idle-хост следующей формы; `scripts/HostVessel.gd` — совместимый алиас |
| `scenes/BreakableBox.tscn` | `BreakableBox` (StaticBody2D) | ломается псом на скорости (T-0018) |
| `scenes/WindZone.tscn` | `WindZone` (Area2D) | толкает MovementBird в своей зоне (T-0007) |

## Формы и их механики

| Форма | Скорость | Прыжок | Особое | Ограничение |
|---|---|---|---|---|
| Кот | средняя | обычный | подползание, ночное зрение | не ломает коробки |
| Пёс | высокая | высокий | вызывает break_apart у breakable на скорости | коробка готова: `scenes/BreakableBox.tscn` (T-0018) |
| Ворон | полёт | нет | игнорирует гравитацию, зависит от ветра | нет опоры на землю |

ShapeShiftManager — Autoload: регистрирует игрока, меняет формы с эффектом
вспышки и призрака-«вселения», хранит `last_checkpoint` и прогресс в
`user://progress.cfg`, загружает следующую сцену через
`trigger_level_transition(next_scene)` (это делает `LevelExit`). Ручного
переключения форм в игре нет (T-0036); `current_form` менеджера синхронизируется
сигналом игрока `form_changed`. WindZone передаёт силу MovementBird; на уровне
ворона есть стены, потолок и собранные зоны ветра (T-0023, T-0032).

## Правила изменения

* Новую глобальную систему (Autoload, новый input action, изменение рендера) добавлять только
  через `infra`-задачу с `paths: [project.godot]`.
* Каждая новая сцена — в `scenes/`, каждый новый скрипт — в `scripts/`, каждая новая картинка —
  в `assets/sprites/<форма>/` или `assets/environment/`.
* UID ресурсов меняются только движком; файлы `*.import` и `*.uid` руками не правятся.
