extends Control

const POSSESSION_SCRIPT: Script = preload("res://scenes/Intro.gd")
const TYPE_SPEED: float = 32.0

const LINES: Array[String] = [
	"Каждый хочет прожить интересную жизнь.",
	"Но не у каждого есть такая возможность с самого начала.",
    "Помогите призраку обрести себя."
]

@onready var dialogue_text: RichTextLabel = $DialoguePanel/Content/DialogueText
@onready var next_button: Button = $DialoguePanel/Content/ButtonRow/NextButton
@onready var fade: ColorRect = $Fade

var _line_index: int = 0
var _typing_tween: Tween
var _transitioning: bool = false


func _ready() -> void:
	fade.color = Color.BLACK
	dialogue_text.custom_minimum_size.y = 120.0
	dialogue_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_text.add_theme_font_size_override("normal_font_size", 28)
	next_button.pressed.connect(_on_next_pressed)
	_show_line()
	await _fade_to(0.0, 0.8)


func _show_line() -> void:
	dialogue_text.text = LINES[_line_index]
	dialogue_text.visible_ratio = 0.0

	_typing_tween = create_tween()
	var duration: float = maxf(
		float(dialogue_text.text.length()) / TYPE_SPEED,
		0.25
	)
	_typing_tween.tween_property(dialogue_text, "visible_ratio", 1.0, duration)


func _on_next_pressed() -> void:
	if _transitioning:
		return

	if _typing_tween != null and _typing_tween.is_running():
		_typing_tween.kill()
		dialogue_text.visible_ratio = 1.0
		return

	_line_index += 1
	if _line_index >= LINES.size():
		_open_possession_scene()
		return

	_show_line()


func _open_possession_scene() -> void:
	if _transitioning:
		return

	_transitioning = true
	next_button.disabled = true
	await _fade_to(1.0, 0.8)

	var possession_root := Node2D.new()
	possession_root.name = "PossessionIntro"
	possession_root.set_script(POSSESSION_SCRIPT)
	var possession_scene := PackedScene.new()
	var pack_error: Error = possession_scene.pack(possession_root)
	if pack_error != OK:
		push_error("Не удалось собрать сцену встречи с котом: %s" % error_string(pack_error))
		return

	var change_error: Error = get_tree().change_scene_to_packed(possession_scene)
	if change_error != OK:
		push_error("Не удалось открыть сцену встречи с котом: %s" % error_string(change_error))


func _fade_to(alpha: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(fade, "color:a", alpha, duration)
	await tween.finished
