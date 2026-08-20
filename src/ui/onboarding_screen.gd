extends Control
## Six animated, skippable chapters before the interactive battle tutorial.

const PAGES := [
	{"id":"sort", "eyebrow":"THE ALCHEMY TABLE", "title":"SORT THE ESSENCE",
		"body":"Tap a source flask, then an empty flask or one with the same top color. Only connected top layers pour.", "accent":"62d8ff"},
	{"id":"brew", "eyebrow":"POTION EFFECTS", "title":"BREW YOUR POWER",
		"body":"Complete four matching layers. Red damages, Green heals, Blue shields, and Purple poisons through Armor.", "accent":"f1c45c"},
	{"id":"survive", "eyebrow":"ENEMY INTENT", "title":"COUNT EVERY POUR",
		"body":"Each successful pour spends one move. When the intent countdown reaches zero, the enemy performs its shown action.", "accent":"ff8a68"},
	{"id":"react", "eyebrow":"ALCHEMY REACTIONS", "title":"THE THREE COLORED DOTS",
		"body":"The dots remember your last three completed potion colors. Their order forms reactions: Red then Red triggers Fire Burst.", "accent":"d99aff"},
	{"id":"cast", "eyebrow":"HERO POWERS", "title":"MANA, SKILL & ULTIMATE",
		"body":"Potions generate Mana for your active Skill. Reactions separately charge your Ultimate; at 100% it becomes available.", "accent":"70d9ff"},
	{"id":"explore", "eyebrow":"ROGUELIKE EXPEDITION", "title":"CHOOSE YOUR FATE",
		"body":"Every run creates new hidden routes, enemies, events, relics, and battle formats. Your exact progress is saved automatically.", "accent":"be7cff"},
]

var _page := 0
var _eyebrow: Label
var _title: Label
var _body: Label
var _dots: HBoxContainer
var _dot_marks: Array[Panel] = []
var _back: Button
var _next: Button
var _card: PanelContainer
var _card_content: VBoxContainer
var _demo: OnboardingDemo
var _page_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.battle_background(self, "res://assets/art/backgrounds/launch_splash_v3.jpg")
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.005, 0.002, 0.02, 0.42)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var profile := UiKit.layout_profile(get_viewport_rect().size)
	var narrow := get_viewport_rect().size.x < 640.0
	var margin := UiKit.safe_margin(self, 20 if narrow else 26,
			int(profile.get("safe_top", 30)), int(profile.get("safe_bottom", 26)))
	var root := VBoxContainer.new()
	root.name = "OnboardingStack"
	root.add_theme_constant_override("separation", 6)
	margin.add_child(root)

	var top_row := HBoxContainer.new()
	top_row.name = "OnboardingTopRow"
	root.add_child(top_row)
	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(top_spacer)
	var skip := UiKit.button("SKIP", Vector2(112, 52), Color("b9a9c8"))
	skip.name = "OnboardingSkip"
	skip.add_theme_font_size_override("font_size", 16)
	skip.pressed.connect(_finish)
	top_row.add_child(skip)

	var brand := UiKit.title_label("POTION ROGUE", 34 if narrow else 42, Color("f1cf79"))
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_color_override("font_shadow_color", Color(0.1, 0.02, 0.18, 0.95))
	brand.add_theme_constant_override("shadow_offset_x", 3)
	brand.add_theme_constant_override("shadow_offset_y", 4)
	root.add_child(brand)
	var legend := UiKit.label("A ROGUE ALCHEMIST'S JOURNEY", 12 if narrow else 13,
			Color("cdb5ef"))
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(legend)

	# The demo is centred inside whatever height is left over rather than
	# stretched into it: the teaching art is authored around a fixed radius and
	# turns into a thin empty ring when it is scaled up to fill a tall screen.
	var demo_holder := CenterContainer.new()
	demo_holder.name = "OnboardingDemoHolder"
	demo_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(demo_holder)
	_demo = OnboardingDemo.new()
	demo_holder.add_child(_demo)
	var demo_extent := clampf(get_viewport_rect().size.x - 56.0, 240.0, 360.0)
	_demo.custom_minimum_size = Vector2(demo_extent, demo_extent)

	# Measured against the rendered frame: battle_panel.png lands its gold
	# filigree about 60px in from each edge, and hangs a crest over the middle
	# of the top rail, so the card breathes asymmetrically inside the ornament.
	_card = UiKit.textured_panel("res://assets/art/ui/battle_panel.png",
			58 if narrow else 64)
	_inset_card(_card, 64, 78, 64)
	_card.name = "OnboardingCard"
	root.add_child(_card)
	_card_content = VBoxContainer.new()
	_card_content.name = "OnboardingCardContent"
	_card_content.add_theme_constant_override("separation", 8 if narrow else 10)
	_card.add_child(_card_content)
	_eyebrow = UiKit.label("", 12 if narrow else 13, Color("8edcff"))
	_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_content.add_child(_eyebrow)
	_title = UiKit.title_label("", 27 if narrow else 33)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_content.add_child(_title)
	_body = UiKit.label("", 15 if narrow else 17, UiKit.COLOR_TEXT)
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(0, 84)
	_card_content.add_child(_body)
	# The page dots sit below the frame: inside it they land on the carved
	# ledge at the bottom of the ornament and read as damage, not as a control.
	root.add_child(_build_dots())

	# Actions live outside the ornate frame: nesting a second battle_panel
	# button inside the card stacked two frames and clipped the labels.
	var actions := HBoxContainer.new()
	actions.name = "OnboardingActions"
	actions.add_theme_constant_override("separation", 10)
	root.add_child(actions)
	_back = UiKit.cta_bar("BACK", Color("8d70b8"), 56 if narrow else 60)
	_back.name = "OnboardingBack"
	_back.size_flags_stretch_ratio = 0.62
	_back.add_theme_font_size_override("font_size", 20 if narrow else 22)
	_back.add_theme_constant_override("outline_size", 4)
	_back.pressed.connect(_previous)
	_quiet_ornament(_back)
	actions.add_child(_back)
	_next = UiKit.cta_bar("NEXT", Color("f1c45c"), 56 if narrow else 60)
	_next.name = "OnboardingNext"
	_next.add_theme_font_size_override("font_size", 20 if narrow else 22)
	_next.add_theme_constant_override("outline_size", 4)
	_next.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.02, 0.9))
	_next.pressed.connect(_advance)
	_quiet_ornament(_next)
	actions.add_child(_next)

	_show_page(false)


