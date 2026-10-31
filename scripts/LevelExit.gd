extends Area2D
class_name LevelExit

## Выход-вселение: idle-сосуд следующей формы вместо зелёной двери.

@export_file("*.tscn") var next_scene: String = ""
@export var unlock_form: int = -1
@export var host_form: int = PlayerController.Form.DOG
@export var exit_text: String = "Вселиться →"

const SCREEN_HEIGHT: float = 800.0
const _HOST_ANIMS: Dictionary = {
	PlayerController.Form.CAT: preload("res://assets/sprites/cat/anim_cat_idle.tscn"),
	PlayerController.Form.DOG: preload("res://assets/sprites/dog/anim_dog_idle.tscn"),
	PlayerController.Form.BIRD: preload("res://assets/sprites/bird/anim_bird_idle.tscn"),
}

var _transition_pending: bool = false
var _sprite: AnimatedSprite2D = null


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_build_host_visual()
	_ensure_large_hitbox()
	var label: Label = get_node_or_null("Label") as Label
	if label != null:
		label.text = exit_text
		label.position = Vector2(-120.0, -220.0)


func _physics_process(_delta: float) -> void:
	if _transition_pending or not monitoring:
		return
	# Запасной путь: body_entered на крупном CharacterBody иногда пропускается.
	for body: Node2D in get_overlapping_bodies():
		if body is PlayerController:
			_on_body_entered(body)
			return


func _ensure_large_hitbox() -> void:
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var rect := RectangleShape2D.new()
	var target_h: float = SCREEN_HEIGHT / 5.0
	if host_form == PlayerController.Form.BIRD:
		target_h = SCREEN_HEIGHT / 6.0
	rect.size = Vector2(maxf(target_h * 1.2, 160.0), maxf(target_h * 1.35, 180.0))
	shape_node.shape = rect
	shape_node.position = Vector2(0.0, -target_h * 0.15)
	shape_node.disabled = false


func _build_host_visual() -> void:
	var glow: CanvasItem = get_node_or_null("Glow") as CanvasItem
	if glow != null:
		glow.visible = false
	_sprite = get_node_or_null("HostSprite") as AnimatedSprite2D
	if _sprite == null:
		_sprite = AnimatedSprite2D.new()
		_sprite.name = "HostSprite"
		add_child(_sprite)
	var packed: PackedScene = _HOST_ANIMS.get(host_form) as PackedScene
	if packed == null:
		return
	var sample: AnimatedSprite2D = packed.instantiate() as AnimatedSprite2D
	_sprite.sprite_frames = sample.sprite_frames
	sample.free()
	if _sprite.sprite_frames != null and _sprite.sprite_frames.has_animation(&"default"):
		_sprite.play(&"default")
	_fit_host_scale()


func _fit_host_scale() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(&"default"):
		return
	var texture: Texture2D = _sprite.sprite_frames.get_frame_texture(&"default", 0)
	if texture == null:
		return
	var used: Rect2 = Rect2(texture.get_image().get_used_rect())
	if not used.has_area():
		used = Rect2(Vector2.ZERO, texture.get_size())
	var target_h: float = SCREEN_HEIGHT / 5.0
	if host_form == PlayerController.Form.BIRD:
		target_h = SCREEN_HEIGHT / 6.0
	var ratio: float = target_h / maxf(used.size.y, 1.0)
	_sprite.scale = Vector2(ratio, ratio)
	_sprite.position = Vector2(0.0, -target_h * 0.35)


func _on_body_entered(body: Node2D) -> void:
	if _transition_pending or not body is PlayerController:
		return
	_transition_pending = true
	# Нельзя менять сцену прямо из физического callback.
	call_deferred("_begin_possession", body as PlayerController)


func _begin_possession(player: PlayerController) -> void:
	if next_scene.is_empty() or not ResourceLoader.exists(next_scene, "PackedScene"):
		push_warning("Выход: сцена назначения пока недоступна: %s" % next_scene)
		_transition_pending = false
		return
	if unlock_form < -1 or unlock_form >= PlayerController.Form.size():
		push_warning("Выход: некорректная форма для разблокировки: %s" % unlock_form)
		_transition_pending = false
		return
	if is_instance_valid(player) and ShapeShiftManager.has_method("play_possession_fx"):
		ShapeShiftManager.play_possession_fx(player)
	var previous_forms: Array[int] = ShapeShiftManager.unlocked_forms.duplicate()
	var previous_checkpoint: Vector2 = ShapeShiftManager.last_checkpoint
	var previous_form: int = ShapeShiftManager.current_form
	if unlock_form >= 0:
		ShapeShiftManager.unlock_form(unlock_form)
	# current_form не выставляется заранее: состояние менеджера должно отражать
	# фактическую форму игрока — синхронизацию делает form_changed, а целевой
	# уровень сам сменит форму директором (T-0037).
	ShapeShiftManager.set_checkpoint(Vector2.ZERO)
	await get_tree().create_timer(0.25).timeout
	if not ShapeShiftManager.trigger_level_transition(next_scene):
		ShapeShiftManager.unlocked_forms = previous_forms
		ShapeShiftManager.set_checkpoint(previous_checkpoint)
		ShapeShiftManager.current_form = previous_form
		ShapeShiftManager.save_progress()
		_transition_pending = false
