extends Node
class_name MovementCat

signal night_vision_toggled(enabled: bool)

const SPEED: float = 220.0
const JUMP_VELOCITY: float = -420.0
const CRAWL_SPEED: float = 90.0
const ACCELERATION: float = 1200.0
const FRICTION: float = 1400.0
const GRAVITY: float = 980.0

const STAND_RADIUS: float = 16.0
const STAND_HEIGHT: float = 44.0
const CRAWL_RADIUS: float = 11.0
const CRAWL_HEIGHT: float = 22.0

const _ANIM_IDLE := preload("res://assets/sprites/cat/anim_cat_idle.tscn")
const _ANIM_WALK := preload("res://assets/sprites/cat/anim_cat_walk.tscn")
const _ANIM_JUMP := preload("res://assets/sprites/cat/anim_cat_jump.tscn")
const _ANIM_CRAWL := preload("res://assets/sprites/cat/anim_cat_crawling.tscn")

var is_crawling: bool = false
var night_vision_enabled: bool = false

var _sprite: AnimatedSprite2D = null
var _collision: CollisionShape2D = null
var _frames: Dictionary = {}
var _current_anim: String = ""
var _standing_shape_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_resolve_player_refs()
	_cache_animation_frames()
	if _collision != null:
		_standing_shape_pos = _collision.position
	_set_night_vision(true)


func _exit_tree() -> void:
	_set_night_vision(false)


func move(player: CharacterBody2D, delta: float) -> void:
	_resolve_player_refs_from(player)

	if not player.is_on_floor():
		player.velocity.y += GRAVITY * delta

	if Input.is_action_pressed("crawl") and player.is_on_floor():
		crawl()
	elif is_crawling:
		_try_stand(player)

	var axis: float = Input.get_axis("move_left", "move_right")
	var max_speed: float = CRAWL_SPEED if is_crawling else SPEED

	if axis != 0.0:
		player.velocity.x = move_toward(player.velocity.x, axis * max_speed, ACCELERATION * delta)
		if _sprite != null:
			_sprite.flip_h = axis < 0.0
	else:
		player.velocity.x = move_toward(player.velocity.x, 0.0, FRICTION * delta)

	if not is_crawling and player.is_on_floor() and Input.is_action_just_pressed("jump"):
		player.velocity.y = JUMP_VELOCITY

	player.move_and_slide()
	_update_animation(player)


func crawl() -> void:
	if _collision == null:
		return
	if not is_crawling:
		_standing_shape_pos = _collision.position
		_apply_crawl_collision()
		is_crawling = true


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
	if parent_node == null:
		return
	if parent_node is CharacterBody2D:
		_resolve_player_refs_from(parent_node as CharacterBody2D)


func _resolve_player_refs_from(player: CharacterBody2D) -> void:
	if player == null:
		return
	if "animated_sprite" in player:
		_sprite = player.animated_sprite as AnimatedSprite2D
	if "collision_shape" in player:
		_collision = player.collision_shape as CollisionShape2D


func _cache_animation_frames() -> void:
	_frames["idle"] = _extract_frames(_ANIM_IDLE)
	_frames["walk"] = _extract_frames(_ANIM_WALK)
	_frames["jump"] = _extract_frames(_ANIM_JUMP)
	_frames["crawl"] = _extract_frames(_ANIM_CRAWL)


func _extract_frames(packed: PackedScene) -> SpriteFrames:
	var node: Node = packed.instantiate()
	var frames: SpriteFrames = null
	if node is AnimatedSprite2D:
		frames = (node as AnimatedSprite2D).sprite_frames
	node.free()
	return frames


func _normalize_anim_name(anim_name: String) -> String:
	match anim_name:
		"cat_idle", "idle":
			return "idle"
		"cat_walk", "walk", "run":
			return "walk"
		"cat_jump", "jump":
			return "jump"
		"cat_crawling", "crawling", "crawl":
			return "crawl"
		_:
			return anim_name


func _update_animation(player: CharacterBody2D) -> void:
	if is_crawling:
		play_anim("crawl")
		return
	if not player.is_on_floor():
		play_anim("jump")
		return
	if absf(player.velocity.x) > 10.0:
		play_anim("walk")
	else:
		play_anim("idle")


func _apply_crawl_collision() -> void:
	if _collision == null:
		return
	var capsule := CapsuleShape2D.new()
	capsule.radius = CRAWL_RADIUS
	capsule.height = CRAWL_HEIGHT
	_collision.shape = capsule
	# Низ коллайдера остаётся на месте: центр смещается вниз на половину разницы высот.
	var drop: float = (STAND_HEIGHT - CRAWL_HEIGHT) * 0.5
	_collision.position = Vector2(_standing_shape_pos.x, _standing_shape_pos.y + drop)


func _apply_standing_collision() -> void:
	if _collision == null:
		return
	var capsule := CapsuleShape2D.new()
	capsule.radius = STAND_RADIUS
	capsule.height = STAND_HEIGHT
	_collision.shape = capsule
	_collision.position = _standing_shape_pos


func _try_stand(player: CharacterBody2D) -> void:
	if not is_crawling:
		return
	var shape: CapsuleShape2D = CapsuleShape2D.new()
	shape.radius = STAND_RADIUS
	shape.height = STAND_HEIGHT
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = _collision.global_transform
	query.transform.origin = player.to_global(_standing_shape_pos)
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	if not player.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return
	_apply_standing_collision()
	is_crawling = false


func _set_night_vision(enabled: bool) -> void:
	if night_vision_enabled == enabled:
		return
	night_vision_enabled = enabled
	night_vision_toggled.emit(enabled)
