# Overworld map — touch-native, responsive.
# Fixed 240x160 was too small on tablet and clipped on notch.
# Now panel is % of safe area, with zoom and pan.
class_name MapOverlay
extends CanvasLayer

signal travel_requested(settlement_index: int)
signal shrine_travel_requested(poi_index: int)

var world: Overworld = null
var zoom := 1.0
var _off := Vector2.ZERO
var _root: Control
var _clip: Control
var _map_tex: TextureRect
var _hero_dot: ColorRect
var _obj_dot: ColorRect
var _markers: Array = []          # [sett_index, ColorRect, map_local]
var _name_lbls: Array = []        # [sett_index, Label, map_local]
var _fog: Array = []              # [ColorRect, base_local]
var _legend: Array = []
var _hero_local := Vector2.ZERO
var _obj_local := Vector2.ZERO
var _baked_seed := -1
var _title: Label
var _hint: Label
var _zoom_chip: Control
var _zoom_lbl: Label
var _border: ColorRect
var _panel_size := Vector2(240, 160)
var _panel_pos := Vector2(120, 55)

const ZOOM_FIT := 1.0
const ZOOM_IN := 2.0
const MAP_TEX_BASE := Vector2(240, 160) # base texture size, scaled by panel
# legacy constants for tests — kept but not used in layout
const MAP_PX := Vector2(240, 160)
const PANEL_POS := Vector2(120, 55)

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	Settings.settings_changed.connect(_layout)
	I18N.locale_changed.connect(func(_l): if visible: _refresh_labels())

func _build() -> void:
	_root = Control.new()
	_root.name = "MapRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_gui)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	_border = ColorRect.new()
	_border.color = Color(0.5, 0.42, 0.28)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_border)

	_clip = Control.new()
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_clip)

	_map_tex = TextureRect.new()
	_map_tex.position = Vector2.ZERO
	_map_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_map_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(_map_tex)

	_title = _label(Vector2.ZERO, Color(1, 0.86, 0.4), 12)
	_hint = _label(Vector2.ZERO, Color(0.62, 0.64, 0.72), 8)

	_hero_dot = _dot(Color(1, 0.92, 0.55), 6)
	_obj_dot = _dot(Color(1, 0.6, 0.2), 7)

	_zoom_chip = Control.new()
	_zoom_chip.size = Vector2(28, 20)
	_zoom_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_zoom_chip)
	var zb := ColorRect.new()
	zb.color = Color(0.5, 0.42, 0.28, 0.95)
	zb.size = Vector2(28, 20)
	zb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_chip.add_child(zb)
	var zbg := ColorRect.new()
	zbg.color = Color(0.08, 0.08, 0.12, 0.95)
	zbg.position = Vector2(1, 1)
	zbg.size = Vector2(26, 18)
	zbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_chip.add_child(zbg)
	_zoom_lbl = Label.new()
	_zoom_lbl.add_theme_font_size_override("font_size", 9)
	_zoom_lbl.add_theme_font_override("font", load(I18N.FONT_REGULAR_PATH))
	_zoom_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	_zoom_lbl.position = Vector2(0, 3)
	_zoom_lbl.size = Vector2(28, 14)
	_zoom_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom_chip.add_child(_zoom_lbl)

	_layout()

