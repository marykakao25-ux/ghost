extends Node2D

const CAT_LEVEL_PATH: String = "res://scenes/Level_Cat_Cemetry.tscn"

@onready var _music: AudioStreamPlayer = $AudioStreamPlayer
@onready var _play_button: Button = $CanvasLayer/UI/Center/Buttons/PlayButton
@onready var _quit_button: Button = $CanvasLayer/UI/Center/Buttons/QuitButton

var _released: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_play_button.pressed.connect(_on_play_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	tree_exiting.connect(_release_music)
	# Headless --quit не успевает освободить AudioStreamPlaybackMP3 после autoplay/play.
	if DisplayServer.get_name() == "headless":
		_music.autoplay = false
		_music.stop()
		_music.stream = null
		return
	if _music.stream != null and not _music.playing:
		_music.play()


func _exit_tree() -> void:
	_release_music()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_release_music()


func _on_play_pressed() -> void:
	## Музыку между сценами без Autoload не удержать — останавливаем явно.
	_release_music()
	get_tree().change_scene_to_file(CAT_LEVEL_PATH)


func _on_quit_pressed() -> void:
	_release_music()
	get_tree().quit()


func _release_music() -> void:
	if _released:
		return
	_released = true
	if not is_instance_valid(_music):
		return
	_music.autoplay = false
	if _music.playing:
		_music.stop()
	_music.stream = null
