class_name Tutorial
extends PanelContainer
## Interactive tutorial banner shown during the first battle (until completed
## once). Short hints that advance when the player actually performs each step;
## no walls of text, no input blocking.

var _step := -1
var _label: Label

var _steps: Array[String] = [
	"Tap a glowing tube to pick it up.",
	"Tap another tube to pour. Colors must match!",
	"Fill a tube with 4 of one color to unleash the potion!",
	"Potions strike instantly! The enemy hits back every few moves — watch the counter.",
	"Blue potions raise a shield to block attacks. Brew to victory!",
]


func setup(board: PuzzleBoard, battle: BattleManager) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1c2e1f")
	style.set_corner_radius_all(12)
	style.border_color = UiKit.COLOR_GOLD_DIM
	style.set_border_width_all(2)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	_label = UiKit.label("", 21, UiKit.COLOR_GOLD)
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_label)

	board.tube_selected.connect(func() -> void: _reach(1))
	board.move_made.connect(func() -> void: _reach(2))
	board.tube_completed.connect(_on_tube_completed)
	battle.enemy_attacked.connect(
			func(_d: int, _b: int, _c: bool) -> void: _reach(4))
	_advance(0)


func _on_tube_completed(color: String) -> void:
	if color == "blue" and _step >= 4:
		_finish()
	else:
		_reach(3)


## Move forward to a step (never backwards).
func _reach(step: int) -> void:
	if step > _step:
		_advance(step)


func _advance(step: int) -> void:
	_step = step
	if _step >= _steps.size():
		_finish()
		return
	_label.text = "Tutorial:  " + _steps[_step]


func _finish() -> void:
	if not visible:
		return
	SaveSystem.mark_tutorial_done()
	_label.text = "You're ready. Good luck, alchemist!"
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(hide)