func _layout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var safe := SafeArea.get_safe_margins(vp)
	var bars := SafeArea.get_bars(vp)
	var base_w := 480.0
	var base_h := 270.0
	var avail_w := base_w - safe.x - safe.z - bars.x - bars.y - 20.0
	var avail_h := base_h - safe.y - safe.w - 40.0
	# percent panel: 80% width, 70% height, but keep aspect 3:2
	var pw := minf(avail_w * 0.92, 440.0)
	var ph := minf(avail_h * 0.82, 220.0)
	# keep 3:2
	if pw / ph > 1.5:
		pw = ph * 1.5
	else:
		ph = pw / 1.5
	# centre
	var px := safe.x + bars.x + (base_w - safe.x - safe.z - bars.x - bars.y - pw) * 0.5
	var py := safe.y + 24.0 + (base_h - safe.y - safe.w - 24.0 - 20.0 - ph) * 0.5
	_panel_pos = Vector2(px, py)
	_panel_size = Vector2(pw, ph)
	_border.position = _panel_pos - Vector2(2, 2)
	_border.size = _panel_size + Vector2(4, 4)
	_clip.position = _panel_pos
	_clip.size = _panel_size
	_title.position = Vector2(0, safe.y + 2)
	_title.size = Vector2(base_w, 16)
	_hint.position = Vector2(0, py + ph + 6)
	_hint.size = Vector2(base_w, 12)
	_zoom_chip.position = _panel_pos + Vector2(_panel_size.x - 30.0, 2.0)
	_apply_view()

