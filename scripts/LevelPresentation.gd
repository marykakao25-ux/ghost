extends Node2D

const OBSTACLE_SCRIPT: GDScript = preload("res://scripts/Obstacle.gd")

const BACKGROUNDS: Array[Texture2D] = [
	preload("res://assets/environment/halloween_props/cat_location.png"),
	preload("res://assets/environment/halloween_props/dog_location.png"),
	preload("res://assets/environment/halloween_props/bird_location.png"),
]
const TITLES: Array[String] = ["01 / Забытое кладбище", "02 / Осенний парк", "03 / Над крышами"]
const OBJECTIVES: Array[String] = [
	"Пригнись под каменными сводами. Перепрыгни светящиеся лужи.",
	"Разгонись, разбей ящики и перепрыгни бревно и провал.",
	"Лети к зелёному выходу справа. Обходи красные ветви и используй ветер.",
]

@export_enum("Кладбище", "Парк", "Крыши") var location: int = 0

var _surfaces: Array[Rect2] = []
var _hazards: Array[Rect2] = []
var _checkpoints: Array[Vector2] = []
var _wind_regions: Array[Rect2] = []
var _player: PlayerController = null
var _progress: ProgressBar = null
var _form_label: Label = null
var _message: Label = null
var _message_seconds: float = 0.0


func _ready() -> void:
	z_index = -10
	var level: Node = get_parent()
	_player = level.get_node("Player") as PlayerController
	for node: Node in level.get_children():
		if node is Sprite2D:
			(node as Sprite2D).hide()
		if node is CollisionObject2D and not node.is_in_group("breakable"):
			var collider: CollisionShape2D = node.get_node_or_null("CollisionShape2D")
			if collider == null or collider.shape == null:
				continue
			var rect: Rect2 = collider.global_transform * collider.shape.get_rect()
			if node is StaticBody2D:
				_surfaces.append(rect)
			elif node.name.begins_with("Checkpoint"):
				_checkpoints.append((node as Node2D).position)
			elif node.name.begins_with("WindZone"):
				_wind_regions.append(rect)
			elif node.get_script() == OBSTACLE_SCRIPT and int(node.get("obstacle_type")) == 3:
				_hazards.append(rect)
	var overlay: ColorRect = level.get_node_or_null("GhostVision/VisionOverlay")
	if overlay != null:
		var vision_material: ShaderMaterial = overlay.material as ShaderMaterial
		vision_material.set_shader_parameter("darkness_color", Color(0.015, 0.025, 0.045, 0.48))
	var director: Node = level.get_node("LevelDirector")
	director.connect("player_respawned", _on_respawned)
	_create_hud()
	queue_redraw()


func _process(delta: float) -> void:
	if is_instance_valid(_player):
		_progress.value = _player.global_position.x
		var names: Array[String] = ["Кот", "Пёс", "Ворон"]
		_form_label.text = names[_player.current_form] + "  /  Q · 1 · 2 · 3 — открытые формы"
	_message_seconds = maxf(0.0, _message_seconds - delta)
	_message.visible = _message_seconds > 0.0


func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, 1800.0, 800.0), Color("171d30"))
	var source: Rect2 = Rect2(0.0, 0.0, 1500.0, 600.0)
	var sky: Rect2 = Rect2(0.0, 0.0, 1800.0, 520.0)
	if location == 2:
		source.size.y = 800.0
		sky.size.y = 800.0
	draw_texture_rect_region(BACKGROUNDS[location], sky, source, Color(0.8, 0.84, 0.9))
	for surface: Rect2 in _surfaces:
		var fill: Color = Color("36354b") if location != 1 else Color("463e38")
		var rect: Rect2 = surface
		if rect.position.y >= 520.0 and rect.size.x > 1000.0:
			rect.size.y = 800.0 - rect.position.y
		draw_rect(rect, fill)
		draw_rect(surface, Color("6d7485"), false, 2.0)
		draw_line(surface.position, Vector2(surface.end.x, surface.position.y), Color("b6c6af"), 3.0)
		for x: float in range(int(rect.position.x + 18.0), int(rect.end.x), 50):
			if rect.size.y > 35.0:
				draw_line(
					Vector2(x, rect.position.y + 20.0), Vector2(x + 20.0, rect.position.y + 20.0),
					Color(0.6, 0.62, 0.67, 0.2), 2.0
				)
	for hazard: Rect2 in _hazards:
		draw_rect(hazard, Color(0.8, 0.16, 0.3, 0.55))
		draw_rect(hazard, Color("ff8c99"), false, 2.0)
		for x: int in range(int(hazard.position.x), int(hazard.end.x), 12):
			draw_line(Vector2(x, hazard.end.y), Vector2(x + 8, hazard.position.y), Color("ffbec3"), 2.0)
	for point: Vector2 in _checkpoints:
		draw_line(point + Vector2(0.0, 60.0), point, Color("d6c693"), 3.0)
		draw_circle(point, 19.0, Color(1.0, 0.8, 0.35, 0.14))
		draw_circle(point, 7.0, Color("ffe7a2"))
		draw_line(point, point + Vector2(25.0, 8.0), Color("ffe7a2"), 4.0)
	for wind: Rect2 in _wind_regions:
		draw_rect(wind, Color(0.6, 0.85, 1.0, 0.08))
		for y: int in range(int(wind.position.y + 24.0), int(wind.end.y), 36):
			draw_line(
				Vector2(wind.position.x + 16.0, y), Vector2(wind.end.x - 16.0, y - 8.0),
				Color(0.7, 0.9, 1.0, 0.45), 2.0
			)


func _create_hud() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "LevelHUD"
	layer.layer = 20
	add_child(layer)
	var panel: ColorRect = ColorRect.new()
	panel.position = Vector2(20.0, 16.0)
	panel.size = Vector2(1760.0, 100.0)
	panel.color = Color(0.025, 0.04, 0.07, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	_add_label(panel, TITLES[location], Vector2(20.0, 10.0), 26)
	_add_label(panel, OBJECTIVES[location], Vector2(20.0, 50.0), 19)
	_form_label = _add_label(panel, "", Vector2(1210.0, 18.0), 18)
	_progress = ProgressBar.new()
	_progress.position = Vector2(1210.0, 55.0)
	_progress.size = Vector2(520.0, 12.0)
	_progress.max_value = 1800.0
	_progress.show_percentage = false
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_progress)
	var controls: String = "A / D · ← / → — ходьба     Пробел — прыжок     Ctrl / S — ползти"
	if location == 2:
		controls = "W A S D · стрелки — полёт     Светлые потоки — ветер"
	_add_label(layer, controls + "     Esc — пауза", Vector2(28.0, 720.0), 22)
	var legend: String = "Жёлтый фонарь — чекпоинт  ·  Красная штриховка — опасность"
	_add_label(layer, legend + "  ·  Зелёный свет — выход", Vector2(28.0, 760.0), 18)
	_message = _add_label(layer, "", Vector2(30.0, 125.0), 22)
	_message.modulate = Color("ffb6b9")
	_message.hide()


func _add_label(parent: Node, text: String, label_position: Vector2, font_size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.position = label_position
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label


func _on_respawned(reason: String) -> void:
	_message.text = reason
	_message_seconds = 3.0
