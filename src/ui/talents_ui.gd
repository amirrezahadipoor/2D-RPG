# Talent screen (T): spend level-up points on three passive tracks.
class_name TalentsUI
extends CanvasLayer

const KEYS := ["might", "vigor", "swift"]

var _sel := 0
var _tap_frame := -1
var _root: Control
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

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_tap)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE   # let taps reach the root handler
	_root.add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.07, 0.11, 0.97)
	panel.position = Vector2(120, 60)
	panel.size = Vector2(240, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(panel)
	_title = _label(Vector2(0, 68), Color(1, 0.86, 0.4), 11, 480)
	_points = _label(Vector2(0, 84), Color(0.8, 0.85, 1.0), 9, 480)
	for i in 3:
		_rows.append(_label(Vector2(140, 104 + i * 18), Color(0.92, 0.93, 1.0), 9, 220))
	_hint = _label(Vector2(0, 190), Color(0.6, 0.62, 0.7), 8, 480)

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
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		# one physical tap arrives as BOTH a ScreenTouch and a synthesised mouse
		# press in the same frame (emulate_touch_from_mouse); act on it once
		var frame := Engine.get_process_frames()
		if frame == _tap_frame:
			return
		_tap_frame = frame
		var p := Vector2.ZERO
		if event is InputEventMouseButton:
			p = (event as InputEventMouseButton).position
		else:
			p = (event as InputEventScreenTouch).position
		# rows live at x 140..360, y 104 + i*18
		if p.x < 132.0 or p.x > 368.0 or p.y < 100.0 or p.y > 158.0:
			return
		var row := clampi(int((p.y - 100.0) / 18.0), 0, 2)
		if _sel == row:
			Stats.rank_up(KEYS[row])   # tap the already chosen track to spend a point
		else:
			_sel = row
		_refresh()

func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
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
