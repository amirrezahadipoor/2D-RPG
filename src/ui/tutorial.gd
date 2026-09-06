# First-run touch tutorial: three swipe/tap slides that teach the gesture
# language before the world lets go of your hand. Shown once (Settings flag).
class_name Tutorial
extends CanvasLayer

signal finished

const SLIDES := 3

var _root: Control
var _panel: ColorRect
var _glyph: Control
var _title: Label
var _body: Label
var _page: Label
var _dots: Array[ColorRect] = []
var _slide := 0
var _open_ms := 0

func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("modal_ui")
	_build()
	visible = false

func _build() -> void:
	_root = Control.new()
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_panel = ColorRect.new()
	_panel.color = Color(0.07, 0.07, 0.11, 0.97)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel)
	_glyph = Control.new()
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_glyph)
	_title = _mk_label(12, Color(1, 0.86, 0.4))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_title)
	_body = _mk_label(8, Color(0.82, 0.85, 0.95))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_body)
	for i in SLIDES:
		var d := ColorRect.new()
		d.size = Vector2(4, 4)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(d)
		_dots.append(d)
	_page = _mk_label(7, Color(0.6, 0.63, 0.72))
	_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_page)
	_layout()
	get_viewport().size_changed.connect(_layout)
	I18N.locale_changed.connect(func(_l): if visible: _apply())

func _mk_label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_font_override("font", load(I18N.FONT_REGULAR_PATH))
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_panel.position = Vector2(vp.x * 0.5 - 150, vp.y * 0.5 - 90)
	_panel.size = Vector2(300, 180)
	_glyph.position = Vector2(vp.x * 0.5 - 40, vp.y * 0.5 - 78)
	_glyph.size = Vector2(80, 46)
	_title.position = Vector2(vp.x * 0.5 - 140, vp.y * 0.5 - 24)
	_title.size = Vector2(280, 16)
	_body.position = Vector2(vp.x * 0.5 - 130, vp.y * 0.5 - 4)
	_body.size = Vector2(260, 58)
	for i in SLIDES:
		_dots[i].position = Vector2(vp.x * 0.5 - float(SLIDES) * 4.0 + float(i) * 9.0, vp.y * 0.5 + 60)
	_page.position = Vector2(vp.x * 0.5 - 100, vp.y * 0.5 + 70)
	_page.size = Vector2(200, 10)

var _auto := false

## Open by itself as soon as the intro cutscene and any modal are done.
func request_auto_open() -> void:
	_auto = true

func _process(_delta: float) -> void:
	if not _auto or visible:
		return
	if Game.state != Game.State.PLAYING or get_tree().paused:
		return
	var cs := get_tree().get_first_node_in_group("cutscene")
	if cs != null and bool(cs.get("active")):
		return
	for ui in get_tree().get_nodes_in_group("modal_ui"):
		if ui.visible and ui != self:
			return
	_auto = false
	open()

func open() -> void:
	_slide = 0
	_open_ms = Time.get_ticks_msec()
	visible = true
	_apply()

func close() -> void:
	visible = false
	Settings.set_tutorial_seen(true)
	finished.emit()

func _apply() -> void:
	var keys := [["tut.tap.title", "tut.tap.body"],
			["tut.look.title", "tut.look.body"],
			["tut.fight.title", "tut.fight.body"]]
	_title.text = I18N.tr_str(keys[_slide][0])
	_body.text = I18N.tr_str(keys[_slide][1])
	I18N.tag(_title)
	I18N.tag(_body)
	_page.text = I18N.tr_str("tut.next") if _slide < SLIDES - 1 else I18N.tr_str("tut.begin")
	I18N.tag(_page)
	for i in SLIDES:
		_dots[i].color = Color(1, 0.86, 0.4) if i == _slide else Color(0.35, 0.36, 0.45)
	_draw_glyph()

## Tiny vector vignettes: a finger, a swipe, a crossed sword - no art needed.
func _draw_glyph() -> void:
	for c in _glyph.get_children():
		c.queue_free()
	var put := func(r: Rect2, col: Color) -> void:
		var cr := ColorRect.new()
		cr.position = r.position
		cr.size = r.size
		cr.color = col
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glyph.add_child(cr)
	var skin := Color(0.95, 0.8, 0.62)
	var gold := Color(1, 0.86, 0.4)
	var grey := Color(0.7, 0.73, 0.85)
	match _slide:
		0:  # tap: a finger over a ring
			put.call(Rect2(24, 18, 32, 4), grey)
			put.call(Rect2(38, 4, 4, 14), grey)
			put.call(Rect2(24, 4, 4, 14), grey)
			put.call(Rect2(24, 4, 32, 4), grey)
			put.call(Rect2(36, 24, 8, 16), skin)
			put.call(Rect2(34, 38, 12, 6), skin)
		1:  # drag + flick: an arrow with a speed tail
			put.call(Rect2(8, 22, 44, 4), grey)
			put.call(Rect2(52, 16, 4, 16), grey)
			put.call(Rect2(48, 18, 4, 4), grey)
			put.call(Rect2(56, 18, 4, 4), grey)
			put.call(Rect2(10, 34, 10, 3), gold)
			put.call(Rect2(24, 34, 16, 3), gold)
		2:  # auto-combat: two crossed blades
			for i in 8:
				put.call(Rect2(20 + i * 5, 8 + i * 4, 5, 4), grey)
				put.call(Rect2(55 - i * 5, 8 + i * 4, 5, 4), grey)
			put.call(Rect2(16, 40, 8, 6), gold)
			put.call(Rect2(56, 40, 8, 6), gold)

func advance() -> void:
	# the tap that opens the tutorial must not instantly skip slide one
	if Time.get_ticks_msec() - _open_ms < 250:
		return
	Sfx.play("click")
	if _slide < SLIDES - 1:
		_slide += 1
		_apply()
	else:
		close()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		advance()
		get_viewport().set_input_as_handled()
