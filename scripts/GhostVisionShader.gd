extends CanvasLayer
class_name GhostVisionShader

const _SHADER: Shader = preload("res://assets/shaders/ghost_vision.gdshader")
const _FADE_SPEED: float = 3.5
const _DEFAULT_DIRECTION: Vector2 = Vector2.RIGHT

@export var player: Node2D = null

var _overlay: ColorRect = null
var _material: ShaderMaterial = null
var _intensity: float = 0.0
var _look_direction: Vector2 = _DEFAULT_DIRECTION


func _ready() -> void:
	layer = 10
	_overlay = ColorRect.new()
	_overlay.name = "VisionOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(1, 1, 1, 1)

	_material = ShaderMaterial.new()
	_material.shader = _SHADER
	_material.set_shader_parameter("intensity", 0.0)
	_overlay.material = _material
	add_child(_overlay)

	if player == null:
		_try_find_player()


func set_player(target: Node2D) -> void:
	player = target


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		_try_find_player()

	var target: float = 1.0 if _is_night_vision_on() else 0.0
	_intensity = move_toward(_intensity, target, _FADE_SPEED * delta)

	if _material == null:
		return

	_material.set_shader_parameter("intensity", _intensity)
	if _intensity <= 0.001 or player == null or not is_instance_valid(player):
		return

	var canvas_pos: Vector2 = player.get_global_transform_with_canvas().origin
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	var uv: Vector2 = canvas_pos / vp_size
	_material.set_shader_parameter("cone_center", uv)
	_material.set_shader_parameter("cone_direction", _resolve_look_direction())


func _try_find_player() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	# ShapeShiftManager — единственный Autoload с доступом к игроку.
	var manager: Node = tree.root.get_node_or_null("ShapeShiftManager")
	if manager != null and manager.has_method("get_player"):
		var registered: Variant = manager.call("get_player")
		if registered is Node2D:
			player = registered as Node2D
			return
	var grouped: Node = tree.get_first_node_in_group("player")
	if grouped is Node2D:
		player = grouped as Node2D


func _is_night_vision_on() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	if not ("current_movement" in player):
		return false
	var movement: Variant = player.get("current_movement")
	if movement == null or not is_instance_valid(movement):
		return false
	if "night_vision_enabled" in movement:
		return bool(movement.night_vision_enabled)
	return false


func _resolve_look_direction() -> Vector2:
	if player == null:
		return _look_direction

	if "animated_sprite" in player:
		var sprite: Variant = player.get("animated_sprite")
		if sprite is AnimatedSprite2D:
			_look_direction = Vector2.LEFT if (sprite as AnimatedSprite2D).flip_h else Vector2.RIGHT
			return _look_direction

	if player is CharacterBody2D:
		var velocity_x: float = (player as CharacterBody2D).velocity.x
		if absf(velocity_x) > 1.0:
			_look_direction = Vector2.RIGHT if velocity_x > 0.0 else Vector2.LEFT

	return _look_direction
