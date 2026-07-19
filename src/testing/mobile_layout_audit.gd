class_name MobileLayoutAudit
extends RefCounted
## Deterministic headless checks for touch targets and primary-screen clipping.


static func inspect(root: Control, viewport_size: Vector2) -> Array[String]:
	var issues: Array[String] = []
	var viewport_rect := Rect2(Vector2.ZERO, viewport_size)
	for raw_control in root.find_children("*", "BaseButton", true, false):
		var control := raw_control as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if control.size.x < UiThemeTokens.TOUCH_MIN \
				or control.size.y < UiThemeTokens.TOUCH_MIN:
			issues.append("%s:touch" % control.name)
		var local_rect := control.get_global_rect()
		local_rect.position -= root.global_position
		if _inside_scroll_container(control):
			if local_rect.end.x > viewport_rect.end.x + 1.0 \
					or local_rect.position.x < -1.0:
				issues.append("%s:horizontal_clip" % control.name)
		elif local_rect.intersects(viewport_rect) and not viewport_rect.encloses(local_rect):
			issues.append("%s:clip" % control.name)
	return issues


static func _inside_scroll_container(control: Control) -> bool:
	var current := control.get_parent()
	while current != null:
		if current is ScrollContainer:
			return true
		current = current.get_parent()
	return false
