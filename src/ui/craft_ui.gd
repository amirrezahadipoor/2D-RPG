# Recipe book — touch-native, responsive.
class_name CraftUI
extends CanvasLayer

var _root: Control
var _panel: ColorRect
var _rows: Array = []      # [recipe, Control, Label, Label]
var open_flag := false
var _title: Label

func _ready() -> void:
	add_to_group("craft_ui")
	add_to_group("modal_ui")
	layer = 30
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_panel = ColorRect.new()
	_panel.color = Color(0.12, 0.11, 0.16, 0.97)
	_root.add_child(_panel)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 10)
	_title.add_theme_font_override("font", load(I18N.FONT_REGULAR_PATH))
	_title.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_title)
	_title.text = I18N.tr_str("craft.title")
	for i in Recipes.ALL.size():
		var row := Control.new()
		row.size = Vector2(228, 32)
		_root.add_child(row)
		var bg := ColorRect.new()
		bg.color = Color(1, 1, 1, 0.06)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bg)
		var nm := Label.new()
		nm.add_theme_font_size_override("font_size", 8)
		nm.add_theme_font_override("font", load(I18N.FONT_REGULAR_PATH))
		nm.position = Vector2(4, 2)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(nm)
		var cost := Label.new()
		cost.add_theme_font_size_override("font_size", 7)
		cost.add_theme_font_override("font", load(I18N.FONT_REGULAR_PATH))
		cost.position = Vector2(4, 14)
		cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(cost)
		_rows.append([Recipes.ALL[i], row, nm, cost])
	_layout()
	_refresh()
	Settings.settings_changed.connect(_layout)
	I18N.locale_changed.connect(func(_l): _refresh())

func _layout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var safe := SafeArea.get_safe_margins(vp)
	var bars := SafeArea.get_bars(vp)
	var base_w := 480.0
	var base_h := 270.0
	var pw := minf(260.0, base_w - safe.x - safe.z - bars.x - bars.y - 20.0)
	var ph := minf(220.0, base_h - safe.y - safe.w - 20.0)
	var px := safe.x + bars.x + (base_w - safe.x - safe.z - bars.x - bars.y - pw) * 0.5
	var py := safe.y + (base_h - safe.y - safe.w - ph) * 0.5
	_panel.position = Vector2(px, py)
	_panel.size = Vector2(pw, ph)
	_title.position = Vector2(px, py + 4)
	_title.size = Vector2(pw, 14)
	for i in _rows.size():
		_rows[i][1].position = Vector2(px + 6, py + 22 + i * 32)
		_rows[i][1].size = Vector2(pw - 12, 30)

func open() -> void:
	open_flag = true
	_root.visible = true
	_layout()
	_refresh()

func close() -> void:
	open_flag = false
	_root.visible = false

func _refresh() -> void:
	_title.text = I18N.tr_str("craft.title")
	for r in _rows:
		var rec: Dictionary = r[0]
		(r[2] as Label).text = I18N.tr_str("item." + rec["id"])
		var parts := []
		for mat in rec["cost"]:
			parts.append("%d %s" % [int(rec["cost"][mat]), I18N.tr_str("item." + mat)])
		var ok := Recipes.can_craft(rec["cost"])
		(r[3] as Label).text = "  ".join(parts)
		(r[3] as Label).add_theme_color_override("font_color",
				Color(0.55, 0.9, 0.55) if ok else Color(0.75, 0.5, 0.5))
		(r[2] as Label).add_theme_color_override("font_color",
				Color(1, 0.95, 0.8) if ok else Color(0.6, 0.6, 0.6))

func _input(event: InputEvent) -> void:
	if not open_flag:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if not event.is_pressed():
			return
		var p: Vector2 = Vector2.ZERO
		if event is InputEventScreenTouch:
			p = (event as InputEventScreenTouch).position
		else:
			p = (event as InputEventMouseButton).position
		for i in _rows.size():
			var row_ctl: Control = _rows[i][1]
			if Rect2(row_ctl.position, row_ctl.size).has_point(p):
				if Recipes.craft(_rows[i][0]["id"]):
					Sfx.play("levelup", -6.0)
					var hud := get_tree().get_first_node_in_group("hud")
					if hud != null and hud.has_method("show_toast"):
						hud.show_toast(I18N.tr_str("craft.made") % I18N.tr_str("item." + _rows[i][0]["id"]))
				else:
					Sfx.play("denied")
				_refresh()
				get_viewport().set_input_as_handled()
				return
		if not Rect2(_panel.position, _panel.size).has_point(p):
			close()
