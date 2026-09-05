# Inventory & equipment screen. Big 32px icons (2x the 16px atlas cells, so
# pixels stay square), rarity frames, EN/FA tooltips with affixes.
class_name InventoryScreen
extends CanvasLayer

const COLS := 6
const ROWS := 4
const CELL := 34.0
const ICON := 32.0
const GRID_ORIGIN := Vector2(24, 42)
const WORN_ORIGIN := Vector2(24, 188)
const TIP_X := 240.0

var selected := 0

var _root: Control
var _cells: Array = []        # 30 dicts: {frame, icon, index}
var _title: Label
var _weight: Label
var _hint: Label
var _worn_label: Label
var _tip_icon: TextureRect
var _tip_name: Label
var _tip_rarity: Label
var _tip_slot: Label
var _tip_stats: Label

func _ready() -> void:
	layer = 20
	_build()
	visible = false
	Inventory.changed.connect(func(): if visible: _refresh())
	Inventory.equipment_changed.connect(func(): if visible: _refresh())
	I18N.locale_changed.connect(func(_l): if visible: _refresh_text())

# ------------------------------------------------------------------ build ---
func _build() -> void:
	_root = Control.new()
	_root.name = "InvRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var border := ColorRect.new()
	border.color = Color(0.35, 0.3, 0.22)
	border.position = Vector2(13, 18)
	border.size = Vector2(454, 234)
	_root.add_child(border)
	var panel := ColorRect.new()
	panel.color = Color(0.09, 0.08, 0.12, 0.97)
	panel.position = Vector2(14, 19)
	panel.size = Vector2(452, 232)
	_root.add_child(panel)

	_title = _label(Vector2(0, 24), Color(1, 0.86, 0.4), 11)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.size = Vector2(480, 14)

	# bag grid + worn row: one button per cell
	for i in COLS * ROWS + COLS:
		var cell := _make_cell(i)
		_cells.append(cell)

	_worn_label = _label(WORN_ORIGIN + Vector2(COLS * CELL + 8, 10), Color(0.7, 0.72, 0.8), 8)

	# tooltip column
	_tip_icon = TextureRect.new()
	_tip_icon.position = Vector2(TIP_X + 6, 48)
	_tip_icon.size = Vector2(ICON, ICON)
	_tip_icon.stretch_mode = TextureRect.STRETCH_KEEP
	_tip_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(_tip_icon)
	_tip_name = _label(Vector2(TIP_X + 44, 46), Color.WHITE, 9)
	_tip_name.size = Vector2(480 - TIP_X - 52, 24)
	_tip_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_rarity = _label(Vector2(TIP_X + 44, 70), Color.WHITE, 8)
	_tip_slot = _label(Vector2(TIP_X + 6, 88), Color(0.75, 0.78, 0.85), 8)
	_tip_stats = _label(Vector2(TIP_X + 6, 100), Color(0.9, 0.92, 1.0), 9)
	_tip_stats.size = Vector2(480 - TIP_X - 20, 60)

	_weight = _label(Vector2(24, 228), Color(0.8, 0.8, 0.7), 8)
	_hint = _label(Vector2(0, 240), Color(0.6, 0.62, 0.7), 8)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.size = Vector2(480, 10)

func _make_cell(index: int) -> Dictionary:
	var pos: Vector2
	if index < COLS * ROWS:
		pos = GRID_ORIGIN + Vector2(float(index % COLS) * CELL, float(index / COLS) * CELL)
	else:
		pos = WORN_ORIGIN + Vector2(float((index - COLS * ROWS) % COLS) * CELL, 0)
	var frame := ColorRect.new()
	frame.color = Color(0.3, 0.3, 0.36)
	frame.position = pos
	frame.size = Vector2(CELL - 2, CELL - 2)
	_root.add_child(frame)
	var btn := Button.new()
	btn.flat = true
	btn.position = pos + Vector2(1, 1)
	btn.size = Vector2(CELL - 4, CELL - 4)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_cell_pressed.bind(index))
	_root.add_child(btn)
	var icon := TextureRect.new()
	icon.position = Vector2.ZERO
	icon.size = Vector2(ICON - 4, ICON - 4)
	icon.stretch_mode = TextureRect.STRETCH_KEEP
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)
	return {"frame": frame, "icon": icon, "button": btn, "index": index}

