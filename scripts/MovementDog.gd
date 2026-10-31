extends Node
class_name MovementDog

const SPEED: float = 360.0
const JUMP_VELOCITY: float = -580.0
const ACCELERATION: float = 900.0
const DECELERATION: float = 700.0
const GRAVITY: float = 1400.0
const BREAK_SPEED: float = 280.0
const PUSH_BREAK_SPEED: float = 200.0

const _ANIM_IDLE: PackedScene = preload("res://assets/sprites/dog/anim_dog_idle.tscn")
const _ANIM_RUN: PackedScene = preload("res://assets/sprites/dog/anim_dog_run.tscn")
const _ANIM_JUMP: PackedScene = preload("res://assets/sprites/dog/anim_dog_jump_high.tscn")

var _frames: Dictionary[StringName, SpriteFrames] = {}
var _push_hold: float = 0.0


func _ready() -> void:
	_cache_animation_frames()


func move(player: CharacterBody2D, delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	var intended_x: float = direction * SPEED
	var acceleration: float = ACCELERATION if direction != 0.0 else DECELERATION
	player.velocity.x = move_toward(player.velocity.x, intended_x, acceleration * delta)
	if not player.is_on_floor():
		player.velocity.y += GRAVITY * delta
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.velocity.y = JUMP_VELOCITY

	# move_and_slide обнуляет скорость при ударе о стену; нужна скорость до удара.
	var impact_speed: float = player.velocity.x
	player.move_and_slide()
	var pressed_into_breakable: bool = false
	for index: int in range(player.get_slide_collision_count()):
		var collision: KinematicCollision2D = player.get_slide_collision(index)
		var normal_x: float = collision.get_normal().x
		var collider: Node = collision.get_collider() as Node
		var push_speed: float = impact_speed
		if direction != 0.0 and normal_x * direction < 0.0:
			push_speed = intended_x
			if is_instance_valid(collider) and collider.is_in_group("breakable"):
				pressed_into_breakable = true
				_push_hold += delta
		if normal_x * push_speed < 0.0:
			check_obstacle_break(collider, push_speed)
	if not pressed_into_breakable:
		_push_hold = 0.0
	_update_animation(player)


func check_obstacle_break(body: Node, impact_speed: float) -> void:
	if not is_instance_valid(body):
		return
	var threshold: float = BREAK_SPEED if _push_hold < 0.12 else PUSH_BREAK_SPEED
	if absf(impact_speed) < threshold:
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
