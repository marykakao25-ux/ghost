extends SceneTree
## Запуск: godot --headless --path . --script scripts/tests/interaction_regression.gd

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
	for frame: int in range(2):
		await physics_frame
	_player = current_scene.get_node("Player") as CharacterBody2D
	# T-0034: компонент движения обязан существовать сразу после загрузки.
	# Раньше здесь был ручной патч (set_form при current_movement == null),
	# который маскировал «не работает движение после переключения».
	_check(_player.current_movement != null, "Игрок загружен без компонента движения: %s" % path)
	_check(
		int(_manager.current_form) == int(_player.current_form),
		"Рассинхрон формы менеджер/игрок после загрузки: %s" % path
	)
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
	await _test_real_input_movement()
	await _test_always_switched_forms()
	await _test_desync_selfheal()
	await _test_crawl_idle()
	await _test_pause_menu()
	await _test_atmosphere()
	await _test_ghost_visible()
	await _test_dog_push_break()
	await _test_menu_music_release()
	await _test_intro_possession()
	await _test_exit_host_transition()
	if _had_progress:
		var file: FileAccess = FileAccess.open("user://progress.cfg", FileAccess.WRITE)
		_check(file != null, "Не удалось восстановить сохранение")
		if file != null:
			file.store_buffer(_original_progress)
			file.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://progress.cfg"))
	print("Регрессии взаимодействия: провалено проверок — ", _failures)
	quit(1 if _failures > 0 else 0)


func _test_intro_possession() -> void:
	change_scene_to_file("res://scenes/Intro.tscn")
	for frame: int in range(4):
		await process_frame
	var intro: Node = current_scene
	_check(intro.has_method("_possess"), "Intro без вселения")
	var speed_ok: bool = false
	var script_res: Script = intro.get_script() as Script
	if script_res != null:
		var constants: Variant = script_res.get_script_constant_map()
		if constants is Dictionary:
			speed_ok = float((constants as Dictionary).get("GHOST_SPEED", 0.0)) >= 300.0
	_check(speed_ok, "Призрак слишком медленный")
	intro.set("_possessing", false)
	var ghost: Sprite2D = intro.get("_ghost") as Sprite2D
	var cat: AnimatedSprite2D = intro.get("_cat") as AnimatedSprite2D
	_check(ghost != null and cat != null, "Нет призрака/кота в интро")
	if ghost != null and cat != null:
		ghost.position = cat.position
		intro.call("_possess")
		for frame: int in range(90):
			await process_frame
			if current_scene != null and current_scene.scene_file_path == "res://scenes/Level_Cat_Cemetry.tscn":
				break
		_check(
			current_scene != null and current_scene.scene_file_path == "res://scenes/Level_Cat_Cemetry.tscn",
			"Интро не перешло на уровень кота"
		)
	await _load_level("res://scenes/Level_Cat_Cemetry.tscn")


func _test_exit_host_transition() -> void:
	await _load_level("res://scenes/Level_Cat_Cemetry.tscn")
	var exit_node: Area2D = current_scene.get_node("LevelExit") as Area2D
	_check(exit_node.monitoring, "LevelExit не monitoring")
	_check(exit_node.collision_mask == 1, "LevelExit mask не ловит игрока")
	_player.set_physics_process(true)
	_player.global_position = exit_node.global_position + Vector2(-40.0, 0.0)
	_player.velocity = Vector2.ZERO
	for frame: int in range(8):
		await physics_frame
	_player.global_position = exit_node.global_position
	for frame: int in range(90):
		await physics_frame
		await process_frame
		if current_scene != null and current_scene.scene_file_path == "res://scenes/Level_Dog_Park.tscn":
			break
	_check(
		current_scene != null and current_scene.scene_file_path == "res://scenes/Level_Dog_Park.tscn",
		"Касание хоста не перевело на уровень пса"
	)
	if current_scene != null and current_scene.has_node("Player"):
		_player = current_scene.get_node("Player") as CharacterBody2D
		_player.set_physics_process(false)


