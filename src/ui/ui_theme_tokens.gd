class_name UiThemeTokens
extends RefCounted

const TOUCH_TARGET := 56
const SPACE_XS := 4
const SPACE_SM := 8
const SPACE_MD := 16
const SPACE_LG := 24
const SPACE_XL := 36
const SURFACE := Color("160c24")
const SURFACE_RAISED := Color("2a173d")
const BORDER := Color("8d672b")
const FOCUS := Color("ffe08a")
const GOLD := Color("e9bd59")
const VIOLET := Color("8d49cc")
const TYPE_SCALE := {"caption":12, "body":16, "action":18, "subtitle":22,
		"title":32, "display":52}

static func type_size(role: String) -> int:
	return int(TYPE_SCALE.get(role, TYPE_SCALE.body))

static func focus_style(radius := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.10, 0.28, 0.96)
	style.border_color = FOCUS
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(FOCUS, 0.35)
	style.shadow_size = 7
	return style