func _label(pos: Vector2, col: Color, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(480, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l

func _dot(col: Color, px: int) -> ColorRect:
	var d := ColorRect.new()
	d.color = col
	d.size = Vector2(px, px)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clip.add_child(d)
	return d

func show_map(w: Overworld) -> void:
	world = w
	_bake_if_needed()
	zoom = ZOOM_FIT
	_off = Vector2.ZERO
	_layout()
	_title.text = I18N.tr_str("map.title")
	_hint.text = I18N.tr_str("map.hint")
	I18N.tag(_title)
	I18N.tag(_hint)
	_place_markers()
	_apply_view()
	visible = true

func hide_map() -> void:
	visible = false

func _to_local(world_pos: Vector2) -> Vector2:
	# map local is relative to base 240x160, scaled to panel
	var base := Vector2(world_pos.x / 25.6, world_pos.y / 25.6)
	# scale base (240x160) to panel size
	return base * (_panel_size / MAP_TEX_BASE)

# ---------------------------------------------------------------- view ------
func set_zoom(z: float) -> void:
	var nz := ZOOM_IN if z > (ZOOM_FIT + ZOOM_IN) * 0.5 else ZOOM_FIT
	if nz == zoom:
		return
	var center := (_off + _panel_size * 0.5) / zoom
	zoom = nz
	if nz == ZOOM_FIT:
		_off = Vector2.ZERO
	else:
		_off = center * zoom - _panel_size * 0.5
		_clamp_off()
	_apply_view()

func toggle_zoom() -> void:
	set_zoom(ZOOM_FIT if zoom > ZOOM_FIT else ZOOM_IN)

func _pan_by(delta_panel: Vector2) -> void:
	if zoom <= ZOOM_FIT:
		return
	_off -= delta_panel
	_clamp_off()
	_apply_view()

func _clamp_off() -> void:
	var max_off := _panel_size * zoom - _panel_size
	_off.x = clampf(_off.x, 0.0, maxf(0.0, max_off.x))
	_off.y = clampf(_off.y, 0.0, maxf(0.0, max_off.y))

func _build_fog() -> void:
	for f in _fog:
		if is_instance_valid(f[0]):
			f[0].free()
	_fog.clear()
	if world == null:
		return
	var cw := 32 * 16.0
	for cy in int(Overworld.WORLD_H / 32):
		for cx in int(Overworld.WORLD_W / 32):
			var ci := cx + cy * int(Overworld.WORLD_W / 32)
			if ci < world.seen_cells.size() and world.seen_cells[ci]:
				continue
			var r := ColorRect.new()
			r.color = Color(0, 0, 0, 0.55)
			var a := _to_local(Vector2(cx * cw, cy * cw))
			var b := _to_local(Vector2((cx + 1) * cw, (cy + 1) * cw))
			r.size = b - a
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_clip.add_child(r)
			_fog.append([r, a])

func _build_legend() -> void:
	for l in _legend:
		if is_instance_valid(l[0]):
			l[0].free()
		if is_instance_valid(l[1]):
			l[1].free()
	_legend.clear()
	var rows := [
		[Color(0.95, 0.85, 0.45), "map.legend.town"],
		[Color(0.9, 0.8, 0.6), "map.legend.village"],
		[Color(0.4, 0.95, 1.0), "map.legend.shrine"],
		[Color(0.95, 0.35, 0.3), "map.legend.camp"],
		[Color(1.0, 0.82, 0.3), "map.legend.ruin"],
		[Color(1, 1, 1), "map.legend.you"],
	]
	for i in rows.size():
		var d := _dot(rows[i][0], 4)
		d.get_parent().remove_child(d)
		_root.add_child(d)
		d.position = _panel_pos + Vector2(4.0, _panel_size.y - 52.0 + i * 8.0)
		var lb := _label(Vector2.ZERO, Color(0.85, 0.85, 0.8), 7)
		lb.position = Vector2(_panel_pos.x + 10.0, _panel_pos.y + _panel_size.y - 54.0 + i * 8.0)
		lb.size = Vector2(120, 10)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lb.text = I18N.tr_str(rows[i][1])
		_legend.append([d, lb])

func _refresh_labels() -> void:
	for l in _legend:
		if is_instance_valid(l[1]):
			I18N.tag(l[1])

func _apply_view() -> void:
	_map_tex.position = -_off
	_map_tex.size = _panel_size * zoom
	_hero_dot.position = _hero_local * zoom - _off - _hero_dot.size * 0.5
	_obj_dot.position = _obj_local * zoom - _off - _obj_dot.size * 0.5
	_obj_dot.visible = _obj_local.x >= 0.0
	for m in _markers:
		if is_instance_valid(m[1]):
			(m[1] as ColorRect).position = (m[2] as Vector2) * zoom - _off - (m[1] as ColorRect).size * 0.5
	for f in _fog:
		if is_instance_valid(f[0]):
			(f[0] as ColorRect).position = (f[1] as Vector2) * zoom - _off
	for nl in _name_lbls:
		if is_instance_valid(nl[1]):
			var li: int = int(nl[0])
			var seen: bool = li < world.discovered.size() and bool(world.discovered[li]) if world != null else false
			(nl[1] as Label).visible = seen
			if seen:
				(nl[1] as Label).position = (nl[2] as Vector2) * zoom - _off + Vector2(6, -4)
	_zoom_lbl.text = "x2" if zoom > ZOOM_FIT else "x1"

# ------------------------------------------------------------- baking -------
const BIOME_COLORS := {
	"water": Color(0.22, 0.34, 0.55), "grass": Color(0.38, 0.52, 0.30),
	"grass2": Color(0.34, 0.49, 0.27), "forest": Color(0.27, 0.43, 0.24),
	"snow": Color(0.86, 0.90, 0.95), "desert": Color(0.82, 0.72, 0.50),
	"swamp": Color(0.36, 0.42, 0.26), "caves": Color(0.44, 0.39, 0.38),
	"graveyard": Color(0.47, 0.44, 0.52), "village": Color(0.55, 0.44, 0.30),
	"town": Color(0.62, 0.48, 0.30),
}
const ROAD_COLOR := Color(0.78, 0.70, 0.55)

func _bake_if_needed() -> void:
	if world == null:
		return
	if _baked_seed == world.world_seed:
		return
	_baked_seed = world.world_seed
	var img := Image.create(int(MAP_TEX_BASE.x), int(MAP_TEX_BASE.y), false, Image.FORMAT_RGB8)
	for y in int(MAP_TEX_BASE.y):
		for x in int(MAP_TEX_BASE.x):
			var t := Vector2i(int(x * 25.6 / 16.0), int(y * 25.6 / 16.0))
			t.x = clampi(t.x, 0, Overworld.WORLD_W - 1)
			t.y = clampi(t.y, 0, Overworld.WORLD_H - 1)
			var biome := world._biome_grid[t.y * Overworld.WORLD_W + t.x]
			var col: Color = BIOME_COLORS.get(biome, Color(0.3, 0.3, 0.3))
			if world._road_grid[t.y * Overworld.WORLD_W + t.x] == 1 and biome not in ["village", "town"]:
				col = ROAD_COLOR
			img.set_pixel(x, y, col)
	_map_tex.texture = ImageTexture.create_from_image(img)

# ------------------------------------------------------------ markers -------
func _place_markers() -> void:
	if world == null:
		return
	_hero_local = _to_local(world.hero.global_position)
	for m in _markers:
		if is_instance_valid(m[1]):
			m[1].free()
	_markers.clear()
	for nl in _name_lbls:
		if is_instance_valid(nl[1]):
			nl[1].free()
	_name_lbls.clear()
	for f in _fog:
		if is_instance_valid(f[0]):
			f[0].free()
	_fog.clear()
	for l in _legend:
		if is_instance_valid(l[0]):
			l[0].free()
		if is_instance_valid(l[1]):
			l[1].free()
	_legend.clear()
	for st in world.settlements:
		var col := Color(0.95, 0.85, 0.45) if st["type"] == "town" else Color(0.9, 0.8, 0.6)
		var d := _dot(col, 4 if st["type"] == "village" else 6)
		var plaza := Vector2(st["plaza"].x * 16.0 + 8.0, st["plaza"].y * 16.0 + 8.0)
		_markers.append([int(st["index"]), d, _to_local(plaza)])
		var lb := Label.new()
		lb.add_theme_font_size_override("font_size", 7)
		lb.add_theme_font_override("font", load(I18N.FONT_REGULAR_PATH))
		lb.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7, 0.85))
		lb.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		lb.add_theme_constant_override("outline_size", 2)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lb.text = I18N.tr_str(st.get("name_key", "place.0"))
		_clip.add_child(lb)
		_name_lbls.append([int(st["index"]), lb, _to_local(plaza)])
	_build_fog()
	_build_legend()
	for lm in world.landmarks:
		var d := _dot(Color(1.0, 0.82, 0.3), 5)
		_markers.append([-3, d, _to_local(Vector2(lm["pos"].x * 16.0 + 8.0, lm["pos"].y * 16.0 + 8.0))])
	for p in world.pois:
		var col := Color(0.4, 0.95, 1.0)
		var sz := 3
		match p["type"]:
			"camp":
				col = Color(0.95, 0.35, 0.3)
				sz = 4
			"signpost":
				col = Color(0.75, 0.6, 0.4)
				sz = 3
		var d := _dot(col, sz)
		_markers.append([-2, d, _to_local(p["pos"])])
	var cave := world.find_child("CaveEntrance", true, false)
	if cave != null:
		var cd := _dot(Color(0.6, 0.5, 0.95), 4)
		_markers.append([-1, cd, _to_local(cave.global_position)])
	var obj := _objective_world_pos()
	_obj_local = _to_local(obj) if obj.x >= 0.0 else Vector2(-1, -1)

