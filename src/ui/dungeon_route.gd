class_name DungeonRoute
extends Control
## Illustrated dungeon path. Normalized positions preserve the composition on
## both standard and extra-tall phones.

const NODE_POSITIONS := [
	Vector2(0.40, 0.87), Vector2(0.62, 0.76), Vector2(0.37, 0.63),
	Vector2(0.61, 0.52), Vector2(0.39, 0.39), Vector2(0.62, 0.25),
	Vector2(0.50, 0.11),
]

signal node_selected(node_id: String)

var entries: Array = []
var current_index := 0
var _pulse := 0.0
var graph_nodes: Array = []
var graph_current := ""
var graph_reachable: Array[String] = []


func configure_graph(graph: Dictionary, current_id: String, reachable: Array[String]) -> void:
	graph_nodes = graph.get("nodes", [])
	graph_current = current_id
	graph_reachable = reachable
	_rebuild_graph_nodes()
	queue_redraw()


func configure(battles: Array, active_index: int) -> void:
	entries = battles
	current_index = active_index
	_rebuild_nodes()
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var timer := Timer.new()
	timer.wait_time = 0.04
	timer.timeout.connect(func() -> void:
		_pulse = fmod(_pulse + 0.04, TAU)
		queue_redraw())
	add_child(timer)
	timer.start()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if graph_nodes.is_empty(): _position_nodes()
		else: _position_graph_nodes()
		queue_redraw()


func _draw() -> void:
	if not graph_nodes.is_empty():
		_draw_graph()
		return
	if entries.is_empty():
		return
	var count := mini(entries.size(), NODE_POSITIONS.size())
	for i in range(count - 1):
		var a := _point(i)
		var b := _point(i + 1)
		var unlocked := i < current_index
		draw_line(a, b, Color(0.03, 0.01, 0.07, 0.90), 18.0, true)
		draw_line(a, b, Color("a95df0") if unlocked else Color("5f4b69"), 8.0, true)
		draw_line(a, b, Color("f2c35b") if unlocked else Color("8a7350"), 2.5, true)
		var midpoint := a.lerp(b, 0.5)
		draw_set_transform(midpoint, PI / 4.0)
		draw_rect(Rect2(-6, -6, 12, 12), Color("f8ce65") if unlocked else Color("62556a"), true)
		draw_set_transform(Vector2.ZERO, 0.0)
	var current := _point(current_index)
	var radius := 62.0 + sin(_pulse * 2.0) * 6.0
	draw_arc(current, radius, 0.0, TAU, 48, Color(0.65, 0.25, 1.0, 0.38), 8.0, true)
	draw_arc(current, radius - 5.0, 0.0, TAU, 48, Color(1.0, 0.78, 0.25, 0.75), 2.0, true)


func _rebuild_nodes() -> void:
	for child in get_children():
		if child is Timer:
			continue
		child.queue_free()
	for i in mini(entries.size(), NODE_POSITIONS.size()):
		add_child(_make_medallion(i, entries[i]))
	_position_nodes()


func _rebuild_graph_nodes() -> void:
	for child in get_children():
		if child is not Timer: child.queue_free()
	for node in graph_nodes:
		var button := Button.new()
		button.name = "GraphNode_" + str(node.id)
		button.custom_minimum_size = Vector2(132, 62)
		button.size = button.custom_minimum_size
		button.text = _kind_icon(str(node.kind)) + "\n" + str(node.kind).to_upper()
		button.disabled = str(node.id) not in graph_reachable
		button.tooltip_text = "Floor %d • %s" % [int(node.floor) + 1, str(node.kind).capitalize()]
		button.add_theme_font_size_override("font_size", 14)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("241533") if not button.disabled else Color("110d19")
		style.border_color = _graph_color(node)
		style.set_border_width_all(3 if str(node.id) in graph_reachable else 1)
		style.set_corner_radius_all(16 if str(node.kind) != "boss" else 31)
		style.shadow_color = Color(0.45, 0.12, 0.65, 0.6)
		style.shadow_size = 8 if str(node.id) in graph_reachable else 2
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("disabled", style)
		button.pressed.connect(_emit_node.bind(str(node.id)))
		add_child(button)
	_position_graph_nodes()


func _draw_graph() -> void:
	var by_id := {}
	for node in graph_nodes: by_id[str(node.id)] = node
	for node in graph_nodes:
		for target_id in node.links:
			if not by_id.has(str(target_id)): continue
			var a := _graph_point(node)
			var b := _graph_point(by_id[str(target_id)])
			var active := str(node.id) == graph_current or bool(node.visited)
			draw_line(a, b, Color(0.03, 0.01, 0.06, 0.95), 13.0, true)
			draw_line(a, b, Color("d292ff") if active else Color("51445b"), 5.0, true)
			draw_line(a, b, Color("f2c968") if active else Color("79664e"), 1.5, true)


