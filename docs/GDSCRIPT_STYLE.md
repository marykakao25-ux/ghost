# Стиль GDScript

Правила ориентированы на Godot 4.7 и на код, который будут читать другие агенты. Если сомневаетесь —
посмотрите, как написан соседний файл, и повторите его форму.

## Файлы и имена

| Что | Как | Пример |
|---|---|---|
| Файл скрипта | `snake_case.gd`, но исторические файлы в `PascalCase` не переименовывать | `MovementCat.gd` |
| Корень сцены | `PascalCase.tscn` | `Player.tscn` |
| Узлы | `PascalCase` | `AnimatedSprite2D`, `FormPivot` |
| Переменные, функции | `snake_case` | `crawl_speed`, `apply_wind_force()` |
| Константы | `UPPER_SNAKE_CASE` | `JUMP_VELOCITY` |
| Приватные члены | `_leading_underscore` | `_apply_gravity()` |
| Сигналы | `snake_case`, прошедшее время | `form_changed`, `checkpoint_reset` |

## Форматирование

* **Отступ — табы.** Godot 4 форматирует файлы табами; перевод на пробелы даёт шум в диффе.
* Одна инструкция на строку, без `;`.
* Длина строки — до 100 символов.
* Пустая строка между методами и логическими блоками.
* Порядок в файле: `class_name`/`extends` → `signal` → `enum` → `const` → `@export` → `var` →
  `@onready` → `_init`/`_ready` → встроенные методы (`_process`, `_physics_process`) → публичные →
  приватные.

## Типизация

```gdscript
extends Node
class_name MovementCat

signal night_vision_toggled(enabled: bool)

enum Mode { IDLE, RUN, CRAWL, FALL }

const SPEED: float = 220.0
const JUMP_VELOCITY: float = -420.0

@export var crawl_speed: float = 90.0
var is_crawling: bool = false
@onready var _sprite: AnimatedSprite2D = get_parent().animated_sprite


func move(player: CharacterBody2D, delta: float) -> void:
	...
```

* Все переменные, параметры и возвраты — с типами. `Variant` не оставлять.
* Коллекции — типизированные: `Array[int]`, `Dictionary[String, float]`.
* `-> void` указывать явно.

## Обязательные правила

1. **Никогда `Input.is_action_pressed("ui_*")` для геймплея** — только собственные действия из
   `docs/INPUT_MAP.md`.
2. Не обращаться к глобальному `get_node()` с абсолютным путём. Зависимости — через `@export`,
   `@onready` или параметры методов.
3. `get_node()` в `_process`/`_physics_process` запрещён — кэшируйте в `@onready`.
4. Прямые манипуляции `position` у `CharacterBody2D` — только с `move_and_slide()`;
   телепортация — через `global_position` и `reset_physics_interpolation()` при необходимости.
5. Проверять наличие анимации перед проигрыванием:
   `if sprite.sprite_frames.has_animation(anim): sprite.play(anim)` — спрайтов пса и ворона пока нет.
6. Ошибки ввода-вывода — не глотать: `push_warning()` для ожидаемых, `push_error()` для ошибок.
7. Не использовать `class_name`, если тип не нужен снаружи файла.

## Комментарии

* Документирующие комментарии `##` — для экспортируемых полей (они видны в инспекторе).
* Обычные `#` — только «почему», не «что». Строка `# увеличиваем x на 1` перед `x += 1` — шум.
* Комментарии — по-русски, как и остальные тексты в проекте.

## Сцены (.tscn)

* Не редактировать `.tscn` текстовым редактором, если можно сделать это в Godot.
* Не менять `uid://` вручную.
* Новые узлы называть осмысленно (`Player`, а не `Node2D2`).
* При конфликте merge: `git checkout --ours -- <scene>`, открыть сцену в редакторе, внести правку заново.

## Проверка перед коммитом

```powershell
pwsh -File scripts/agent/verify.ps1
```

Дополнительно, если Godot в PATH: открыть проект и убедиться, что в консоли нет `SCRIPT ERROR`
и `Parse Error`. Предупреждения (жёлтые) — тоже исправлять, если они из вашего файла.