func _label(pos: Vector2, col: Color, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(l)
	return l

# ------------------------------------------------------------------ open ----
func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	Inventory.screen_open = true
	_refresh()

func close() -> void:
	visible = false
	Inventory.screen_open = false

# ----------------------------------------------------------------- input ----
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("interact"):
		_act()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dodge"):
		if selected < COLS * ROWS:
			Inventory.drop_index(selected)
			selected = mini(selected, _bag_size() - 1)
			selected = maxi(0, selected)
			_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_left"):
		_move(-1, 0); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_right"):
		_move(1, 0); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_up"):
		_move(0, -1); get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_down"):
		_move(0, 1); get_viewport().set_input_as_handled()

func _move(dx: int, dy: int) -> void:
	var row := selected / COLS
	var col := selected % COLS
	col = clampi(col + dx, 0, COLS - 1)
	row = clampi(row + dy, 0, ROWS)   # row == ROWS is the worn strip
	selected = row * COLS + col
	_refresh()

func _on_cell_pressed(index: int) -> void:
	if selected == index:
		_act()
	else:
		selected = index
		_refresh()

func _bag_size() -> int:
	return Inventory.bag.size()

func _act() -> void:
	if selected < COLS * ROWS:
		if Inventory.equip_index(selected):
			selected = mini(selected, maxi(0, _bag_size() - 1))
	else:
		var slot: String = ArtIndex.EQUIPMENT_SLOTS[selected - COLS * ROWS]
		Inventory.unequip_slot(slot)
	_refresh()

# ---------------------------------------------------------------- refresh ---
func _refresh() -> void:
	_refresh_cells()
	_refresh_text()

func _entry_at(index: int):
	if index < COLS * ROWS:
		return Inventory.bag[index] if index < Inventory.bag.size() else null
	var slot: String = ArtIndex.EQUIPMENT_SLOTS[index - COLS * ROWS]
	var e = Inventory.equipped.get(slot, "")
	return e if e is Dictionary else null

func _refresh_cells() -> void:
	for cell in _cells:
		var index: int = cell["index"]
		var entry = _entry_at(index)
		var icon: TextureRect = cell["icon"]
		var frame: ColorRect = cell["frame"]
		if entry is Dictionary:
			icon.texture = _icon_texture(entry["id"])
			frame.color = ItemGen.rarity_color(entry)
		else:
			icon.texture = null
			frame.color = Color(0.22, 0.22, 0.27)
		if index == selected:
			frame.color = Color(1, 0.9, 0.3)

func _icon_texture(item_id: String) -> Texture:
	if not ArtIndex.ICON_INDEX.has(item_id):
		return null
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/items/equipment_icons.png")
	var idx: int = ArtIndex.ICON_INDEX[item_id]
	at.region = Rect2(Vector2(idx % 8, idx / 8) * 16.0, Vector2(16, 16))
	return at

func _refresh_text() -> void:
	_title.text = I18N.tr_str("inv.title")
	_worn_label.text = I18N.tr_str("inv.equipped")
	_weight.text = "%s: %s/%s" % [
		I18N.tr_str("inv.weight"), I18N.num(Inventory.total_weight()), I18N.num(ItemDB.CARRY_LIMIT)]
	_hint.text = I18N.tr_str("inv.hint")

	var entry = _entry_at(selected)
	if entry is Dictionary:
		_tip_icon.texture = _icon_texture(entry["id"])
		_tip_name.text = ItemGen.name_of(entry)
		_tip_name.add_theme_color_override("font_color", ItemGen.rarity_color(entry))
		_tip_rarity.text = ItemGen.rarity_name(entry)
		_tip_rarity.add_theme_color_override("font_color", ItemGen.rarity_color(entry))
		_tip_slot.text = I18N.tr_str("gear.slot." + entry["slot"])
		var lines := []
		if int(entry["dmg"]) > 0:
			lines.append("%s: %s" % [I18N.tr_str("inv.damage"), I18N.num(int(entry["dmg"]))])
		if int(entry["armor"]) > 0:
			lines.append("%s: %s" % [I18N.tr_str("inv.armor"), I18N.num(int(entry["armor"]))])
		lines.append("%s: %s" % [I18N.tr_str("inv.weight"), I18N.num(int(entry["weight"]))])
		lines.append("%s" % (I18N.tr_str("inv.equip") if selected < COLS * ROWS else I18N.tr_str("inv.unequip")))
		_tip_stats.text = "  ".join(lines)
	else:
		_tip_icon.texture = null
		_tip_name.text = I18N.tr_str("inv.empty")
		_tip_name.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		_tip_rarity.text = ""
		_tip_slot.text = ""
		_tip_stats.text = ""
	for l: Label in [_title, _worn_label, _weight, _hint, _tip_name, _tip_rarity, _tip_slot, _tip_stats]:
		I18N.tag(l)
