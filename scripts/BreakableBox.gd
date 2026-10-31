extends StaticBody2D
class_name BreakableBox

var _broken: bool = false

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("breakable")


func break_apart() -> void:
	if _broken:
		return
	_broken = true
	remove_from_group("breakable")
	hide()
	# Удар может обрабатываться внутри физического callback: коллизию меняем отложенно.
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if is_instance_valid(_collision):
		_collision.set_deferred("disabled", true)
	queue_free()
