# Talent screen (T): spend level-up points on three passive tracks.
class_name TalentsUI
extends CanvasLayer

const KEYS := ["might", "vigor", "swift"]

var _sel := 0
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
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.07, 0.11, 0.97)
	panel.position = Vector2(120, 60)
	panel.size = Vector2(240, 150)
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
