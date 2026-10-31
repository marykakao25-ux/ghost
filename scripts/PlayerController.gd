extends CharacterBody2D
class_name PlayerController

signal form_changed(form: Form)

enum Form { CAT, DOG, BIRD }

const CAT_CAPSULE_RADIUS: float = 10.0
const CAT_CAPSULE_HEIGHT: float = 28.0
const DOG_CAPSULE_RADIUS: float = 14.0
const DOG_CAPSULE_HEIGHT: float = 40.0
const BIRD_CIRCLE_RADIUS: float = 12.0

const _MOVEMENT_SCRIPTS: Dictionary = {
	Form.CAT: preload("res://scripts/MovementCat.gd"),
	Form.DOG: preload("res://scripts/MovementDog.gd"),
	Form.BIRD: preload("res://scripts/MovementBird.gd"),
}

var current_form: Form = Form.CAT
var current_movement: Node = null

var _pause_layer: CanvasLayer = null
var _owns_pause: bool = false

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
	set_form(current_form)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if current_movement != null and current_movement.has_method("move"):
		current_movement.move(self, delta)
	else:
		_apply_default_gravity(delta)
		move_and_slide()


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


func _create_pause_overlay() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.name = "PauseOverlay"
	_pause_layer.layer = 100
	add_child(_pause_layer)
	var shade: ColorRect = ColorRect.new()
	shade.name = "Shade"
	shade.color = Color(0.0, 0.0, 0.0, 0.7)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(shade)
	var label: Label = Label.new()
	label.text = "Пауза\nEsc — продолжить"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(label)


func set_form(form: Form) -> void:
	_ensure_child_refs()
	var feet_y: float = _get_collider_bottom_y()
	current_form = form
	_apply_collision_for_form(form)
	_align_feet_to(feet_y)
	_swap_movement(form)
	form_changed.emit(form)


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
	match form:
		Form.CAT:
			var capsule_cat := CapsuleShape2D.new()
			capsule_cat.radius = CAT_CAPSULE_RADIUS
			capsule_cat.height = CAT_CAPSULE_HEIGHT
			collision_shape.shape = capsule_cat
		Form.DOG:
			var capsule_dog := CapsuleShape2D.new()
			capsule_dog.radius = DOG_CAPSULE_RADIUS
			capsule_dog.height = DOG_CAPSULE_HEIGHT
			collision_shape.shape = capsule_dog
		Form.BIRD:
			var circle := CircleShape2D.new()
			circle.radius = BIRD_CIRCLE_RADIUS
			collision_shape.shape = circle


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
