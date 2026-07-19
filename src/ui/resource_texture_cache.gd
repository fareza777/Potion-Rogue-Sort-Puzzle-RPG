class_name ResourceTextureCache
extends RefCounted
## Shared runtime-generated textures keyed by semantic palette.

static var _bars: Dictionary = {}


static func bar_texture(kind: String, base: Color, jewel_fill: bool) -> Texture2D:
	var key := "%s:%s:%s" % [kind, base.to_html(), jewel_fill]
	if _bars.has(key): return _bars[key]
	var image := Image.create(256, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 256:
			var uv := Vector2(float(x) / 255.0, float(y) / 31.0)
			var color := base.darkened(0.10 + uv.y * 0.10)
			if jewel_fill:
				color = base.darkened(0.22).lerp(base.lightened(0.17), uv.x)
				color = color.lightened(0.22 * maxf(0.0, 1.0 - uv.y * 3.2))
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	_bars[key] = texture
	return texture


static func cache_size() -> int:
	return _bars.size()
