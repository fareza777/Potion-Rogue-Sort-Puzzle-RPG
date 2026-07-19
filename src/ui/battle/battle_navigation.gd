class_name BattleNavigation
extends RefCounted
## The only battle collaborator allowed to decide scene destinations.

var _tree: SceneTree


func configure(tree: SceneTree) -> void:
	_tree = tree


func go_to_map() -> void:
	_change("res://scenes/map.tscn")


func go_to_menu() -> void:
	_change("res://scenes/main_menu.tscn")


func go_to_area_select() -> void:
	_change("res://scenes/area_select.tscn")


func _change(path: String) -> void:
	if _tree != null: _tree.change_scene_to_file(path)
