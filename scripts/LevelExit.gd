extends Area2D
class_name LevelExit

## Сцена назначения; загрузка и сохранение прогресса выполняются менеджером.
@export_file("*.tscn") var next_scene: String = ""
## Форма, открываемая при переходе; -1 оставляет список форм без изменений.
@export var unlock_form: int = -1
## Подпись видимой зоны выхода.
@export var exit_text: String = "Выход →"

var _transition_pending: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var label: Label = get_node_or_null("Label") as Label
	if label != null:
		label.text = exit_text


func _on_body_entered(body: Node2D) -> void:
	if _transition_pending or not body is PlayerController:
		return
	_transition_pending = true
	# Удалять текущую сцену внутри физического callback небезопасно.
	_begin_transition.call_deferred()


func _begin_transition() -> void:
	if next_scene.is_empty() or not ResourceLoader.exists(next_scene, "PackedScene"):
		push_warning("Выход: сцена назначения пока недоступна: %s" % next_scene)
		_transition_pending = false
		return
	if unlock_form < -1 or unlock_form >= PlayerController.Form.size():
		push_warning("Выход: некорректная форма для разблокировки: %s" % unlock_form)
		_transition_pending = false
		return

	var previous_forms: Array[int] = ShapeShiftManager.unlocked_forms.duplicate()
	var previous_checkpoint: Vector2 = ShapeShiftManager.last_checkpoint
	if unlock_form >= 0:
		ShapeShiftManager.unlock_form(unlock_form)
	# Чекпоинт относится к старому уровню, а не к сцене назначения.
	ShapeShiftManager.set_checkpoint(Vector2.ZERO)
	if not ShapeShiftManager.trigger_level_transition(next_scene):
		ShapeShiftManager.unlocked_forms = previous_forms
		ShapeShiftManager.set_checkpoint(previous_checkpoint)
		ShapeShiftManager.save_progress()
		_transition_pending = false
