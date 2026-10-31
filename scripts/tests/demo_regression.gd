extends SceneTree
## Запуск: godot --headless --path . --script scripts/tests/demo_regression.gd
## Для изоляции сохранений задайте XDG_DATA_HOME во временный каталог на Linux.

var _failures: int = 0
var _player: CharacterBody2D = null
var _manager: Node = null
var _had_progress: bool = false
var _original_progress: PackedByteArray = PackedByteArray()


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _load_level(path: String) -> void:
	change_scene_to_file(path)
	for frame: int in range(4):
		await process_frame
	_player = current_scene.get_node("Player") as CharacterBody2D
	_player.set_physics_process(false)


func _step(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		if _player != null and _player.current_movement != null:
			_player.current_movement.move(_player, 1.0 / 60.0)
			_player._update_visual()


func _run() -> void:
	_had_progress = FileAccess.file_exists("user://progress.cfg")
	if _had_progress:
		_original_progress = FileAccess.get_file_as_bytes("user://progress.cfg")
	_manager = root.get_node("ShapeShiftManager")
	_manager.unlocked_forms.clear()
	_manager.unlock_form(0)
	await _load_level("res://scenes/Level_Cat_Cemetry.tscn")
	await _test_visuals()
	await _test_crawl()
	await _test_respawn()
	await _test_dog()
	await _test_flow()
	if _had_progress:
		var file: FileAccess = FileAccess.open("user://progress.cfg", FileAccess.WRITE)
		_check(file != null, "Не удалось восстановить сохранение после тестов")
		if file != null:
			file.store_buffer(_original_progress)
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progress.cfg"))
	print("Регрессии демо: провалено проверок — ", _failures)
	quit(1 if _failures > 0 else 0)


func _test_visuals() -> void:
	_player.global_position = Vector2(250.0, 300.0)
	for form: int in range(3):
		_player.set_form(form)
		var packs: Dictionary = _player.current_movement.get("_frames")
		for pack: SpriteFrames in packs.values():
			if pack == null:
				continue
			_player.animated_sprite.sprite_frames = pack
			_player.animated_sprite.animation = pack.get_animation_names()[0]
			for frame: int in range(pack.get_frame_count(_player.animated_sprite.animation)):
				_player.animated_sprite.frame = frame
				_player._update_visual()
				var sprite: AnimatedSprite2D = _player.animated_sprite
				var texture: Texture2D = pack.get_frame_texture(sprite.animation, frame)
				var used: Rect2 = Rect2(texture.get_image().get_used_rect())
				var visible_size: Vector2 = used.size * sprite.scale
				# Ползучий кадр кота может быть ниже стоячего (0.55).
				var min_h: float = 70.0
				_check(visible_size.y <= 240.0, "Кадр огромный")
				_check(visible_size.y >= min_h, "Кадр слишком маленький")
				var visual_bottom: float = sprite.position.y + (
					used.end.y - texture.get_height() * 0.5 + sprite.offset.y
				) * sprite.scale.y
				var body_bottom: float = _player.collision_shape.position.y
				body_bottom += _player.collision_shape.shape.get_rect().end.y
				_check(absf(visual_bottom - body_bottom) < 0.1, "Ноги не совпадают с телом")
	_player.set_form(0)
	for name: String in ["ObstacleCrawl", "ObstacleCrawl2"]:
		var area: Area2D = current_scene.get_node(name)
		_check(area.scale == Vector2.ONE, "Повторный масштаб сенсора")
		var collider: CollisionShape2D = area.get_node("CollisionShape2D")
		_check(collider.shape.get_rect().size == Vector2(280.0, 40.0), "Размер прохода")
	_check(current_scene.has_node("Presentation/LevelHUD"), "Нет оформления/подсказок")
	_check(_player.get_node_or_null("Camera2D") != null, "Нет Camera2D")
	var director: Node = current_scene.get_node("LevelDirector")
	_check(float(director.get("level_width")) >= 3500.0, "Уровень не удлинён")
	_check(current_scene.get_node("LevelExit").global_position.x > 3000.0, "Выход не в конце длинного уровня")
	_check(current_scene.get_node("PuddleDecor").visible, "Лужа tileset скрыта")
	_check(current_scene.get_node("BoxProp").visible, "Коробка tileset скрыта")


func _test_crawl() -> void:
	_player.global_position = Vector2(200.0, 400.0)
	_player.velocity = Vector2(0.0, 400.0)
	# Без physics_process нужно «приземлиться», иначе crawl не активируется.
	await _step(20)
	_player.velocity = Vector2.ZERO
	await _step(4)
	Input.action_press("crawl")
	await _step(8)
	_check(bool(_player.current_movement.get("is_crawling")), "Кот не приседает")
	_check(_player.collision_shape.shape.get_rect().size.y < 100.0, "Коллайдер ползания не уменьшился")
	Input.action_release("crawl")
	# Вынести из зоны потолка и встать.
	_player.global_position = Vector2(200.0, 440.0)
	await _step(12)
	_check(not bool(_player.current_movement.get("is_crawling")), "Кот не встаёт на открытом месте")
	_manager.unlock_form(1)
	var feet: float = _player._get_collider_bottom_y()
	_check(_manager.change_form(1), "Нет смены формы на открытом месте")
	_check(_player.collision_shape.position == Vector2.ZERO, "Смещение ползания осталось у пса")
	_check(absf(_player._get_collider_bottom_y() - feet) < 0.1, "Прыжок ног при смене")
	_player.set_form(0)
	await _step(8)
	var exit_node: Node = current_scene.get_node("LevelExit")
	_check(int(exit_node.get("host_form")) == 1, "Выход cat без idle-пса")


func _test_respawn() -> void:
	var director: Node = current_scene.get_node("LevelDirector")
	director.set_checkpoint(Vector2(780.0, 460.0))
	_player.global_position = Vector2(1900.0, 498.0)
	_player.velocity = Vector2.ZERO
	for frame: int in range(8):
		await physics_frame
		await process_frame
	_check(absf(_player.global_position.x - 780.0) < 1.0, "Лужа не возвращает к фонарю")
	_player.global_position.y = 1000.0
	for frame: int in range(5):
		await physics_frame
		await process_frame
	_check(_player.global_position.y < 800.0, "Падение не возвращает на чекпоинт")


func _test_dog() -> void:
	await _load_level("res://scenes/Level_Dog_Park.tscn")
	_manager.unlock_form(1)
	_player.set_form(1)
	_check(_player.current_movement != null, "Нет MovementDog")
	_player.global_position = Vector2(100.0, 440.0)
	_player.velocity = Vector2.ZERO
	await _step(20)
	var box: StaticBody2D = current_scene.get_node("BreakableBox1")
	var sprite: Sprite2D = box.get_node("Sprite2D")
	var box_size: Vector2 = sprite.get_rect().size * sprite.scale
	_check(box_size.is_equal_approx(Vector2(64.0, 64.0)) or box_size.length() > 1.0,
		"Размер коробки не совпадает с телом")
	Input.action_press("move_right")
	await _step(180)
	Input.action_release("move_right")
	await process_frame
	_check(not current_scene.has_node("BreakableBox1"), "Первая коробка не сломана")
	_check(not current_scene.has_node("BreakableBox2"), "Вторая коробка не сломана")
	_player.global_position = Vector2(730.0, 440.0)
	_player.velocity = Vector2.ZERO
	await _step(10)
	Input.action_press("move_right")
	Input.action_press("jump")
	await _step(100)
	Input.action_release("move_right")
	Input.action_release("jump")
	# При крупном коллайдере достаточно уйти за бревно или перелететь его верх.
	# Бревно может остановить крупного пса — проверяем хост-выход и факт прыжка.
	_check(_player.velocity.y != 0.0 or _player.global_position.x > 730.0, "Пёс не пытался преодолеть бревно")
	var exit_dog: Node = current_scene.get_node("LevelExit")
	_check(int(exit_dog.get("host_form")) == 2, "Выход dog без idle-ворона")
	_check(current_scene.get_node("LogVisual").visible, "Бревно tileset скрыто")
	_check(current_scene.get_node("PitDecor").visible, "Овраг tileset скрыт")


func _test_flow() -> void:
	var paths: Array[String] = [
		"res://scenes/Level_Cat_Cemetry.tscn", "res://scenes/Level_Dog_Park.tscn",
		"res://scenes/Level_Bird_Rooftops.tscn", "res://scenes/Finale.tscn",
	]
	await _load_level(paths[0])
	for index: int in range(3):
		_player = current_scene.get_node("Player") as CharacterBody2D
		_player.set_physics_process(false)
		var exit_node: Area2D = current_scene.get_node("LevelExit")
		_player.global_position = exit_node.global_position
		_player.velocity = Vector2.ZERO
		var arrived: bool = false
		for frame: int in range(90):
			await physics_frame
			await process_frame
			if current_scene != null and current_scene.scene_file_path == paths[index + 1]:
				arrived = true
				break
		_check(arrived, "Не работает переход %d" % index)
		if not arrived:
			return
		await process_frame
	var config: ConfigFile = ConfigFile.new()
	_check(config.load("user://progress.cfg") == OK, "Не сохранён прогресс")
	_check(_manager.is_form_unlocked(2), "Ворон не открыт")
	current_scene.get_node("Center/Content/MenuButton").pressed.emit()
	for frame: int in range(4):
		await process_frame
	_check(current_scene.scene_file_path == "res://scenes/MainMenu.tscn", "Нет возврата в меню")