func _position_graph_nodes() -> void:
	for node in graph_nodes:
		var control := get_node_or_null("GraphNode_" + str(node.id)) as Control
		if control: control.position = _graph_point(node) - control.size * 0.5


func _graph_point(node: Dictionary) -> Vector2:
	var x: float = [0.19, 0.5, 0.81][clampi(int(node.lane), 0, 2)]
	var y: float = lerpf(0.90, 0.09, float(node.floor) / 6.0)
	return Vector2(size.x * x, size.y * y)


func _emit_node(id: String) -> void:
	node_selected.emit(id)


func _graph_color(node: Dictionary) -> Color:
	if str(node.id) == graph_current: return Color("74e990")
	if bool(node.visited): return Color("6f8a68")
	if str(node.id) in graph_reachable: return _node_color(str(node.kind), 0)
	return Color("5e5264")


func _kind_icon(kind: String) -> String:
	match kind:
		"battle": return "⚔"
		"elite": return "✦"
		"boss": return "☠"
		"event": return "?"
		"shop": return "¤"
		"treasure": return "◆"
		"campfire": return "♨"
		_: return "•"


func _make_medallion(index: int, entry: Dictionary) -> Control:
	var kind := str(entry.get("kind", "battle"))
	var enemy_id := str(entry.get("enemy", "slime"))
	var enemy: Dictionary = GameState.enemies.get(enemy_id, {})
	var holder := Control.new()
	holder.name = "RouteNode%d" % index
	var boss := kind == "boss"
	holder.custom_minimum_size = Vector2(190, 150 if boss else 132)
	holder.size = holder.custom_minimum_size

	var portrait_panel := PanelContainer.new()
	portrait_panel.position = Vector2(39 if boss else 45, 0)
	portrait_panel.size = Vector2(112, 112) if boss else Vector2(100, 100)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("110d19") if index >= current_index else Color("25122e")
	style.border_color = _node_color(kind, index)
	style.set_border_width_all(4 if index == current_index else 2)
	style.set_corner_radius_all(56)
	style.shadow_color = Color(0.35, 0.05, 0.55, 0.6) if index == current_index else Color(0, 0, 0, 0.5)
	style.shadow_size = 10 if index == current_index else 4
	portrait_panel.add_theme_stylebox_override("panel", style)
	holder.add_child(portrait_panel)

	var portrait := TextureRect.new()
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
	portrait.texture = VisualRegistry.enemy_texture(enemy_id)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.modulate = Color.WHITE if index <= current_index else Color(0.52, 0.47, 0.58, 0.86)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_panel.add_child(portrait)

	var tag := Label.new()
	tag.position = Vector2(0, 115 if boss else 103)
	tag.size = Vector2(190, 24)
	tag.text = ("BOSS" if boss else "ELITE" if kind == "elite" else "BATTLE") + "  -  " + str(enemy.get("name", "Unknown")).to_upper()
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_override("font", UiKit.title_font())
	tag.add_theme_font_size_override("font_size", 17 if boss else 15)
	tag.add_theme_color_override("font_color", _node_color(kind, index))
	tag.add_theme_constant_override("outline_size", 5)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	holder.add_child(tag)

	if index > current_index:
		var lock := Label.new()
		lock.position = Vector2(76, 38)
		lock.size = Vector2(38, 24)
		lock.text = "LOCK"
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.add_theme_font_size_override("font_size", 10)
		lock.add_theme_color_override("font_color", Color("b3a4ba"))
		holder.add_child(lock)
	return holder


func _node_color(kind: String, index: int) -> Color:
	if index > current_index:
		return Color("a392aa")
	if kind == "boss":
		return Color("ff654f")
	if kind == "elite":
		return Color("d87cff")
	return Color("f4ca67")


func _position_nodes() -> void:
	for i in mini(entries.size(), NODE_POSITIONS.size()):
		var node := get_node_or_null("RouteNode%d" % i) as Control
		if node != null:
			node.position = _point(i) - node.size * 0.5


func _point(index: int) -> Vector2:
	var safe := clampi(index, 0, NODE_POSITIONS.size() - 1)
	return Vector2(size.x * NODE_POSITIONS[safe].x, size.y * NODE_POSITIONS[safe].y)
