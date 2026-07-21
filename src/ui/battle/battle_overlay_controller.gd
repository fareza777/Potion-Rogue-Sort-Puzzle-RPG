class_name BattleOverlayController
extends RefCounted
## Presents modal states with one consistent narrow-phone-safe button stack.

var _root: Control
var _title: Label
var _body: Label
var _choices: VBoxContainer
var _buttons: VBoxContainer


func configure(root: Control, title: Label, body: Label,
		choices: VBoxContainer, buttons: VBoxContainer) -> void:
	_root = root; _title = title; _body = body; _choices = choices; _buttons = buttons


func show_reward(kind := "Reward", choices: Array = []) -> void:
	show(kind, "Choose one reward.", choices)


func show_pause(buttons: Array = []) -> void:
	show("Paused", "Your exact battle state is saved automatically.", buttons)


func show_notice(kicker: String, title: String, body: String) -> void:
	show(kicker + "\n" + title, body, [["CONTINUE", Callable(self, "hide")]])


func show(title: String, body: String, buttons: Array) -> void:
	if _root == null: return
	_title.text = title
	_body.text = body
	_body.visible = not body.is_empty()
	_clear(_choices); _clear(_buttons)
	for entry in buttons:
		var button := UiKit.ornate_button(str(entry[0]), Vector2(390, 58))
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(entry[1] as Callable)
		_buttons.add_child(button)
	_root.visible = true


func hide() -> void:
	if _root != null: _root.visible = false


func _clear(container: Control) -> void:
	for child in container.get_children(): child.queue_free()
