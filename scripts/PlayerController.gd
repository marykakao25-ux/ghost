extends CharacterBody2D
class_name PlayerController

signal form_changed(form: Form)

enum Form { CAT, DOG, BIRD }

## Высота экрана 800: кот/пёс ≈ 1/5, ворон ≈ 1/6 (капсула: height + 2*radius).
const CAT_CAPSULE_RADIUS: float = 36.0
const CAT_CAPSULE_HEIGHT: float = 88.0
const DOG_CAPSULE_RADIUS: float = 40.0
const DOG_CAPSULE_HEIGHT: float = 80.0
const BIRD_CIRCLE_RADIUS: float = 66.0
const SCREEN_HEIGHT: float = 800.0
const MAIN_MENU_PATH: String = "res://scenes/MainMenu.tscn"

const _MOVEMENT_SCRIPTS: Dictionary = {
	Form.CAT: preload("res://scripts/MovementCat.gd"),
	Form.DOG: preload("res://scripts/MovementDog.gd"),
	Form.BIRD: preload("res://scripts/MovementBird.gd"),
}

var current_form: Form = Form.CAT
var current_movement: Node = null

var _pause_layer: CanvasLayer = null
var _owns_pause: bool = false
var _collision_pending: bool = false
var _texture_bounds: Dictionary[Texture2D, Rect2] = {}
var _effects_enabled: bool = true

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var form_pivot: Node2D = $FormPivot


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("player")
	ShapeShiftManager.register_player(self)
	animated_sprite = $AnimatedSprite2D
	animated_sprite.process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_shape = $CollisionShape2D
	form_pivot = $FormPivot
	animated_sprite.frame_changed.connect(_update_visual)
	animated_sprite.sprite_frames_changed.connect(_update_visual)
	set_form(current_form)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if _collision_pending and not _movement_is_crawling():
		_apply_form_collision()
	if current_movement != null and current_movement.has_method("move"):
		current_movement.move(self, delta)
	else:
		_apply_default_gravity(delta)
		move_and_slide()
	_update_visual()


func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
	if ShapeShiftManager.active_player == self:
		ShapeShiftManager.active_player = null


func _unhandled_input(event: InputEvent) -> void:
	if ShapeShiftManager.get_player() != self:
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return
	var requested_form: Form = current_form
	if event.is_action_pressed("shapeshift_cat"):
		requested_form = Form.CAT
	elif event.is_action_pressed("shapeshift_dog"):
		requested_form = Form.DOG
	elif event.is_action_pressed("shapeshift_bird"):
		requested_form = Form.BIRD
	elif event.is_action_pressed("shapeshift"):
		requested_form = _get_next_unlocked_form()
	else:
		return
	get_viewport().set_input_as_handled()
	if ShapeShiftManager.is_form_unlocked(requested_form):
		ShapeShiftManager.change_form(requested_form)


func _get_next_unlocked_form() -> Form:
	for offset: int in range(1, Form.size()):
		var candidate: Form = ((int(current_form) + offset) % Form.size()) as Form
		if ShapeShiftManager.is_form_unlocked(candidate):
			return candidate
	return current_form


func _toggle_pause() -> void:
	if _pause_layer == null:
		_create_pause_overlay()
	get_tree().paused = not get_tree().paused
	_owns_pause = get_tree().paused
	_pause_layer.visible = get_tree().paused
	if get_tree().paused:
		var menu: Node = _pause_layer.get_node_or_null("MenuCenter/Menu")
		if menu != null and menu.get_child_count() > 1:
			(menu.get_child(1) as Control).grab_focus()
	_sync_atmosphere()


func _create_pause_overlay() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseOverlay"
	_pause_layer.layer = 100
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)
	var shade: ColorRect = ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(shade)
	var panel_size := Vector2(320.0, 280.0)
	var center: CenterContainer = CenterContainer.new()
	center.name = "MenuCenter"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pause_layer.add_child(center)
	var panel: VBoxContainer = VBoxContainer.new()
	panel.name = "Menu"
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_theme_constant_override("separation", 12)
	panel.custom_minimum_size = panel_size
	# CenterContainer на весь viewport центрирует фактический размер панели:
	# меню не «уезжает» при разрешениях, отличных от 1800x800, и когда
	# содержимое больше custom_minimum_size.
	center.add_child(panel)
	var title: Label = Label.new()
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	panel.add_child(title)
	_add_pause_button(panel, "Продолжить", _on_pause_resume)
	_add_pause_button(panel, "К чекпоинту", _on_pause_checkpoint)
	_add_pause_button(panel, "В меню", _on_pause_menu)
	_add_pause_button(panel, "Эффекты: вкл", _on_pause_effects)
	_add_pause_button(panel, "Выход", _on_pause_quit)


func _add_pause_button(parent: Node, text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280.0, 40.0)
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _on_pause_resume() -> void:
	if get_tree().paused:
		_toggle_pause()


func _on_pause_checkpoint() -> void:
	_on_pause_resume()
	var director: Node = get_tree().get_first_node_in_group("level_director")
	if director == null:
		var parent_node: Node = get_parent()
		if parent_node != null:
			director = parent_node.get_node_or_null("LevelDirector")
	if director != null and director.has_method("respawn_to_checkpoint"):
		director.call("respawn_to_checkpoint", "Возврат к последнему фонарю.")


func _on_pause_menu() -> void:
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_pause_effects() -> void:
	_effects_enabled = not _effects_enabled
	_sync_atmosphere()
	if _pause_layer == null:
		return
	var menu: Node = _pause_layer.get_node_or_null("MenuCenter/Menu")
	if menu == null or menu.get_child_count() < 5:
		return
	var effects_button: Button = menu.get_child(4) as Button
	if effects_button != null:
		effects_button.text = "Эффекты: вкл" if _effects_enabled else "Эффекты: выкл"


