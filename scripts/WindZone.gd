extends Area2D
class_name WindZone

@export var wind_direction: Vector2 = Vector2.RIGHT
@export var wind_strength: float = 120.0

var _bodies_in_zone: Array[Node2D] = []


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	monitoring = true


func _physics_process(_delta: float) -> void:
	if wind_strength == 0.0 or wind_direction == Vector2.ZERO:
		return

	var force: Vector2 = wind_direction.normalized() * wind_strength
	var i: int = 0
	while i < _bodies_in_zone.size():
		var body: Node2D = _bodies_in_zone[i]
		if body == null or not is_instance_valid(body):
			_bodies_in_zone.remove_at(i)
			continue
		_apply_wind_to_body(body, force)
		i += 1


func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if _bodies_in_zone.has(body):
		return
	_bodies_in_zone.append(body)


func _on_body_exited(body: Node2D) -> void:
	_bodies_in_zone.erase(body)


func _apply_wind_to_body(body: Node2D, force: Vector2) -> void:
	if not ("current_movement" in body):
		return
	var movement: Variant = body.get("current_movement")
	if movement == null or not is_instance_valid(movement):
		return
	if movement.has_method("apply_wind_force"):
		movement.apply_wind_force(force)
