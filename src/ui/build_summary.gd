class_name BuildSummary
extends PanelContainer
## Compact map readout for the current run build.


func _init() -> void:
	name = "BuildSummary"
	custom_minimum_size = Vector2(0, 66)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.022, 0.075, 0.94)
	style.border_color = Color("675091")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var kit := UiKit.label("KIT", 12, UiKit.COLOR_GOLD)
	kit.name = "BuildKit"
	kit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(kit)
	var counts := UiKit.label("0 RELICS  •  0 UPGRADES", 11, UiKit.COLOR_TEXT_DIM)
	counts.name = "BuildCounts"
	counts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(counts)
	var synergy := UiKit.label("FOUNDATION", 11, Color("9fd7ff"))
	synergy.name = "BuildSynergy"
	synergy.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	synergy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(synergy)


func configure(kit_id: String, relics: Array, upgrades: Array, mutations: Array) -> void:
	(find_child("BuildKit", true, false) as Label).text = _pretty(kit_id)
	(find_child("BuildCounts", true, false) as Label).text = "%d RELICS  •  %d UPGRADES" % [relics.size(), upgrades.size()]
	(find_child("BuildSynergy", true, false) as Label).text = _synergy(kit_id, relics, upgrades, mutations)
	var details: Array[String] = []
	for id in relics: details.append("Relic: " + _pretty(str(id)))
	for id in upgrades: details.append("Upgrade: " + _pretty(str(id)))
	for id in mutations: details.append("Mutation: " + _pretty(str(id)))
	tooltip_text = "Current build\n" + ("No additions yet" if details.is_empty() else "\n".join(details))


func _synergy(kit_id: String, relics: Array, upgrades: Array, mutations: Array) -> String:
	var power := relics.size() * 2 + upgrades.size() + mutations.size() * 2
	var affinity := "EMBER" if "ember" in kit_id else ("VERDANT" if "verdant" in kit_id else "VOID")
	if power >= 8: return affinity + " MASTERY"
	if power >= 4: return affinity + " SYNERGY"
	return affinity + " FOUNDATION"


func _pretty(id: String) -> String:
	return id.replace("_", " ").to_upper()
