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
	# PNG-фрагмент похож на дорогу; оставляем размер для коллизий/тестов, рисуем ящик сами.
	sprite.hide()
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_collision) or _collision.shape == null:
		return
	var rect: Rect2 = _collision.shape.get_rect()
	draw_rect(rect, Color("6b4a2b"))
	draw_rect(rect.grow(-6.0), Color("8b6238"))
	draw_rect(rect, Color("e3bc78"), false, 3.0)
	var mid_x: float = rect.position.x + rect.size.x * 0.5
	var mid_y: float = rect.position.y + rect.size.y * 0.5
	draw_line(Vector2(mid_x, rect.position.y), Vector2(mid_x, rect.end.y), Color("c9a36a"), 2.0)
	draw_line(Vector2(rect.position.x, mid_y), Vector2(rect.end.x, mid_y), Color("c9a36a"), 2.0)
	draw_rect(Rect2(rect.position + Vector2(10.0, 10.0), Vector2(12.0, 12.0)), Color("d8b57a"), false, 2.0)
	draw_rect(Rect2(rect.end - Vector2(22.0, 22.0), Vector2(12.0, 12.0)), Color("d8b57a"), false, 2.0)


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
