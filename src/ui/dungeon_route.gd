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
var _boss_depth := 6


func configure_graph(graph: Dictionary, current_id: String, reachable: Array[String]) -> void:
	graph_nodes = graph.get("nodes", [])
	graph_current = current_id
	graph_reachable = reachable
	_rebuild_graph_nodes()
	queue_redraw()


func configure(graph: Dictionary, current_id: String, boss_depth: int) -> void:
	_boss_depth = maxi(boss_depth, 1)
	var reachable: Array[String] = []
	for node in graph.get("nodes", []):
		if str(node.get("id", "")) == current_id:
			for id in node.get("links", []): reachable.append(str(id))
			break
	configure_graph(graph, current_id, reachable)


func configure_legacy(battles: Array, active_index: int) -> void:
	entries = battles
	current_index = active_index
	_rebuild_nodes()
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	var timer := Timer.new()
	timer.wait_time = 0.10
	timer.timeout.connect(func() -> void:
		_pulse = fmod(_pulse + 0.04, TAU)
		queue_redraw())
	add_child(timer)
	if not bool(SaveSystem.setting("reduced_effects")):
		timer.start()
	visibility_changed.connect(func() -> void:
		if not visible: timer.stop()
		elif not bool(SaveSystem.setting("reduced_effects")):
			timer.start())


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
		var disclosure := disclosure_state(str(node.id))
		var button := Button.new()
		button.name = "GraphNode_" + str(node.id)
		button.custom_minimum_size = Vector2(162, 76)
		button.size = button.custom_minimum_size
		button.text = ""
		# Preserve taps while allowing swipe gestures to bubble into the route
		# ScrollContainer for native kinetic scrolling.
		button.mouse_filter = Control.MOUSE_FILTER_PASS
		button.disabled = str(node.id) not in graph_reachable
		button.tooltip_text = "Floor %d - %s" % [int(node.floor) + 1,
				"Known chamber" if disclosure == "revealed" else "Uncharted path"]
		button.add_theme_font_size_override("font_size", 14)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("241533") if not button.disabled else Color("110d19")
		style.border_color = _graph_color(node)
		style.set_border_width_all(3 if str(node.id) in graph_reachable else 1)
		style.set_corner_radius_all(17)
		style.shadow_color = Color(0.45, 0.12, 0.65, 0.6)
		style.shadow_size = 8 if str(node.id) in graph_reachable else 2
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("disabled", style)
		button.pressed.connect(_emit_node.bind(str(node.id)))
		add_child(button)
		_populate_graph_card(button, node)
	_position_graph_nodes()


func _populate_graph_card(button: Button, node: Dictionary) -> void:
	var kind := str(node.kind)
	var disclosure := disclosure_state(str(node.id))
	var revealed := disclosure == "revealed"
	var is_combat := revealed and kind in ["battle", "elite", "boss"]
	var icon_holder := CenterContainer.new()
	icon_holder.position = Vector2(6, 5)
	icon_holder.size = Vector2(54, 59)
	icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon_holder)
	if is_combat:
		var portrait := TextureRect.new()
		portrait.texture = VisualRegistry.enemy_texture(str(node.enemy))
		portrait.custom_minimum_size = Vector2(54, 59)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.modulate = Color.WHITE if not button.disabled else Color(0.48, 0.45, 0.55, 0.82)
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_holder.add_child(portrait)
	elif revealed:
		var rune := UiKit.label(_kind_icon(kind), 24, _node_color(kind, 0))
		rune.custom_minimum_size = Vector2(40, 40)
		icon_holder.add_child(rune)
	else:
		var mystery_rune := UiKit.label("?", 30,
				Color("f1cb68") if disclosure == "mystery" else Color("74667d"))
		mystery_rune.custom_minimum_size = Vector2(40, 40)
		icon_holder.add_child(mystery_rune)
	var copy := VBoxContainer.new()
	copy.position = Vector2(62, 9)
	copy.size = Vector2(94, 58)
	copy.add_theme_constant_override("separation", -1)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(copy)
	var heading := kind.to_upper() if revealed else (
			str(node.get("reveal_kind", "PATH")).to_upper()
			if disclosure == "mystery" else "UNCHARTED")
	# Font sizes stay >= 12 so route decisions are readable on phone screens.
	var kind_label := UiKit.label(heading, 14, _graph_color(node))
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	copy.add_child(kind_label)
	var detail_text := "CHAMBER" if revealed else (
			_risk_pips(int(node.get("risk", 1)))
			if disclosure == "mystery" else "FATE VEILED")
	if revealed and is_combat:
		detail_text = str(GameState.enemies.get(str(node.enemy), {}).get("name", "Unknown"))
	elif revealed and node.has("event_id"):
		detail_text = str(node.event_id).replace("_", " ")
	var detail := UiKit.label(detail_text.to_upper(), 12, UiKit.COLOR_TEXT_DIM)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	copy.add_child(detail)


func _risk_pips(risk: int) -> String:
	var pips := ""
	for index in 4:
		pips += "✦" if index < clampi(risk, 1, 4) else "·"
	return "RISK  " + pips


func _draw_graph() -> void:
	var by_id := {}
	for node in graph_nodes: by_id[str(node.id)] = node
	for node in graph_nodes:
		for target_id in node.links:
			if not by_id.has(str(target_id)): continue
			var a := _graph_point(node)
			var b := _graph_point(by_id[str(target_id)])
			var active := str(node.id) == graph_current or bool(node.get("visited", false))
			draw_line(a, b, Color(0.03, 0.01, 0.06, 0.95), 13.0, true)
			draw_line(a, b, Color("d292ff") if active else Color("51445b"), 5.0, true)
			draw_line(a, b, Color("f2c968") if active else Color("79664e"), 1.5, true)


func _position_graph_nodes() -> void:
	for node in graph_nodes:
		var control := get_node_or_null("GraphNode_" + str(node.id)) as Control
		if control: control.position = _graph_point(node) - control.size * 0.5


func _graph_point(node: Dictionary) -> Vector2:
	var x: float = [0.19, 0.5, 0.81][clampi(int(node.lane), 0, 2)]
	var usable_top := 155.0
	var usable_bottom := maxf(size.y - 155.0, usable_top)
	var progress := clampf(float(node.floor) / maxf(float(_boss_depth), 1.0), 0.0, 1.0)
	var y := lerpf(usable_bottom, usable_top, progress)
	return Vector2(clampf(size.x * x, 74.0, size.x - 74.0), y)


func _emit_node(id: String) -> void:
	node_selected.emit(id)


func disclosure_state(node_id: String) -> String:
	for node in graph_nodes:
		if str(node.id) != node_id: continue
		if bool(node.get("visited", false)) or node_id == graph_current: return "revealed"
		if node_id in graph_reachable: return "mystery"
		return "fog"
	return "fog"


func _graph_color(node: Dictionary) -> Color:
	if str(node.id) == graph_current: return Color("74e990")
	if bool(node.get("visited", false)): return Color("6f8a68")
	if str(node.id) in graph_reachable: return Color("f0c55e")
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
