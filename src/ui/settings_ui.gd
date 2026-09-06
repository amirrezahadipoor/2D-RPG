# Settings overlay — touch-native, responsive.
class_name SettingsUI
extends CanvasLayer

signal closed

enum Row { MASTER, MUSIC, SFX, QUALITY, PANSPEED, TAPRADIUS, AUTOCOMBAT, FPS, UISCALE, LANGUAGE, DONE }

var _sel: int = Row.MASTER
var _root: Control
var _rows: Dictionary = {}
var _panel: ColorRect
var _handled_touch_frame := -1
var _title: Label
var _ver: Label

func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	_build()
	visible = false
	I18N.locale_changed.connect(func(_l): if visible: _refresh())
	Settings.settings_changed.connect(_layout)

func _build() -> void:
	_root = Control.new()
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_panel = ColorRect.new()
	_panel.color = Color(0.08, 0.07, 0.12, 0.97)
	_root.add_child(_panel)
	_title = _mk_label(Vector2.ZERO, 12, Color(1, 0.86, 0.4))
	_title.text = I18N.tr_str("menu.settings")
	_add_row(Row.MASTER, "settings.master", 78)
	_add_row(Row.MUSIC, "settings.music", 96)
	_add_row(Row.SFX, "settings.sfx", 114)
	_add_row(Row.QUALITY, "settings.quality", 132)
	_add_row(Row.PANSPEED, "settings.pan", 150)
	_add_row(Row.TAPRADIUS, "settings.tap_radius", 168)
	_add_row(Row.AUTOCOMBAT, "settings.auto_combat", 186)
	_add_row(Row.FPS, "settings.fps", 204)
	_add_row(Row.UISCALE, "settings.ui_scale", 222)
	_add_row(Row.LANGUAGE, "settings.language", 240)
	_add_row(Row.DONE, "menu.done", 258)
	_ver = Label.new()
	_ver.text = "v1.0.0-mobile · 2026-09-06 fixed-world 20260906"
	_ver.size = Vector2(480, 10)
	_ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ver.add_theme_font_size_override("font_size", 6)
	_ver.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_root.add_child(_ver)
	_layout()
	_refresh()

func _layout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var safe := SafeArea.get_safe_margins(vp)
	var bars := SafeArea.get_bars(vp)
	var base_w := 480.0
	var base_h := 270.0
	var pw := minf(300.0, base_w - safe.x - safe.z - bars.x - bars.y - 20.0)
	var ph := minf(240.0, base_h - safe.y - safe.w - 16.0)
	var px := safe.x + bars.x + (base_w - safe.x - safe.z - bars.x - bars.y - pw) * 0.5
	var py := safe.y + (base_h - safe.y - safe.w - ph) * 0.5
	_panel.position = Vector2(px, py)
	_panel.size = Vector2(pw, ph)
	_title.position = Vector2(px, py + 6)
	_title.size = Vector2(pw, 14)
	_ver.position = Vector2(px, py + ph - 10)
	_ver.size = Vector2(pw, 10)
	for row in _rows:
		var r: Dictionary = _rows[row]
		var base_y: float = float(r["base_y"])
		# map base_y (78..258) to panel local
		var rel := (base_y - 52.0) / 220.0
		var y := py + 22 + rel * (ph - 40)
		r["y"] = y
		(r["left"] as Label).position = Vector2(px + 8, y)
		(r["left"] as Label).size = Vector2(pw * 0.5 - 8, 16)
		(r["value"] as Label).position = Vector2(px + pw * 0.5 + 4, y)
		(r["value"] as Label).size = Vector2(pw * 0.5 - 8, 16)

