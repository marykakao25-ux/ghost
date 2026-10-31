extends Control

const MENU_SCENE: String = "res://scenes/MainMenu.tscn"

var _elapsed: float = 0.0
var _return_pending: bool = false

@onready var _ghost: AnimatedSprite2D = $Center/Content/GhostStage/Ghost
@onready var _stage: Control = $Center/Content/GhostStage
@onready var _menu_button: Button = $Center/Content/MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_menu_button.pressed.connect(_on_menu_pressed)
	_menu_button.grab_focus()
	_ghost.play(&"default")
	modulate.a = 0.0
	var fade: Tween = create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.8)


func _process(delta: float) -> void:
	_elapsed += delta
	_ghost.position = _stage.size * 0.5 + Vector2(0.0, sin(_elapsed * 1.5) * 8.0)


func _on_menu_pressed() -> void:
	if _return_pending:
		return
	_return_pending = true
	_menu_button.disabled = true
	_return_to_menu.call_deferred()


func _return_to_menu() -> void:
	get_tree().paused = false
	var error: Error = get_tree().change_scene_to_file(MENU_SCENE)
	if error != OK:
		_return_pending = false
		_menu_button.disabled = false
		push_error("Не удалось вернуться в меню: %s" % error_string(error))