func _test_crawl_idle() -> void:
	_player.global_position = Vector2(250.0, 400.0)
	_player.velocity = Vector2(0.0, 400.0)
	await _step(20)
	_player.velocity = Vector2.ZERO
	await _step(4)
	Input.action_press("crawl")
	await _step(8)
	_check(_player.current_movement != null, "Нет MovementCat")
	_check(
		_player.current_movement != null and bool(_player.current_movement.get("is_crawling")),
		"Кот не присел"
	)
	_check(not _player.animated_sprite.is_playing(), "Неподвижный ползущий кот анимируется")
	_check(_player.animated_sprite.frame == 0, "Не та поза ползания")
	Input.action_press("move_right")
	await _step(10)
	_check(_player.animated_sprite.is_playing(), "Ползание в движении без анимации")
	Input.action_release("move_right")
	Input.action_release("crawl")
	_player.global_position = Vector2(250.0, 498.0)
	_player.set_form(0)
	await _step(6)


func _test_real_input_movement() -> void:
	# Настоящий игровой цикл: физика не отключена, движение от зажатой клавиши.
	_player.global_position = Vector2(250.0, 400.0)
	_player.velocity = Vector2.ZERO
	_player.set_physics_process(true)
	var start_x: float = _player.global_position.x
	Input.action_press("move_right")
	for frame: int in range(30):
		await physics_frame
	Input.action_release("move_right")
	_check(
		_player.global_position.x - start_x > 30.0,
		"Ввод move_right не двигает игрока в реальном физическом цикле"
	)
	_player.set_physics_process(false)
	_player.velocity = Vector2.ZERO


func _test_always_switched_forms() -> void:
	# T-0034: смена формы никогда не «съедается» отказом коллизии —
	# компонент движения и синхрон с менеджером гарантированы на любой форме.
	_manager.unlock_form(1)
	_manager.unlock_form(2)
	var movement_paths: Array[String] = [
		"res://scripts/MovementCat.gd",
		"res://scripts/MovementDog.gd",
		"res://scripts/MovementBird.gd",
	]
	for form: int in range(3):
		_player.set_form(form)
		_check(_player.current_movement != null, "Форма %s осталась без компонента движения" % form)
		_check(
			_player.current_movement != null
				and str(_player.current_movement.get_script().resource_path) == movement_paths[form],
			"Компонент движения не соответствует форме %s" % form
		)
		_check(int(_manager.current_form) == form, "Менеджер не синхронизировал форму %s" % form)
	_player.set_form(0)
	await _step(2)


func _test_desync_selfheal() -> void:
	# load_progress мог «запомнить» форму раньше игрока: смена не должна становиться
	# ложным no-op, а игрок — оставаться без движения.
	_player.set_form(0)
	_manager.current_form = 1
	_check(_manager.change_form(1), "change_form съедает смену формы при рассинхроне")
	_check(int(_player.current_form) == 1, "Игрок не сменил форму после рассинхрона")
	_check(_player.current_movement != null, "После смены из рассинхрона игрок без компонента движения")
	_player.set_form(0)
	await _step(2)


func _test_pause_menu() -> void:
	_player._toggle_pause()
	await process_frame
	_check(paused, "Пауза не включилась")
	_check(_player.get_node_or_null("PauseOverlay") != null, "Нет оверлея паузы")
	var menu: Node = _player.get_node("PauseOverlay/MenuCenter/Menu")
	_check(menu.get_child_count() >= 6, "В паузе мало пунктов")
	# T-0035: панель центрирована относительно фактического viewport,
	# а не жёсткими координатами 1800x800.
	var menu_control: Control = menu as Control
	var viewport_center: Vector2 = _player.get_viewport_rect().size * 0.5
	var panel_center: Vector2 = menu_control.global_position + menu_control.size * 0.5
	_check(
		absf(panel_center.x - viewport_center.x) < 2.0 and absf(panel_center.y - viewport_center.y) < 2.0,
		"Меню паузы не отцентровано в viewport (уехало)"
	)
	_check(menu.get_child(1) is Button and (menu.get_child(1) as Control).has_focus(), "Первая кнопка паузы не фокусируется")
	_player._on_pause_resume()
	await process_frame
	_check(not paused, "Пауза не снялась")
	_check(not _player.get_node("PauseOverlay").visible, "Оверлей паузы виден после Продолжить")


