# Shared safe-area + letterbox helper — used by HUD, menus, dialogue, inventory.
# One place, so notch handling is consistent across all screens (was HUD-only).
class_name SafeArea
extends RefCounted

## Returns [safe_l, safe_t, safe_r, safe_b] in design px.
static func get_safe_margins(viewport: Viewport, override_rect: Rect2 = Rect2()) -> Vector4:
	var vp := viewport.get_visible_rect().size
	var st := viewport.get_screen_transform()
	var s := st.get_scale()
	var o := st.get_origin()
	var area := override_rect
	if area.size == Vector2.ZERO:
		area = Rect2(DisplayServer.get_display_safe_area())
		var win := DisplayServer.window_get_size()
		if area.position == Vector2.ZERO and area.size == Vector2(win):
			return Vector4.ZERO
	var l := maxf(0.0, (area.position.x - o.x) / s.x)
	var t := maxf(0.0, (area.position.y - o.y) / s.y)
	var r := maxf(0.0, vp.x - (area.position.x + area.size.x - o.x) / s.x)
	var b := maxf(0.0, vp.y - (area.position.y + area.size.y - o.y) / s.y)
	return Vector4(l, t, r, b)

## Letterbox bar widths in design px (aspect keep centres 480x270).
static func get_bars(viewport: Viewport, rail_override: float = 0.0) -> Vector2:
	if rail_override > 0.0:
		return Vector2(rail_override, rail_override)
	var st := viewport.get_screen_transform()
	var s := st.get_scale()
	var o := st.get_origin()
	var win := DisplayServer.window_get_size()
	var l := o.x / s.x
	var r := (float(win.x) - o.x) / s.x - viewport.get_visible_rect().size.x
	return Vector2(maxf(0.0, l), maxf(0.0, r))
