class_name BattleHudPresenter
extends RefCounted
## Small, data-only presenter that keeps common HUD copy out of combat rules.

var _parent: Control
var _profile: Dictionary = {}
var _views: Dictionary = {}


func build(parent: Control, profile: Dictionary) -> void:
	_parent = parent
	_profile = profile.duplicate(true)


func bind(views: Dictionary) -> void:
	_views = views


func refresh(model: Dictionary) -> void:
	_set_text("stage", str(model.get("stage", "")))
	_set_text("enemy_name", str(model.get("enemy_name", "")))
	_set_text("countdown", str(model.get("countdown", "")))
	_set_text("undo_count", str(model.get("undo_count", "0")))


func _set_text(id: String, value: String) -> void:
	var view: Variant = _views.get(id)
	if view is Label:
		(view as Label).text = value
