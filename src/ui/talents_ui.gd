# Talent screen — touch-native, responsive.
class_name TalentsUI
extends CanvasLayer

const KEYS := ["might", "vigor", "swift"]

var _sel := 0
var _tap_frame := -1
var _root: Control
var _panel: ColorRect
var _title: Label
var _points: Label
var _rows: Array = []
var _hint: Label

func _ready() -> void:
	layer = 23
	add_to_group("modal_ui")
	_build()
	visible = false
	Stats.talent_changed.connect(func(_p): if visible: _refresh())
	I18N.locale_changed.connect(func(_l): if visible: _refresh())
	Settings.settings_changed.connect(_layout)

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_tap)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_panel = ColorRect.new()
	_panel.color = Color(0.08, 0.07, 0.11, 0.97)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)
	_title = _label(Vector2.ZERO, Color(1, 0.86, 0.4), 12, 480)
	_points = _label(Vector2.ZERO, Color(0.8, 0.85, 1.0), 10, 480)
	for i in 3:
		_rows.append(_label(Vector2.ZERO, Color(0.92, 0.93, 1.0), 10, 220))
	_hint = _label(Vector2.ZERO, Color(0.6, 0.62, 0.7), 9, 480)
	_layout()

func _layout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var safe := SafeArea.get_safe_margins(vp)
	var bars := SafeArea.get_bars(vp)
	var base_w := 480.0
	var base_h := 270.0
	var pw := minf(260.0, base_w - safe.x - safe.z - bars.x - bars.y - 20.0)
	var ph := 160.0
	var px := safe.x + bars.x + (base_w - safe.x - safe.z - bars.x - bars.y - pw) * 0.5
	var py := safe.y + (base_h - safe.y - safe.w - ph) * 0.5
	_panel.position = Vector2(px, py)
	_panel.size = Vector2(pw, ph)
	_title.position = Vector2(px, py + 8)
	_title.size = Vector2(pw, 14)
	_points.position = Vector2(px, py + 24)
	_points.size = Vector2(pw, 14)
	for i in 3:
		_rows[i].position = Vector2(px + 10, py + 44 + i * 28)
		_rows[i].size = Vector2(pw - 20, 20)
	_hint.position = Vector2(px, py + ph - 16)
	_hint.size = Vector2(pw, 14)

func _label(pos: Vector2, col: Color, size: int, width: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(width, 12)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l

func _on_tap(event: InputEvent) -> void:
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		var frame := Engine.get_process_frames()
		if frame == _tap_frame:
			return
		_tap_frame = frame
		var p: Vector2 = Vector2.ZERO
		if event is InputEventMouseButton:
			p = (event as InputEventMouseButton).position
		else:
			p = (event as InputEventScreenTouch).position
		# check panel hit
		if not Rect2(_panel.position, _panel.size).has_point(p):
			visible = false
			get_viewport().set_input_as_handled()
			return
		var local_y := p.y - _panel.position.y - 44.0
		if local_y < 0 or local_y > 84:
			return
		var row := clampi(int(local_y / 28.0), 0, 2)
		if _sel == row:
			Stats.rank_up(KEYS[row])
		else:
			_sel = row
		_refresh()

func toggle() -> void:
	visible = not visible
	if visible:
		_layout()
		_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# keep keyboard for desktop testing but UI is touch-only
	if event.is_action_pressed("move_up"):
		_sel = (_sel + 2) % 3; _refresh(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_sel = (_sel + 1) % 3; _refresh(); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		Stats.rank_up(KEYS[_sel]); _refresh(); get_viewport().set_input_as_handled()

func _refresh() -> void:
	_title.text = I18N.tr_str("talent.title")
	_points.text = "%s: %s" % [I18N.tr_str("talent.points"), I18N.num(Stats.talent_points)]
	for i in 3:
		var key: String = KEYS[i]
		var mark := "> " if i == _sel else "  "
		_rows[i].text = "%s%s  %s %s/10" % [
			mark, I18N.tr_str("talent." + key), I18N.tr_str("talent.rank"), I18N.num(int(Stats.talents[key]))]
		_rows[i].add_theme_color_override("font_color",
			Color(1, 0.9, 0.3) if i == _sel else Color(0.92, 0.93, 1.0))
	_hint.text = I18N.tr_str("talent.up")
	for l in [_title, _points, _hint] + _rows:
		I18N.tag(l)
