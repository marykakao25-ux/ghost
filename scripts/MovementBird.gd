extends Node
class_name MovementBird

const FLY_SPEED: float = 200.0
const ACCELERATION: float = 1100.0
const FRICTION: float = 900.0
const WIND_RESISTANCE: float = 2.5
const MAX_VERTICAL_SPEED: float = 260.0
const MAX_HORIZONTAL_SPEED: float = 280.0
const WIND_DECAY: float = 480.0
const FLY_ANIM_THRESHOLD: float = 20.0

const _ANIM_IDLE := preload("res://assets/sprites/bird/anim_bird_idle.tscn")
const _ANIM_FLY := preload("res://assets/sprites/bird/anim_bird_fly.tscn")

var _sprite: AnimatedSprite2D = null
var _frames: Dictionary = {}
var _current_anim: String = ""
var _wind_force: Vector2 = Vector2.ZERO
var _wind_applied_this_frame: bool = false


func _ready() -> void:
	_resolve_player_refs()
	_cache_animation_frames()


func move(player: CharacterBody2D, delta: float) -> void:
	_resolve_player_refs_from(player)

	var axis := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if axis.length() > 1.0:
		axis = axis.normalized()

	var target_velocity: Vector2 = axis * FLY_SPEED
	if axis != Vector2.ZERO:
		player.velocity = player.velocity.move_toward(target_velocity, ACCELERATION * delta)
	else:
		player.velocity = player.velocity.move_toward(Vector2.ZERO, FRICTION * delta)

	if not _wind_applied_this_frame:
		_wind_force = _wind_force.move_toward(Vector2.ZERO, WIND_DECAY * delta)

	var wind_velocity: Vector2 = _wind_force / maxf(WIND_RESISTANCE, 0.01)
	player.velocity += wind_velocity

	player.velocity.x = clampf(player.velocity.x, -MAX_HORIZONTAL_SPEED, MAX_HORIZONTAL_SPEED)
	player.velocity.y = clampf(player.velocity.y, -MAX_VERTICAL_SPEED, MAX_VERTICAL_SPEED)

	if absf(player.velocity.x) > 1.0 and _sprite != null:
		_sprite.flip_h = player.velocity.x < 0.0

	player.move_and_slide()
	_update_animation(player)
	_wind_applied_this_frame = false


func apply_wind_force(force: Vector2) -> void:
	_wind_force = force
	_wind_applied_this_frame = true


func play_anim(anim_name: String) -> void:
	if _sprite == null:
		return

	var key: String = _normalize_anim_name(anim_name)
	if key == _current_anim:
		return
	if not _frames.has(key):
		return

	var frames: SpriteFrames = _frames[key] as SpriteFrames
	if frames == null:
		return

	_sprite.sprite_frames = frames
	_current_anim = key
	if frames.has_animation("default"):
		_sprite.play("default")


func _resolve_player_refs() -> void:
	var parent_node: Node = get_parent()
	if parent_node is CharacterBody2D:
		_resolve_player_refs_from(parent_node as CharacterBody2D)


func _resolve_player_refs_from(player: CharacterBody2D) -> void:
	if player == null:
		return
	if "animated_sprite" in player:
		_sprite = player.animated_sprite as AnimatedSprite2D


func _cache_animation_frames() -> void:
	_frames["idle"] = _extract_frames(_ANIM_IDLE)
	_frames["fly"] = _extract_frames(_ANIM_FLY)


func _extract_frames(packed: PackedScene) -> SpriteFrames:
	var node: Node = packed.instantiate()
	var frames: SpriteFrames = null
	if node is AnimatedSprite2D:
		frames = (node as AnimatedSprite2D).sprite_frames
	node.free()
	return frames


func _normalize_anim_name(anim_name: String) -> String:
	match anim_name:
		"bird_idle", "idle":
			return "idle"
		"bird_fly", "fly":
			return "fly"
		_:
			return anim_name


func _update_animation(player: CharacterBody2D) -> void:
	if absf(player.velocity.y) > FLY_ANIM_THRESHOLD:
		play_anim("bird_fly")
	else:
		play_anim("bird_idle")
