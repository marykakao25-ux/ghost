extends StaticBody2D
class_name BreakableBox

var _broken: bool = false

@onready var _collision: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("breakable")
	var sprite: Sprite2D = $Sprite2D
	var texture: Texture2D = sprite.texture
	var region: Rect2 = Rect2(texture.get_image().get_used_rect())
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	sprite.texture = atlas
	sprite.scale = _collision.shape.get_rect().size / region.size
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_collision) or _collision.shape == null:
		return
	var rect: Rect2 = _collision.shape.get_rect()
	draw_rect(rect, Color("745333"))
	draw_rect(rect, Color("e3bc78"), false, 2.0)
	draw_line(rect.position, rect.end, Color("b89560"), 3.0)


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
