extends Area2D
class_name Obstacle

signal checkpoint_reset(reason: String)

enum ObstacleType { CRAWL_UNDER, JUMP_OVER, FLY_AROUND, HAZARD }

const _FORM_NAMES: Dictionary[int, String] = {
	PlayerController.Form.CAT: "cat",
	PlayerController.Form.DOG: "dog",
	PlayerController.Form.BIRD: "bird",
}

## Тип препятствия; HAZARD опасен для любой формы.
@export var obstacle_type: ObstacleType = ObstacleType.CRAWL_UNDER
## Допустимые формы: cat, dog, bird. Пустой список запрещает все формы.
@export var allowed_forms: Array[String] = ["cat"]

var _reset_pending: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _reset_pending or not body is PlayerController:
		return
	var player: PlayerController = body as PlayerController
	var form_name: String = _FORM_NAMES.get(player.current_form, "")
	if obstacle_type != ObstacleType.HAZARD and allowed_forms.has(form_name):
		return

	# Обработчик рестарта может синхронно вызвать этот сигнал повторно.
	_reset_pending = true
	_clear_reset_pending.call_deferred()
	checkpoint_reset.emit(_get_reset_reason())


func _clear_reset_pending() -> void:
	_reset_pending = false


func _get_reset_reason() -> String:
	match obstacle_type:
		ObstacleType.CRAWL_UNDER:
			return "Эта форма не может пролезть под препятствием."
		ObstacleType.JUMP_OVER:
			return "Эта форма не может перепрыгнуть препятствие."
		ObstacleType.FLY_AROUND:
			return "Эта форма не может облететь препятствие."
		ObstacleType.HAZARD:
			return "Игрок попал в опасную зону."
	return "Игрок столкнулся с препятствием."
