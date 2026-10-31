extends Node
class_name MovementDog

const SPEED: float = 360.0
const JUMP_VELOCITY: float = -580.0
const ACCELERATION: float = 900.0
const DECELERATION: float = 700.0
const GRAVITY: float = 1400.0
const BREAK_SPEED: float = 280.0

const _ANIM_IDLE: PackedScene = preload("res://assets/sprites/dog/anim_dog_idle.tscn")
const _ANIM_RUN: PackedScene = preload("res://assets/sprites/dog/anim_dog_run.tscn")
const _ANIM_JUMP: PackedScene = preload("res://assets/sprites/dog/anim_dog_jump_high.tscn")

var _frames: Dictionary[StringName, SpriteFrames] = {}


func _ready() -> void:
	_cache_animation_frames()


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
	if not is_instance_valid(sprite):
		return
	if _frames.is_empty():
		_cache_animation_frames()
	if not is_zero_approx(player.velocity.x):
		sprite.flip_h = player.velocity.x < 0.0
	var animation: StringName = &"idle"
	if not player.is_on_floor():
		animation = &"jump"
	elif not is_zero_approx(player.velocity.x):
		animation = &"run"
	var frames: SpriteFrames = _frames.get(animation)
	if frames == null or not frames.has_animation(&"default"):
		return
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
	if sprite.animation != &"default" or not sprite.is_playing():
		sprite.play(&"default")


func _cache_animation_frames() -> void:
	if not _frames.is_empty():
		return
	_frames[&"idle"] = _extract_frames(_ANIM_IDLE)
	_frames[&"run"] = _extract_frames(_ANIM_RUN)
	_frames[&"jump"] = _extract_frames(_ANIM_JUMP)


func _extract_frames(scene: PackedScene) -> SpriteFrames:
	var sprite: AnimatedSprite2D = scene.instantiate() as AnimatedSprite2D
	var frames: SpriteFrames = sprite.sprite_frames
	sprite.free()
	return frames