## PanelContainer only exposes symmetric margins through UiKit; the ornate
## frame needs a deeper top inset to clear its crest.
func _inset_card(card: PanelContainer, horizontal: int, top: int, bottom: int) -> void:
	var style := card.get_theme_stylebox("panel") as StyleBoxTexture
	if style == null:
		return
	style.content_margin_left = float(horizontal)
	style.content_margin_right = float(horizontal)
	style.content_margin_top = float(top)
	style.content_margin_bottom = float(bottom)


## Wide, short CTAs pull the banner filigree straight across the label. These
## two sit under a busy background, so the ornament recedes instead.
func _quiet_ornament(button: Button) -> void:
	var ornament := button.get_node_or_null("CtaOrnament") as TextureRect
	if ornament != null:
		ornament.modulate = Color(1.0, 0.92, 0.70, 0.16)


func _build_dots() -> HBoxContainer:
	_dots = HBoxContainer.new()
	_dots.name = "OnboardingDots"
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 10)
	_dots.custom_minimum_size = Vector2(0, 22)
	for index in PAGES.size():
		var mark := Panel.new()
		mark.custom_minimum_size = Vector2(10, 10)
		# Without this the HBox stretches each dot into a tall pill.
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dot_marks.append(mark)
		_dots.add_child(mark)
	return _dots


func _show_page(animate := true) -> void:
	var data: Dictionary = PAGES[_page]
	var accent := Color(str(data.accent))
	_eyebrow.text = str(data.eyebrow)
	_title.text = str(data.title)
	_title.add_theme_color_override("font_color", accent)
	_body.text = str(data.body)
	for index in _dot_marks.size():
		var style := StyleBoxFlat.new()
		style.bg_color = accent if index == _page else Color("d8b6ff", 0.30)
		style.set_corner_radius_all(5)
		_dot_marks[index].add_theme_stylebox_override("panel", style)
	_back.disabled = _page == 0
	_next.text = "ENTER THE DUNGEON" if _page == PAGES.size() - 1 else "NEXT"
	var reduced := bool(SaveSystem.setting("reduced_effects"))
	_demo.show_chapter(str(data.id), reduced)
	if not animate or reduced:
		_card_content.modulate.a = 1.0
		return
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	_card_content.modulate.a = 0.15
	_page_tween = create_tween()
	_page_tween.tween_property(_card_content, "modulate:a", 1.0, 0.26) \
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _advance() -> void:
	if _page >= PAGES.size() - 1:
		_finish()
		return
	_page += 1
	_show_page()


func _previous() -> void:
	_page = maxi(_page - 1, 0)
	_show_page()


func _finish() -> void:
	SaveSystem.mark_onboarding_done()
	SceneRouter.go_to("res://scenes/main_menu.tscn")