func _objective_world_pos() -> Vector2:
	if world == null or QuestLog == null:
		return Vector2(-1, -1)
	for q in QuestLog.active:
		if q.get("kind", "") == "deliver" and int(q.get("progress", 0)) < int(q["goal"]):
			return _settlement_pos(int(q.get("settlement", 0)))
		if int(q.get("progress", 0)) >= int(q["goal"]):
			return _settlement_pos(int(q.get("giver_settlement", 0)))
	var m := QuestLog.current_main()
	if not m.is_empty():
		if int(m.get("progress", 0)) >= int(m["goal"]):
			return _nearest_settlement_pos()
		if m.get("kind", "") == "talk":
			return _settlement_pos(int(q_log_int(m, "settlement")))
	return Vector2(-1, -1)

func q_log_int(m: Dictionary, key: String) -> int:
	return int(m.get(key, 0))

func _settlement_pos(index: int) -> Vector2:
	for st in world.settlements:
		if int(st["index"]) == index:
			var p: Vector2i = st["plaza"]
			return Vector2(p.x * 16.0 + 8.0, (p.y + 1) * 16.0 + 8.0)
	return Vector2(-1, -1)

func _nearest_settlement_pos() -> Vector2:
	var best := Vector2(-1, -1)
	var bd := 1e9
	for st in world.settlements:
		var pos := _settlement_pos(int(st["index"]))
		if pos.x < 0.0:
			continue
		var d := pos.distance_to(world.hero.global_position)
		if d < bd:
			bd = d
			best = pos
	return best

