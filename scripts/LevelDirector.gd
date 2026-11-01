extends Node
class_name LevelDirector

const _OBSTACLE_SCENE: PackedScene = preload("res://scenes/Obstacle.tscn")

signal player_respawned(reason: String)

## Директор добавляется дочерним узлом уровня; путь считается от директора.
@export var player_path: NodePath = ^"../Player"
## Ненулевая точка старта. Если не задана, используется начальная позиция игрока.
@export var spawn_point: Vector2 = Vector2.ZERO
## Маркер имеет приоритет над spawn_point, включая начало координат.
@export var spawn_marker: Marker2D = null
@export var level_width: float = 3600.0
@export var level_height: float = 800.0

var _player: PlayerController = null
var _level_root: Node = null
var _spawn_position: Vector2 = Vector2.ZERO
var _respawn_pending: bool = false
var _reset_reason: String = ""


func _ready() -> void:
	add_to_group("level_director")
	_level_root = get_parent()
	_player = get_node_or_null(player_path) as PlayerController
	if _player == null:
		for node: Node in get_tree().get_nodes_in_group("player"):
			if node is PlayerController and _level_root.is_ancestor_of(node):
				_player = node as PlayerController
				break
	if _player == null:
		push_warning("LevelDirector: игрок не найден; проверьте player_path.")
		return
	_player.add_to_group("player")
	ShapeShiftManager.register_player(_player)
	_spawn_position = _player.global_position if spawn_point == Vector2.ZERO else spawn_point
	if is_instance_valid(spawn_marker):
		_spawn_position = spawn_marker.global_position
	_register_box_obstacle()
	register_obstacles()
	_setup_camera()


func _register_box_obstacle() -> void:
	if not is_instance_valid(_level_root):
		return
	var box: Sprite2D = _level_root.get_node_or_null("BoxProp") as Sprite2D
	if box == null or box.texture == null:
		return

	var image: Image = box.texture.get_image()
	var used_rect: Rect2 = Rect2(image.get_used_rect()) if image != null else Rect2()
	if not used_rect.has_area():
		used_rect = Rect2(Vector2.ZERO, box.texture.get_size())

	var obstacle: Obstacle = _OBSTACLE_SCENE.instantiate() as Obstacle
	if obstacle == null:
		push_warning("LevelDirector: не удалось создать препятствие для коробки.")
		return
	obstacle.name = "BoxObstacle"
	obstacle.obstacle_type = Obstacle.ObstacleType.JUMP_OVER
	obstacle.allowed_forms = ["cat"]

	var trigger_shape: CollisionShape2D = obstacle.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if trigger_shape == null:
		obstacle.free()
		push_warning("LevelDirector: у препятствия для коробки нет CollisionShape2D.")
		return
	var box_scale: Vector2 = box.global_scale.abs()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = used_rect.size * box_scale
	trigger_shape.shape = rectangle

	_level_root.add_child(obstacle)
	var center_offset: Vector2 = used_rect.get_center() - box.texture.get_size() * 0.5
	obstacle.global_position = box.to_global(center_offset)


func _setup_camera() -> void:
	if not is_instance_valid(_player):
		return
	var camera: Camera2D = _player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		camera = Camera2D.new()
		camera.name = "Camera2D"
		_player.add_child(camera)
	camera.enabled = true
	camera.make_current()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(level_width)
	camera.limit_bottom = int(level_height)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0


func _physics_process(_delta: float) -> void:
	if is_instance_valid(_player) and _player.global_position.y > 900.0:
		_on_checkpoint_reset("Ты упал. Возвращаемся к последнему фонарю.")


func _exit_tree() -> void:
	if is_instance_valid(_player) and ShapeShiftManager.active_player == _player:
		ShapeShiftManager.active_player = null


func register_obstacles() -> void:
	if not is_instance_valid(_level_root):
		return
	for node: Node in _level_root.find_children("*", "Area2D", true, false):
		if node.has_signal("checkpoint_reset"):
			if not node.is_connected("checkpoint_reset", _on_checkpoint_reset):
				node.connect("checkpoint_reset", _on_checkpoint_reset)


func set_checkpoint(position: Vector2) -> void:
	ShapeShiftManager.set_checkpoint(position)


func respawn_to_checkpoint(reason: String = "Возврат к последнему фонарю.") -> void:
	_on_checkpoint_reset(reason)


func _on_checkpoint_reset(reason: String) -> void:
	if _respawn_pending or not is_instance_valid(_player):
		return
	_respawn_pending = true
	_reset_reason = reason
	# Сигнал приходит из физического callback: перенос выполняется после обхода коллизий.
	_respawn.call_deferred()


func _respawn() -> void:
	if is_instance_valid(_player):
		var checkpoint: Vector2 = ShapeShiftManager.last_checkpoint
		_player.global_position = _spawn_position if checkpoint == Vector2.ZERO else checkpoint
		_player.velocity = Vector2.ZERO
		_player.reset_physics_interpolation()
		player_respawned.emit(_reset_reason)
	_clear_respawn_pending.call_deferred()


func _clear_respawn_pending() -> void:
	_respawn_pending = false
