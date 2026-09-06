# Recipe book (Phase C3): tap a row to craft when the materials are there.
class_name CraftUI
extends CanvasLayer

var _root: Control
var _rows: Array = []      # [recipe, Control, Label, Label]
var open_flag := false

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
	_root.add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.12, 0.11, 0.16, 0.97)
	panel.position = Vector2(120, 30)
	panel.size = Vector2(240, 210)
	_root.add_child(panel)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 9)
	title.add_theme_font_override("font", load(I18N.FONT_REGULAR_PATH))
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	title.position = Vector2(0, 34)
	title.size = Vector2(480, 12)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = I18N.tr_str("craft.title")
	_root.add_child(title)
	for i in Recipes.ALL.size():
		var row := Control.new()
		row.position = Vector2(126, 52 + i * 26)
		row.size = Vector2(228, 24)
		_root.add_child(row)
		var bg := ColorRect.new()
		bg.color = Color(1, 1, 1, 0.06)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.add_child(bg)
		var nm := Label.new()
		nm.add_theme_font_size_override("font_size", 7)
		nm.add_theme_font_override("font", load(I18N.FONT_REGULAR_PATH))
		nm.position = Vector2(4, 2)
		row.add_child(nm)
		var cost := Label.new()
		cost.add_theme_font_size_override("font_size", 6)
		cost.add_theme_font_override("font", load(I18N.FONT_REGULAR_PATH))
		cost.position = Vector2(4, 12)
		row.add_child(cost)
		_rows.append([Recipes.ALL[i], row, nm, cost])
	_refresh()

func open() -> void:
	open_flag = true
	_root.visible = true
	_refresh()

func close() -> void:
	open_flag = false
	_root.visible = false

func _refresh() -> void:
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
		var p: Vector2 = (event as InputEvent).position
		for i in _rows.size():
			if Rect2(_rows[i][1].position, _rows[i][1].size).has_point(p):
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
		if not Rect2(Vector2(120, 30), Vector2(240, 210)).has_point(p):
			close()