func _mk_label(pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(480, size + 6)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	I18N.tag(l)
	_root.add_child(l)
	return l

func _add_row(row: Row, key: String, base_y: float) -> void:
	var left := Label.new()
	left.size = Vector2(140, 16)
	left.add_theme_font_size_override("font_size", 10)
	left.add_theme_color_override("font_color", Color(0.85, 0.87, 1.0))
	left.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	left.add_theme_constant_override("outline_size", 2)
	left.text = I18N.tr_str(key)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	I18N.tag(left)
	_root.add_child(left)
	var right := Label.new()
	right.size = Vector2(96, 16)
	right.add_theme_font_size_override("font_size", 10)
	right.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	right.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	right.add_theme_constant_override("outline_size", 2)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	I18N.tag(right)
	_root.add_child(right)
	_rows[row] = {"name": key, "left": left, "value": right, "y": base_y, "base_y": base_y}

func open() -> void:
	visible = true
	_sel = Row.MASTER
	_layout()
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _refresh() -> void:
	_title.text = I18N.tr_str("menu.settings")
	for row in _rows:
		var r: Dictionary = _rows[row]
		var value: Label = r["value"]
		var left: Label = r["left"]
		match row:
			Row.MASTER:
				value.text = _bar(Settings.master)
			Row.MUSIC:
				value.text = _bar(Settings.music)
			Row.SFX:
				value.text = _bar(Settings.sfx)
			Row.QUALITY:
				value.text = I18N.tr_str("quality." + Settings.quality)
			Row.PANSPEED:
				value.text = "%d%%" % int(Settings.pan_speed * 100.0)
			Row.TAPRADIUS:
				value.text = "%dpx" % int(Settings.tap_radius)
			Row.AUTOCOMBAT:
				value.text = I18N.tr_str("settings.on" if Settings.auto_combat else "settings.off")
			Row.FPS:
				value.text = "%d" % Settings.fps_cap
			Row.UISCALE:
				value.text = "%d%%" % int(Settings.ui_scale * 100.0)
			Row.LANGUAGE:
				value.text = "فارسی / EN" if I18N.locale == "en" else "EN / فارسی"
			Row.DONE:
				value.text = ""
		var is_sel := int(row) == _sel
		var name_text: String = I18N.tr_str(r["name"])
		left.text = ("« " + name_text + " »") if is_sel and I18N.is_rtl() else ("> " + name_text if is_sel else name_text)
		I18N.tag(left)
		I18N.tag(value)
		var col: Color = Color(1, 0.95, 0.7) if is_sel else Color(0.75, 0.78, 0.9)
		value.add_theme_color_override("font_color", col)

func _bar(v: float) -> String:
	var filled := int(round(v * 10.0))
	return "[" + "|".repeat(filled) + ".".repeat(10 - filled) + "] %d%%" % int(v * 100.0)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		_handled_touch_frame = Engine.get_process_frames()
		_pointer_press(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Engine.get_process_frames() == _handled_touch_frame:
			return
		_pointer_press(event.position)
		get_viewport().set_input_as_handled()

func _canvas_point(event_pos: Vector2) -> Vector2:
	return _root.get_canvas_transform().affine_inverse() * event_pos

func _row_at(canvas_y: float) -> int:
	var best := int(Row.MASTER)
	var best_d := 1e9
	for row in _rows:
		var r: Dictionary = _rows[row]
		var d := absf(float(r["y"]) + 8.0 - canvas_y)
		if d < best_d:
			best_d = d
			best = int(row)
	if _panel != null:
		if canvas_y < _panel.position.y + 16 or canvas_y > _panel.position.y + _panel.size.y - 4:
			return -1
	return best

func _pointer_press(event_pos: Vector2) -> void:
	var p := _canvas_point(event_pos)
	var row := _row_at(p.y)
	if row < 0:
		return
	_sel = row
	_refresh()
	if row in [Row.DONE, Row.LANGUAGE, Row.QUALITY, Row.AUTOCOMBAT, Row.FPS, Row.UISCALE]:
		Sfx.play("click")
		_activate()
	elif _panel != null and p.x >= _panel.position.x + _panel.size.x * 0.5:
		Sfx.play("click", -12.0, 0.02)
		_scrub_value(p.x)
	else:
		Sfx.play("click", -14.0, 0.02)

func _scrub_value(x: float) -> void:
	if _panel == null:
		return
	var target := clampf((x - (_panel.position.x + _panel.size.x * 0.5)) / (_panel.size.x * 0.5), 0.0, 1.0)
	match _sel:
		Row.MASTER:
			Settings.set_master(target)
		Row.MUSIC:
			Settings.set_music(target)
		Row.SFX:
			Settings.set_sfx(target)
		Row.PANSPEED:
			Settings.set_pan_speed(0.5 + target * 1.5)
		Row.TAPRADIUS:
			Settings.set_tap_radius(8.0 + target * 20.0)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory"):
		Sfx.play("click")
		close()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("move_up"):
		_sel = (_sel + Row.size() - 1) % Row.size()
		Sfx.play("click", -14.0, 0.02)
		_refresh()
	elif event.is_action_pressed("move_down"):
		_sel = (_sel + 1) % Row.size()
		Sfx.play("click", -14.0, 0.02)
		_refresh()
	elif event.is_action_pressed("move_left"):
		_adjust(-1)
	elif event.is_action_pressed("move_right"):
		_adjust(1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		_activate()
	get_viewport().set_input_as_handled()

func _adjust(dir: int) -> void:
	var step := 0.05 * dir
	match _sel:
		Row.MASTER:
			Settings.set_master(Settings.master + step)
			Sfx.play("click", -12.0, 0.02)
		Row.MUSIC:
			Settings.set_music(Settings.music + step)
		Row.SFX:
			Settings.set_sfx(Settings.sfx + step)
			Sfx.play("click", -12.0, 0.02)
		Row.QUALITY:
			var i := (Settings.QUALITIES.find(Settings.quality) + dir + 3) % 3
			Settings.set_quality(Settings.QUALITIES[i])
			Sfx.play("click")
		Row.PANSPEED:
			Settings.set_pan_speed(Settings.pan_speed + 0.1 * dir)
			Sfx.play("click", -12.0, 0.02)
		Row.TAPRADIUS:
			Settings.set_tap_radius(Settings.tap_radius + 2.0 * dir)
			Sfx.play("click", -12.0, 0.02)
		Row.FPS:
			Settings.set_fps_cap(30 if Settings.fps_cap == 60 else 60)
			Sfx.play("click")
		Row.UISCALE:
			Settings.set_ui_scale(Settings.ui_scale + 0.15 if Settings.ui_scale < 1.5 else 1.0)
			Sfx.play("click")
		Row.AUTOCOMBAT:
			Settings.set_auto_combat(not Settings.auto_combat)
			Sfx.play("click")
		Row.LANGUAGE:
			I18N.toggle_locale()
			Sfx.play("click")
	_refresh()

func _activate() -> void:
	match _sel:
		Row.LANGUAGE:
			I18N.toggle_locale()
			Sfx.play("click")
			_refresh()
		Row.QUALITY:
			var i := (Settings.QUALITIES.find(Settings.quality) + 1) % 3
			Settings.set_quality(Settings.QUALITIES[i])
			Sfx.play("click")
			_refresh()
		Row.AUTOCOMBAT:
			Settings.set_auto_combat(not Settings.auto_combat)
			Sfx.play("click")
			_refresh()
		Row.FPS:
			Settings.set_fps_cap(30 if Settings.fps_cap == 60 else 60)
			Sfx.play("click")
			_refresh()
		Row.UISCALE:
			Settings.set_ui_scale(1.0 if Settings.ui_scale > 1.2 else 1.3)
			Sfx.play("click")
			_refresh()
		Row.DONE:
			Sfx.play("click")
			close()
		_:
			Sfx.play("click", -12.0, 0.02)