func _on_pause_quit() -> void:
	if _owns_pause:
		get_tree().paused = false
		_owns_pause = false
	get_tree().quit()


func _sync_atmosphere() -> void:
	var enabled: bool = _effects_enabled and not get_tree().paused
	get_tree().call_group("level_presentation", "set_atmosphere_enabled", enabled)


func set_form(form: Form) -> bool:
	_ensure_child_refs()
	if form < 0 or form >= Form.size():
		return false
	current_form = form
	# Управление и спрайт меняются всегда: отказ из-за пересечения геометрии
	# не должен оставлять игрока без компонента движения (см. T-0034).
	_swap_movement(form)
	_apply_form_collision()
	_update_visual()
	form_changed.emit(form)
	return true


func _apply_form_collision() -> void:
	if not can_set_form(current_form):
		_collision_pending = true
		return
	_collision_pending = false
	var feet_y: float = _get_collider_bottom_y()
	_apply_collision_for_form(current_form)
	_align_feet_to(feet_y)


func _movement_is_crawling() -> bool:
	return current_movement is MovementCat and (current_movement as MovementCat).is_crawling


func can_set_form(form: int) -> bool:
	if form < 0 or form >= Form.size():
		return false
	if not is_inside_tree() or collision_shape == null:
		return true
	var shape: Shape2D = _make_form_shape(form as Form)
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	query.transform = global_transform
	query.transform.origin.y = _get_collider_bottom_y() - shape.get_rect().end.y
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_visual() -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = animated_sprite.sprite_frames
	if not frames.has_animation(animated_sprite.animation):
		return
	var texture: Texture2D = frames.get_frame_texture(
		animated_sprite.animation, animated_sprite.frame
	)
	if texture == null or collision_shape == null or collision_shape.shape == null:
		return
	if not _texture_bounds.has(texture):
		var image: Image = texture.get_image()
		var used: Rect2 = Rect2(image.get_used_rect()) if image != null else Rect2()
		if not used.has_area():
			used = Rect2(Vector2.ZERO, texture.get_size())
		_texture_bounds[texture] = used
	var bounds: Rect2 = _texture_bounds[texture]
	if not bounds.has_area():
		bounds = Rect2(Vector2.ZERO, texture.get_size())
	var target_h: float = SCREEN_HEIGHT / 5.0
	if current_form == Form.BIRD:
		target_h = SCREEN_HEIGHT / 6.0
	# Масштаб по высоте силуэта — доля экрана (кот/пёс 1/5, ворон 1/6).
	var ratio: float = target_h / maxf(bounds.size.y, 1.0)
	animated_sprite.scale = Vector2(ratio, ratio)
	# Ползущий кот ниже стоячего коллайдера — слегка прижимаем спрайт.
	if current_form == Form.CAT and collision_shape.shape.get_rect().size.y < 100.0:
		animated_sprite.scale.y *= 0.55
	# У PNG разные поля и размеры: выравниваем непрозрачные пиксели, а не весь холст.
	var offset: Vector2 = texture.get_size() * 0.5 - bounds.get_center()
	if animated_sprite.flip_h:
		offset.x = -offset.x
	animated_sprite.offset = offset
	var bottom: float = collision_shape.position.y + collision_shape.shape.get_rect().end.y
	animated_sprite.position = Vector2(
		collision_shape.position.x, bottom - bounds.size.y * animated_sprite.scale.y * 0.5
	)


func _ensure_child_refs() -> void:
	if animated_sprite == null:
		animated_sprite = $AnimatedSprite2D
	if collision_shape == null:
		collision_shape = $CollisionShape2D
	if form_pivot == null:
		form_pivot = $FormPivot


func _apply_default_gravity(delta: float) -> void:
	var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	if not is_on_floor():
		velocity.y += gravity * delta


func _get_collider_bottom_y() -> float:
	if collision_shape == null or collision_shape.shape == null:
		return global_position.y
	var shape: Shape2D = collision_shape.shape
	var local_bottom: float = shape.get_rect().end.y + collision_shape.position.y
	return to_global(Vector2(0.0, local_bottom)).y


func _align_feet_to(feet_y: float) -> void:
	var new_bottom: float = _get_collider_bottom_y()
	global_position.y += feet_y - new_bottom


func _apply_collision_for_form(form: Form) -> void:
	collision_shape.position = Vector2.ZERO
	collision_shape.shape = _make_form_shape(form)


func _make_form_shape(form: Form) -> Shape2D:
	match form:
		Form.CAT:
			var capsule_cat := CapsuleShape2D.new()
			capsule_cat.radius = CAT_CAPSULE_RADIUS
			capsule_cat.height = CAT_CAPSULE_HEIGHT
			return capsule_cat
		Form.DOG:
			var capsule_dog := CapsuleShape2D.new()
			capsule_dog.radius = DOG_CAPSULE_RADIUS
			capsule_dog.height = DOG_CAPSULE_HEIGHT
			return capsule_dog
		Form.BIRD:
			var circle := CircleShape2D.new()
			circle.radius = BIRD_CIRCLE_RADIUS
			return circle
	return null


func _swap_movement(form: Form) -> void:
	if current_movement != null and is_instance_valid(current_movement):
		remove_child(current_movement)
		current_movement.free()
		current_movement = null

	if not _MOVEMENT_SCRIPTS.has(form):
		push_warning("PlayerController: нет скрипта движения для формы %s" % form)
		return

	var script: GDScript = _MOVEMENT_SCRIPTS[form] as GDScript
	var movement: Node = script.new() as Node
	movement.name = "Movement"
	movement.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(movement)
	current_movement = movement
