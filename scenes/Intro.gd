extends Node2D

const CAT_LEVEL_PATH: String = "res://scenes/Level_Cat_Cemetry.tscn"
const SCREEN_HEIGHT: float = 800.0
const GHOST_SPEED: float = 420.0
const POSSESS_GAP: float = 40.0

const _GHOST_TEXTURES: Array[Texture2D] = [
	preload("res://assets/sprites/gg/ghost1.png"),
	preload("res://assets/sprites/gg/ghost2.png"),
	preload("res://assets/sprites/gg/ghost3.png"),
]
const _CAT_IDLE: PackedScene = preload("res://assets/sprites/cat/anim_cat_idle.tscn")

var _ghost: Sprite2D = null
var _cat: AnimatedSprite2D = null
var _possessing: bool = false
var _hint: Label = null
var _ghost_half_w: float = 100.0
var _cat_half_w: float = 80.0
var _fade: ColorRect


func _ready() -> void:
	_build_world()
	_create_fade()
	_hint = Label.new()
	_hint.text = "Подойди к кошке (A/D или ←/→)."
	_hint.position = Vector2(40.0, 40.0)
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_hint)
	await _fade_to(0.0, 0.8)


func _build_world() -> void:
	var bg := ColorRect.new()
	bg.color = Color("121826")
	bg.size = Vector2(1800.0, 800.0)
	bg.z_index = -20
	add_child(bg)
	var floor_draw := ColorRect.new()
	floor_draw.color = Color("36354b")
	floor_draw.position = Vector2(0.0, 520.0)
	floor_draw.size = Vector2(1800.0, 280.0)
	floor_draw.z_index = -10
	add_child(floor_draw)

	_cat = _CAT_IDLE.instantiate() as AnimatedSprite2D
	_cat.position = Vector2(1100.0, 440.0)
	_fit_sprite_height(_cat, SCREEN_HEIGHT / 5.0)
	_cat_half_w = _estimate_half_width(_cat)
	_cat.play(&"default")
	add_child(_cat)

	_ghost = Sprite2D.new()
	_ghost.texture = _GHOST_TEXTURES[0]
	# Одна высота с котом — иначе distance_to никогда не срабатывает.
	_ghost.position = Vector2(180.0, _cat.position.y)
	_fit_texture_height(_ghost, SCREEN_HEIGHT / 4.0)
	_ghost_half_w = _ghost.texture.get_size().x * absf(_ghost.scale.x) * 0.35
	_ghost.modulate = Color(0.85, 0.95, 1.0, 0.92)
	add_child(_ghost)


func _fit_sprite_height(sprite: AnimatedSprite2D, target_h: float) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"default"):
		return
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"default", 0)
	if texture == null:
		return
	var used: Rect2 = Rect2(texture.get_image().get_used_rect())
	if not used.has_area():
		used = Rect2(Vector2.ZERO, texture.get_size())
	var ratio: float = target_h / maxf(used.size.y, 1.0)
	sprite.scale = Vector2(ratio, ratio)


func _fit_texture_height(sprite: Sprite2D, target_h: float) -> void:
	if sprite.texture == null:
		return
	var used: Rect2 = Rect2(sprite.texture.get_image().get_used_rect())
	if not used.has_area():
		used = Rect2(Vector2.ZERO, sprite.texture.get_size())
	var ratio: float = target_h / maxf(used.size.y, 1.0)
	sprite.scale = Vector2(ratio, ratio)


func _estimate_half_width(sprite: AnimatedSprite2D) -> float:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"default"):
		return 80.0
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"default", 0)
	if texture == null:
		return 80.0
	var used: Rect2 = Rect2(texture.get_image().get_used_rect())
	if not used.has_area():
		used = Rect2(Vector2.ZERO, texture.get_size())
	return used.size.x * absf(sprite.scale.x) * 0.45


func _process(delta: float) -> void:
	if _possessing or _ghost == null or _cat == null:
		return
	var axis: float = Input.get_axis("move_left", "move_right")
	_ghost.position.x = clampf(
		_ghost.position.x + axis * GHOST_SPEED * delta, 80.0, 1700.0
	)
	_ghost.position.y = _cat.position.y
	if absf(axis) > 0.1:
		_ghost.flip_h = axis < 0.0
	# Вселение по горизонтальному сближению силуэтов (Y уже совпадает).
	var reach: float = _ghost_half_w + _cat_half_w + POSSESS_GAP
	if absf(_ghost.position.x - _cat.position.x) <= reach:
		_possess()


func _possess() -> void:
	if _possessing:
		return

	_possessing = true
	_hint.text = "Призрак вселяется в кота..."
	_spawn_possession_effect()

	ShapeShiftManager.unlock_form(PlayerController.Form.CAT)
	ShapeShiftManager.current_form = PlayerController.Form.CAT
	ShapeShiftManager.set_checkpoint(Vector2.ZERO)

	var ghost_tween: Tween = create_tween()
	ghost_tween.tween_property(_ghost, "modulate:a", 0.0, 0.8)

	await get_tree().create_timer(1.0).timeout
	await _fade_to(1.0, 0.8)
	get_tree().change_scene_to_file(CAT_LEVEL_PATH)


func _spawn_possession_effect() -> void:
	for particle_index in range(18):
		var radius: float = randf_range(3.0, 7.0)
		var points := PackedVector2Array()

		for point_index in range(10):
			var angle: float = TAU * float(point_index) / 10.0
			points.append(Vector2(cos(angle), sin(angle)) * radius)

		var particle := Polygon2D.new()
		particle.polygon = points
		particle.color = Color.WHITE
		add_child(particle)

		particle.global_position = _cat.global_position + Vector2(
			randf_range(-35.0, 35.0),
			randf_range(-30.0, 30.0)
		)

		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(
			particle,
			"position",
			particle.position + Vector2(
				randf_range(-25.0, 25.0),
				randf_range(-70.0, -25.0)
			),
			0.8
		)
		tween.tween_property(particle, "modulate:a", 0.0, 0.8)
		tween.tween_property(particle, "scale", Vector2.ZERO, 0.8)
		tween.finished.connect(particle.queue_free)


func _create_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func _fade_to(alpha: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", alpha, duration)
	await tween.finished
