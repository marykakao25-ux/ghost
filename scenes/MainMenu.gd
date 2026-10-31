extends Node2D

const CAT_LEVEL_PATH: String = "res://scenes/Level_Cat_Cemetry.tscn"

@onready var _music: AudioStreamPlayer = $AudioStreamPlayer
@onready var _play_button: Button = $CanvasLayer/UI/Center/Buttons/PlayButton
@onready var _quit_button: Button = $CanvasLayer/UI/Center/Buttons/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _on_play_pressed() -> void:
	## Музыку между сценами без Autoload не удержать — останавливаем явно.
	if _music.playing:
		_music.stop()
	get_tree().change_scene_to_file(CAT_LEVEL_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
