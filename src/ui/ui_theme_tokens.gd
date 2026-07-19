class_name UiThemeTokens
extends RefCounted

const SPACE := {"xs":4, "sm":8, "md":12, "lg":16, "xl":24, "xxl":32}
const TYPE := {"caption":12, "body":14, "body_large":16, "subhead":18,
		"heading":22, "display":36, "hero":52}
const TOUCH_MIN := 56
const REALM_ACCENTS := {
	"shadow_crypt": Color("9f6bd2"),
	"verdant_catacombs": Color("65c98b"),
	"astral_foundry": Color("6bbff0"),
	"frostbound_reliquary": Color("77d9f5"),
	"abyssal_apothecary": Color("43d6c5"),
}
const TOUCH_TARGET := TOUCH_MIN
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
const TYPE_SCALE := {"caption":TYPE.caption, "body":TYPE.body_large, "action":TYPE.subhead,
		"subtitle":TYPE.heading, "title":32, "display":TYPE.hero}

static func type_size(role: String) -> int:
	return int(TYPE_SCALE.get(role, TYPE_SCALE.body))


static func contrast_ratio(foreground: Color, background: Color) -> float:
	var lighter := maxf(_luminance(foreground), _luminance(background))
	var darker := minf(_luminance(foreground), _luminance(background))
	return (lighter + 0.05) / (darker + 0.05)


static func _luminance(color: Color) -> float:
	var values: Array[float] = []
	for channel in [color.r, color.g, color.b]:
		values.append(channel / 12.92 if channel <= 0.04045 \
				else pow((channel + 0.055) / 1.055, 2.4))
	return values[0] * 0.2126 + values[1] * 0.7152 + values[2] * 0.0722

static func focus_style(radius := 14) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.10, 0.28, 0.96)
	style.border_color = FOCUS
	style.set_border_width_all(3)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(FOCUS, 0.35)
	style.shadow_size = 7
	return style
