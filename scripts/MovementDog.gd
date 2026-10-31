extends Node
class_name MovementDog

const SPEED: float = 360.0
const JUMP_VELOCITY: float = -580.0
const ACCELERATION: float = 900.0
const DECELERATION: float = 700.0
const GRAVITY: float = 1400.0
const BREAK_SPEED: float = 280.0


func move(player: CharacterBody2D, delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var acceleration: float = ACCELERATION if direction != 0.0 else DECELERATION
	player.velocity.x = move_toward(player.velocity.x, direction * SPEED, acceleration * delta)
	if not player.is_on_floor():
		player.velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.velocity.y = JUMP_VELOCITY

	# move_and_slide обнуляет скорость при ударе о стену; нужна скорость до удара.
	var impact_speed: float = player.velocity.x
	player.move_and_slide()
	for index: int in range(player.get_slide_collision_count()):
		var collision: KinematicCollision2D = player.get_slide_collision(index)
		if collision.get_normal().x * impact_speed < 0.0:
			check_obstacle_break(collision.get_collider() as Node, impact_speed)
	_update_animation(player)


func check_obstacle_break(body: Node, impact_speed: float) -> void:
	if not is_instance_valid(body) or absf(impact_speed) < BREAK_SPEED:
		return
	if body.is_in_group("breakable") and body.has_method("break_apart"):
		body.call("break_apart")


func _update_animation(player: CharacterBody2D) -> void:
	var sprite: AnimatedSprite2D = player.get("animated_sprite") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	if not is_zero_approx(player.velocity.x):
		sprite.flip_h = player.velocity.x < 0.0
	var animation: StringName = &"dog_idle"
	if not player.is_on_floor():
		animation = &"dog_jump_high"
	elif not is_zero_approx(player.velocity.x):
		animation = &"dog_run"
	if sprite.sprite_frames.has_animation(animation):
		sprite.play(animation)