func _test_atmosphere() -> void:
	var presentation: Node = current_scene.get_node("Presentation")
	_check(presentation.get_node_or_null("AtmosphereLayer/Atmosphere") != null, "Нет постэффекта")
	presentation.call("set_atmosphere_enabled", true)
	_player._toggle_pause()
	await process_frame
	var atmosphere: CanvasItem = presentation.get_node("AtmosphereLayer/Atmosphere")
	_check(not atmosphere.visible, "Постэффект не выключился на паузе")
	_player._on_pause_resume()
	await process_frame
	_check(atmosphere.visible, "Постэффект не вернулся после паузы")


func _test_ghost_visible() -> void:
	_player.global_position = Vector2(250.0, 400.0)
	_player.velocity = Vector2(0.0, 400.0)
	await _step(16)
	_player.velocity = Vector2.ZERO
	await _step(4)
	_manager.unlock_form(1)
	_check(_manager.change_form(1), "Не сменилась форма")
	await process_frame
	_check(int(_manager.current_form) == 1 and int(_player.current_form) == 1, "Рассинхрон формы после смены")
	var pivot: Node2D = _player.get_node("FormPivot")
	_check(pivot.get_node_or_null("PossessionGhost") != null, "Призрак не появился при смене")
	_check(_player.animated_sprite.visible, "Форма скрыта после вселения")
	var ghost: Sprite2D = pivot.get_node_or_null("PossessionGhost") as Sprite2D
	if ghost != null and ghost.texture != null:
		var img: Image = ghost.texture.get_image()
		var used_h: float = float(img.get_used_rect().size.y) if img != null else ghost.texture.get_size().y
		var gh: float = used_h * ghost.scale.y
		_check(gh >= 150.0 and gh <= 250.0, "Призрак не ~1/4 экрана")
	_player.set_form(0)
	await _step(4)


func _test_dog_push_break() -> void:
	await _load_level("res://scenes/Level_Dog_Park.tscn")
	_manager.unlock_form(1)
	_player.set_form(1)
	_player.global_position = Vector2(470.0, 400.0)
	_player.velocity = Vector2(0.0, 400.0)
	await _step(20)
	_player.velocity = Vector2.ZERO
	await _step(8)
	Input.action_press("move_right")
	await _step(90)
	Input.action_release("move_right")
	await process_frame
	_check(not current_scene.has_node("BreakableBox2"), "Ящик не сломан толканием с места")
	_check(_player.global_position.x > 500.0, "Пёс не вышел из промежутка")


func _test_menu_music_release() -> void:
	change_scene_to_file("res://scenes/MainMenu.tscn")
	for frame: int in range(4):
		await process_frame
	var menu: Node = current_scene
	_check(menu.has_method("_release_music"), "MainMenu без освобождения аудио")
	var music: AudioStreamPlayer = menu.get_node_or_null("AudioStreamPlayer") as AudioStreamPlayer
	_check(music != null, "Нет AudioStreamPlayer в меню")
	# В headless меню сразу сбрасывает stream, чтобы --quit не утекал PlaybackMP3.
	if DisplayServer.get_name() == "headless":
		_check(music.stream == null, "Headless меню не сбросило stream")
	else:
		_check(music.playing, "Музыка меню не стартовала")
		menu.call("_release_music")
		_check(music.stream == null, "Поток меню не сброшен")
		_check(not music.playing, "Музыка меню продолжает играть")
