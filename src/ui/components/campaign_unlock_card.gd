class_name CampaignUnlockCard
extends PanelContainer
## Reusable purchase surface for the one-time campaign entitlement.
## The same copy and purchase/restore behavior appears in the expedition
## selector and Settings so players never have to hunt for the offer.

var _compact := false
var _title: Label
var _description: Label
var _price: Label
var _status: Label
var _buy_button: Button
var _restore_button: Button
var _billing_wired := false


func configure(compact := false) -> CampaignUnlockCard:
	_compact = compact
	name = "CampaignUnlockCard"
	custom_minimum_size = Vector2(0, 188 if compact else 222)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2a1d43")
	style.border_color = Color("d09b47")
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 8
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.name = "CampaignUnlockContent"
	box.add_theme_constant_override("separation", 5 if compact else 7)
	add_child(box)
	var eyebrow := UiKit.label("ONE-TIME PURCHASE  •  FULL CAMPAIGN", 11,
			Color("f4c96a"))
	eyebrow.name = "CampaignUnlockEyebrow"
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(eyebrow)
	_title = UiKit.title_label("UNLOCK EVERY REALM", 22 if compact else 27,
			Color("ffe2a0"))
	_title.name = "CampaignUnlockTitle"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_title)
	_description = UiKit.label(
			"Open all five dark-fantasy realms and keep every boss, hazard, reward, and rematch available.",
			13 if compact else 14, UiKit.COLOR_TEXT)
	_description.name = "CampaignUnlockDescription"
	_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_description)
	var features := UiKit.label("5 REALMS  •  35+ ENCOUNTERS  •  PERMANENT ACCESS", 11,
			Color("b9a7d8"))
	features.name = "CampaignUnlockFeatures"
	features.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(features)
	_price = UiKit.label("US$4.99  •  ONE-TIME PURCHASE", 13, Color("77d8ff"))
	_price.name = "CampaignUnlockPrice"
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_price)
	_buy_button = UiKit.cta_bar("UNLOCK ALL REALMS  •  US$4.99", Color("b96bde"),
			54 if compact else 60)
	_buy_button.name = "BuyFullCampaign"
	_buy_button.add_theme_color_override("font_disabled_color", Color("d8ccef"))
	var buy_ornament := _buy_button.get_node_or_null("CtaOrnament") as TextureRect
	if buy_ornament != null:
		buy_ornament.modulate = Color(1.0, 0.92, 0.70, 0.24)
	_buy_button.tooltip_text = "Unlock the remaining realms permanently through Google Play."
	_buy_button.pressed.connect(_buy_campaign)
	box.add_child(_buy_button)
	var actions := HBoxContainer.new()
	actions.name = "CampaignUnlockActions"
	actions.alignment = BoxContainer.ALIGNMENT_BEGIN
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	_restore_button = UiKit.button("RESTORE PURCHASE", Vector2(0, 42), Color("9bb9ff"))
	_restore_button.name = "RestoreCampaignPurchase"
	_restore_button.custom_minimum_size.x = 190 if compact else 220
	_restore_button.add_theme_font_size_override("font_size", 13)
	_restore_button.pressed.connect(_restore_campaign)
	actions.add_child(_restore_button)
	box.add_child(actions)
	_status = UiKit.label("Connect to Google Play to purchase.", 11, UiKit.COLOR_TEXT_DIM)
	_status.name = "CampaignUnlockStatus"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)
	_wire_billing()
	_refresh()
	return self


func _wire_billing() -> void:
	if _billing_wired:
		return
	_billing_wired = true
	BillingService.entitlement_changed.connect(_on_entitlement_changed)
	BillingService.purchase_available.connect(_on_purchase_available)
	BillingService.status_changed.connect(_on_status_changed)


func _refresh() -> void:
	if not is_instance_valid(_buy_button):
		return
	var unlocked := BillingService.is_entitled()
	var needs_play_connection := OS.get_name() == "Android" and not BillingService.is_available()
	_buy_button.disabled = unlocked or needs_play_connection
	_restore_button.disabled = needs_play_connection
	if unlocked:
		_title.text = "FULL CAMPAIGN UNLOCKED"
		_price.text = "ALL FIVE REALMS ARE OPEN"
		_buy_button.text = "CAMPAIGN UNLOCKED"
		_status.text = "Your permanent access is saved on this device and restored from Google Play."
		_status.add_theme_color_override("font_color", Color("78d89b"))
	else:
		_title.text = "UNLOCK EVERY REALM"
		_price.text = "US$4.99  •  ONE-TIME PURCHASE"
		_buy_button.text = "UNLOCK ALL REALMS  •  US$4.99"
		_status.add_theme_color_override("font_color", UiKit.COLOR_TEXT_DIM)


func _buy_campaign() -> void:
	BillingService.purchase_full_campaign()


func _restore_campaign() -> void:
	BillingService.restore_purchases()


func _on_entitlement_changed(_unlocked: bool) -> void:
	_refresh()


func _on_purchase_available(_available: bool) -> void:
	_refresh()


func _on_status_changed(message: String) -> void:
	if is_instance_valid(_status):
		_status.text = message
