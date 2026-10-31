extends Node2D

const CAT_LEVEL_PATH: String = "res://scenes/Level_Cat_Cemetry.tscn"
const SCREEN_HEIGHT: float = 800.0
const GHOST_SPEED: float = 140.0

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


func _ready() -> void:
	_build_world()
	_hint = Label.new()
	_hint.text = "Призрак хочет снова почувствовать себя живым.\nПодойди к кошке (A/D или ←/→)."
	_hint.position = Vector2(40.0, 40.0)
	_hint.add_theme_font_size_override("font_size", 28)
	_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	_hint.add_theme_constant_override("shadow_offset_x", 2)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_hint)


func _build_world() -> void:
	var bg := ColorRect.new()
	bg.color = Color("121826")
	bg.size = Vector2(1800.0, 800.0)
	bg.z_index = -20
	add_child(bg)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(900.0, 560.0)
	var floor_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(1900.0, 80.0)
	floor_shape.shape = rect
	floor_body.add_child(floor_shape)
	add_child(floor_body)
	var floor_draw := ColorRect.new()
	floor_draw.color = Color("36354b")
	floor_draw.position = Vector2(0.0, 520.0)
	floor_draw.size = Vector2(1800.0, 280.0)
	floor_draw.z_index = -10
	add_child(floor_draw)

	_cat = _CAT_IDLE.instantiate() as AnimatedSprite2D
	_cat.position = Vector2(980.0, 470.0)
	_fit_sprite_height(_cat, SCREEN_HEIGHT / 5.0)
	_cat.play(&"default")
	add_child(_cat)

	_ghost = Sprite2D.new()
	_ghost.texture = _GHOST_TEXTURES[0]
	_ghost.position = Vector2(220.0, 360.0)
	_fit_texture_height(_ghost, SCREEN_HEIGHT / 4.0)
	_ghost.modulate = Color(0.85, 0.95, 1.0, 0.92)
	add_child(_ghost)

	var area := Area2D.new()
	area.name = "CatSense"
	area.monitoring = true
	area.monitorable = false
	area.collision_layer = 0
	var sense_shape := CollisionShape2D.new()
	var sense_rect := RectangleShape2D.new()
	sense_rect.size = Vector2(140.0, 160.0)
	sense_shape.shape = sense_rect
	area.position = _cat.position
	area.add_child(sense_shape)
	add_child(area)
	# Призрак не CharacterBody — проверяем дистанцию в _process.


func _fit_sprite_height(sprite: AnimatedSprite2D, target_h: float) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(&"default"):
		return
	var texture: Texture2D = sprite.sprite_frames.get_frame_texture(&"default", 0)
	if texture == null:
		return
	var used: Rect2 = Rect2(texture.get_image().get_used_rect())
	if not used.has_area():
		return
	var ratio: float = target_h / used.size.y
	sprite.scale = Vector2(ratio, ratio)


func _fit_texture_height(sprite: Sprite2D, target_h: float) -> void:
	if sprite.texture == null:
		return
	var used: Rect2 = Rect2(sprite.texture.get_image().get_used_rect())
	if not used.has_area():
		used = Rect2(Vector2.ZERO, sprite.texture.get_size())
	var ratio: float = target_h / maxf(used.size.y, 1.0)
	sprite.scale = Vector2(ratio, ratio)


func _process(delta: float) -> void:
	if _possessing or _ghost == null:
		return
	var axis: float = Input.get_axis("move_left", "move_right")
	_ghost.position.x = clampf(_ghost.position.x + axis * GHOST_SPEED * delta, 80.0, 1700.0)
	if absf(axis) > 0.1:
		_ghost.flip_h = axis < 0.0
	if _ghost.position.distance_to(_cat.position) < 110.0:
		_possess()


func _possess() -> void:
	if _possessing:
		return
	_possessing = true
	_hint.text = "Вселение… Тепло жизни возвращается."
	_ghost.modulate.a = 0.35
	ShapeShiftManager.unlock_form(PlayerController.Form.CAT)
	ShapeShiftManager.current_form = PlayerController.Form.CAT
	ShapeShiftManager.set_checkpoint(Vector2.ZERO)
	await get_tree().create_timer(0.7).timeout
	get_tree().change_scene_to_file(CAT_LEVEL_PATH)
