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
| Главная сцена | `scenes/Level_Bird_Rooftops.tscn` (должно стать `MainMenu.tscn` — T-0002) | `run/main_scene="uid://crs113cokr4v8"` |

## Что реализовано на сегодня

| Компонент | Состояние |
|---|---|
| Сцены уровней | 4 сцены-заготовки: только `AudioStreamPlayer` и `Sprite2D` тайлов |
| Скрипты (`scripts/*.gd`) | **все 8 — заглушки `extends Node`, 14 байт** |
| Спрайты кота | 4 набора PNG + 4 сцены `anim_cat_*.tscn` со `SpriteFrames` |
| Спрайты пса, ворона | отсутствуют (T-0010, T-0011) |
| Тайлсет окружения | 13 PNG в `assets/environment/tileset_spooky/` |
| Музыка | 2 mp3 в `assets/audio/` (лицензии — см. `docs/ASSETS.md`) |
| Сцена игрока | отсутствует (T-0003) |
| Шейдеры | отсутствуют (T-0008) |
| Input map | отсутствует (T-0002) |

## Целевая схема узлов

```
Player (CharacterBody2D, scripts/PlayerController.gd)
├── AnimatedSprite2D        спрайты текущей формы
├── CollisionShape2D        коллизия, меняется при смене формы
└── FormPivot (Node2D)      точка для эффекта вспышки при трансформации
```

Компоненты движения — **не узлы сцены, а скрипты** (`MovementCat/Dog/Bird`), которые
`PlayerController` держит в `current_movement` и вызывает `move(player, delta)`.
Это позволяет менять форму без пересоздания сцены.

## Связь файлов

| Файл | Ответственность | Зависит от |
|---|---|---|
| `scripts/PlayerController.gd` | ввод, гравитация, делегирование в форму | `Movement*.gd`, `Player.tscn` |
| `scripts/MovementCat.gd` | бег, прыжок, подползание, `night_vision_enabled` | `PlayerController`, `INPUT_MAP` |
| `scripts/MovementDog.gd` | разгон, высокий прыжок, ломание коробок | `PlayerController` |
| `scripts/MovementBird.gd` | полёт по обеим осям, ветер | `PlayerController`, `WindZone` |
| `scripts/ShapeShiftManager.gd` | Autoload: смена формы, переход уровней, прогресс | `PlayerController` |
| `scripts/GhostVisionShader.gd` | экранная маска темноты с конусом | `assets/shaders/ghost_vision.gdshader` |
| `scripts/Obstacle.gd` | тип препятствия, допустимые формы, сигнал рестарта | чекпоинты уровня |
| `scripts/WindZone.gd` | `Area2D`, передаёт вектор ветра воронам в зоне | `MovementBird` |

## Сцены и их корневые узлы

| Файл | Корень | Замечание |
|---|---|---|
| `scenes/MainMenu.tscn` | `MainMenu` (Node2D) | без кнопок, только музыка (T-0012) |
| `scenes/Level_Cat_Cemetry.tscn` | `LevelCatCemetry` | имя файла с опечаткой («Cemetry») |
| `scenes/Level_Dog_Park.tscn` | `LevelDogBird` | корень назван не по файлу |
| `scenes/Level_Bird_Rooftops.tscn` | `LevelBirdRooftops` | сейчас главная сцена проекта |

## Формы и их механики

| Форма | Скорость | Прыжок | Особое | Ограничение |
|---|---|---|---|---|
| Кот | средняя | обычный | подползание, ночное зрение | не ломает коробки |
| Пёс | высокая | высокий | ломает дерево на скорости | не подползает |
| Ворон | полёт | нет | игнорирует гравитацию, зависит от ветра | нет опоры на землю |

## Правила изменения

* Новую глобальную систему (Autoload, новый input action, изменение рендера) добавлять только
  через `infra`-задачу с `paths: [project.godot]`.
* Каждая новая сцена — в `scenes/`, каждый новый скрипт — в `scripts/`, каждая новая картинка —
  в `assets/sprites/<форма>/` или `assets/environment/`.
* UID ресурсов меняются только движком; файлы `*.import` и `*.uid` руками не правятся.
