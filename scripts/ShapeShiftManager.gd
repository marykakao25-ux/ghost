extends Node

## Autoload ShapeShiftManager: смена формы игрока, переход между уровнями
## и сохранение прогресса. Подключён в project.godot, секция [autoload].

signal form_changed(from_form: int, to_form: int)
signal progress_loaded()
signal transition_started(next_scene: String)

const PROGRESS_PATH: String = "user://progress.cfg"
const PROGRESS_SECTION: String = "progress"

const FLASH_NODE_NAME: String = "FormFlash"
const FLASH_LIFETIME: float = 0.35
const FLASH_AMOUNT: int = 20
const FLASH_COLOR: Color = Color(0.62, 0.9, 1.0, 0.9)

## Все формы, до которых игрок уже добрался.
var unlocked_forms: Array[int] = []
## Позиция последнего чекпоинта (используется уровнями и T-0009).
var last_checkpoint: Vector2 = Vector2.ZERO
## Текущая форма как int (значения — из PlayerController.Form).
var current_form: int = PlayerController.Form.CAT
## Игрок, которым управляет менеджер. Задаётся через register_player().
var active_player: Node = null

var _flash: CPUParticles2D = null


func _ready() -> void:
	if unlocked_forms.is_empty():
		unlocked_forms = [PlayerController.Form.CAT]
	load_progress()


# ------------------------------------------------------------------ игрок ----

func register_player(player: Node) -> void:
	## Вызывается уровнем после появления игрока в сцене.
	active_player = player
	if player.has_signal("form_changed") and not player.form_changed.is_connected(_on_player_form_changed):
		player.form_changed.connect(_on_player_form_changed)


func get_player() -> Node:
	return _resolve_player()


# ------------------------------------------------------------------ формы ----

func change_form(new_form: int) -> bool:
	## Меняет форму: один эффект вспышки, set_form у игрока, сигнал form_changed.
	var player: Node = _resolve_player()
	if player == null:
		push_warning("ShapeShiftManager: нет игрока — сначала register_player().")
		return false
	if not player.has_method("set_form"):
		push_warning("ShapeShiftManager: у игрока нет метода set_form().")
		return false
	if new_form == current_form:
		return false

	var from_form: int = current_form
	_spawn_flash(player)
	current_form = new_form
	_unlock_form(new_form)
	player.set_form(new_form)
	form_changed.emit(from_form, new_form)
	return true


func unlock_form(form: int) -> void:
	_unlock_form(form)


func is_form_unlocked(form: int) -> bool:
	return unlocked_forms.has(form)


# --------------------------------------------------------------- прогресс ----

func set_checkpoint(position: Vector2) -> void:
	last_checkpoint = position


func save_progress() -> bool:
	var config := ConfigFile.new()
	config.set_value(PROGRESS_SECTION, "unlocked_forms", unlocked_forms)
	config.set_value(PROGRESS_SECTION, "last_checkpoint", last_checkpoint)
	config.set_value(PROGRESS_SECTION, "current_form", current_form)

	var err: Error = config.save(PROGRESS_PATH)
	if err != OK:
		push_error("ShapeShiftManager: не удалось сохранить прогресс (%s)." % error_string(err))
		return false
	return true


func load_progress() -> bool:
	var config := ConfigFile.new()
	if config.load(PROGRESS_PATH) != OK:
		return false

	unlocked_forms.clear()
	for form: int in config.get_value(PROGRESS_SECTION, "unlocked_forms", [PlayerController.Form.CAT]):
		unlocked_forms.append(form)
	if unlocked_forms.is_empty():
		unlocked_forms = [PlayerController.Form.CAT]

	last_checkpoint = config.get_value(PROGRESS_SECTION, "last_checkpoint", Vector2.ZERO)
	current_form = int(config.get_value(PROGRESS_SECTION, "current_form", PlayerController.Form.CAT))
	progress_loaded.emit()
	return true


# --------------------------------------------------------------- переходы ----

func trigger_level_transition(next_scene: String) -> bool:
	## Сохраняет прогресс и грузит сцену. Отсутствие файла — ошибка, а не падение.
	if next_scene.is_empty():
		push_error("ShapeShiftManager: пустой путь следующей сцены.")
		return false
	if not ResourceLoader.exists(next_scene):
		push_error("ShapeShiftManager: сцена '%s' не найдена." % next_scene)
		return false

	save_progress()
	transition_started.emit(next_scene)

	var err: Error = get_tree().change_scene_to_file(next_scene)
	if err != OK:
		push_error("ShapeShiftManager: не удалось загрузить '%s' (%s)." % [next_scene, error_string(err)])
		return false
	return true


# ----------------------------------------------------------------- приватное ----

func _resolve_player() -> Node:
	if active_player != null and is_instance_valid(active_player):
		return active_player
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.get_first_node_in_group("player")


func _unlock_form(form: int) -> void:
	if not unlocked_forms.has(form):
		unlocked_forms.append(form)


func _spawn_flash(player: Node) -> void:
	# Один эффект на одну смену формы: предыдущий убираем, если ещё жив.
	if _flash != null and is_instance_valid(_flash):
		_flash.queue_free()
		_flash = null

	var pivot: Node2D = player.get_node_or_null("FormPivot") as Node2D
	if pivot == null:
		return

	var flash := CPUParticles2D.new()
	flash.name = FLASH_NODE_NAME
	flash.amount = FLASH_AMOUNT
	flash.lifetime = FLASH_LIFETIME
	flash.one_shot = true
	flash.explosiveness = 1.0
	flash.direction = Vector2.UP
	flash.spread = 180.0
	flash.gravity = Vector2(0.0, -160.0)
	flash.initial_velocity_min = 40.0
	flash.initial_velocity_max = 120.0
	flash.scale_amount_min = 1.5
	flash.scale_amount_max = 3.0
	flash.color = FLASH_COLOR
	pivot.add_child(flash)

	if flash.has_signal("finished"):
		flash.finished.connect(flash.queue_free)
	else:
		get_tree().create_timer(FLASH_LIFETIME + 0.1).timeout.connect(flash.queue_free)

	flash.emitting = true
	_flash = flash


func _on_player_form_changed(form: int) -> void:
	# Если игрок сменил форму сам, менеджер просто синхронизирует состояние.
	current_form = form
	_unlock_form(form)