# --------------------------------------------------- touch: pan then tap ----
var _down_ok := false
var _down_p := Vector2.ZERO
var _last_p := Vector2.ZERO
var _moved_pan := 0.0

func _panel_point(event_pos: Vector2) -> Vector2:
	return _root.get_canvas_transform().affine_inverse() * event_pos

func _on_gui(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var t: InputEventScreenTouch = event
		_last_touch_ms = Time.get_ticks_msec()
		if t.pressed:
			_down_ok = true
			_down_p = _panel_point(t.position)
			_last_p = _down_p
			_moved_pan = 0.0
		elif _down_ok:
			_down_ok = false
			if _moved_pan <= 12.0: # was 6, too tight BUG-106
				_tap_at(_down_p)
	elif event is InputEventScreenDrag:
		var d: InputEventScreenDrag = event
		if not _down_ok:
			return
		var p := _panel_point(d.position)
		var delta := p - _last_p
		_last_p = p
		_moved_pan += delta.length()
		if _moved_pan > 10.0: # was 6
			_pan_by(delta)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if Time.get_ticks_msec() - _last_touch_ms < 900:
			return
		if mb.pressed:
			_down_ok = true
			_down_p = _panel_point(mb.position)
			_last_p = _down_p
			_moved_pan = 0.0
		elif _down_ok:
			_down_ok = false
			if _moved_pan <= 12.0:
				_tap_at(_down_p)

var _tap_frame := -1
var _last_touch_ms := -1000

func _tap_at(p: Vector2) -> void:
	if Engine.get_process_frames() == _tap_frame:
		return
	_tap_frame = Engine.get_process_frames()
	if Rect2(_zoom_chip.position, _zoom_chip.size).has_point(p):
		toggle_zoom()
		return
	var panel := Rect2(_panel_pos, _panel_size)
	if not panel.has_point(p):
		close_request()
		return
	var q := _root.get_canvas_transform() * p
	for m in _markers:
		if int(m[0]) >= 0 and is_instance_valid(m[1]):
			var r: Rect2 = (m[1] as ColorRect).get_global_rect()
			if r.grow(6.0).has_point(q): # bigger hit
				# check discovered before travel (BUG)
				if world != null and int(m[0]) < world.discovered.size() and not world.discovered[int(m[0])]:
					# undiscovered — show toast, don't travel
					for child in get_tree().root.get_children():
						var hud = child.get_node_or_null("Hud")
						if hud != null and hud.has_method("show_toast"):
							hud.show_toast(I18N.tr_str("toast.discovered_locked"))
							break
					return
				travel_requested.emit(int(m[0]))
				return
	for mi in _markers.size():
		var m: Array = _markers[mi]
		if int(m[0]) != -2 or not is_instance_valid(m[1]):
			continue
		var r: Rect2 = (m[1] as ColorRect).get_global_rect()
		if not r.grow(6.0).has_point(q):
			continue
		for pi in world.pois.size():
			if world.pois[pi]["type"] != "shrine":
				continue
			var ml: Vector2 = m[2]
			var pl := _to_local(world.pois[pi]["pos"])
			if (ml - pl).length() < 1.0 and pi < world.poi_seen.size() and world.poi_seen[pi]:
				shrine_travel_requested.emit(pi)
				return
	close_request()

func close_request() -> void:
	for child in get_tree().root.get_children():
		if child.has_method("close_map") and child.name == "Main":
			child.close_map()
			return
	hide_map()
