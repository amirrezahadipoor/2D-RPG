# Inventory & equipment screen — touch-native, responsive.
# Big 40px icons (was 32), 44px cells (was 34) for finger targets.
# Panel is centred with SafeArea so not clipped on notched phones.
class_name InventoryScreen
extends CanvasLayer

const COLS := 6
const ROWS := 4
const CELL := 44.0  # was 34 → bigger touch target (BUG small targets)
const ICON := 40.0  # was 32
const BASE_W := 480.0
const BASE_H := 270.0

var selected := 0

var _root: Control
var _cells: Array = []        # dicts: {frame, icon, index}
var _title: Label
var _weight: Label
var _hint: Label
var _worn_label: Label
var _tip_icon: TextureRect
var _tip_name: Label
var _tip_rarity: Label
var _tip_slot: Label
var _tip_stats: Label
var _panel: ColorRect
var _border: ColorRect
var _dim: ColorRect

func _ready() -> void:
	layer = 20
	add_to_group("modal_ui")
	_build()
	visible = false
	Inventory.changed.connect(func(): if visible: _refresh())
	Inventory.equipment_changed.connect(func(): if visible: _refresh())
	I18N.locale_changed.connect(func(_l): if visible: _refresh_text())
	Settings.settings_changed.connect(_layout)

func _build() -> void:
	_root = Control.new()
	_root.name = "InvRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.62)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(func(e):
		if e is InputEventScreenTouch and e.pressed:
			close()
	)
	_root.add_child(_dim)

	_border = ColorRect.new()
	_border.color = Color(0.35, 0.3, 0.22)
	_root.add_child(_border)
	_panel = ColorRect.new()
	_panel.color = Color(0.09, 0.08, 0.12, 0.97)
	_root.add_child(_panel)

	_title = _label(Vector2.ZERO, Color(1, 0.86, 0.4), 12)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for i in COLS * ROWS + COLS:
		var cell := _make_cell(i)
		_cells.append(cell)

	_worn_label = _label(Vector2.ZERO, Color(0.7, 0.72, 0.8), 9)

	_tip_icon = TextureRect.new()
	_tip_icon.size = Vector2(ICON, ICON)
	_tip_icon.stretch_mode = TextureRect.STRETCH_KEEP
	_tip_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_root.add_child(_tip_icon)
	_tip_name = _label(Vector2.ZERO, Color.WHITE, 10)
	_tip_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_rarity = _label(Vector2.ZERO, Color.WHITE, 9)
	_tip_slot = _label(Vector2.ZERO, Color(0.75, 0.78, 0.85), 9)
	_tip_stats = _label(Vector2.ZERO, Color(0.9, 0.92, 1.0), 10)

	_weight = _label(Vector2.ZERO, Color(0.8, 0.8, 0.7), 9)
	_hint = _label(Vector2.ZERO, Color(0.6, 0.62, 0.7), 9)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_layout()

func _layout() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var safe := SafeArea.get_safe_margins(vp)
	var bars := SafeArea.get_bars(vp)
	# panel size responsive: fill safe area minus margins, max 480 width
	var avail_w := BASE_W - safe.x - safe.z - bars.x - bars.y - 16.0
	var avail_h := BASE_H - safe.y - safe.w - 16.0
	var pw := minf(460.0, avail_w)
	var ph := minf(250.0, avail_h)
	var px := safe.x + bars.x + (BASE_W - safe.x - safe.z - bars.x - bars.y - pw) * 0.5
	var py := safe.y + (BASE_H - safe.y - safe.w - ph) * 0.5
	_border.position = Vector2(px - 1, py - 1)
	_border.size = Vector2(pw + 2, ph + 2)
	_panel.position = Vector2(px, py)
	_panel.size = Vector2(pw, ph)
	_dim.position = Vector2.ZERO
	_dim.size = Vector2(BASE_W, BASE_H)

	# layout cells inside panel
	var grid_origin := Vector2(px + 10, py + 28)
	var tip_x := px + pw * 0.55
	# if tablet/wide, keep two columns
	if pw < 380:
		# narrow: stack vertically
		grid_origin = Vector2(px + 10, py + 28)
		tip_x = px + 10
		var tip_y := py + 28 + ROWS * CELL + CELL + 14
		_tip_icon.position = Vector2(tip_x, tip_y)
		_tip_name.position = Vector2(tip_x + ICON + 6, tip_y)
		_tip_name.size = Vector2(pw - ICON - 20, 28)
		_tip_rarity.position = Vector2(tip_x + ICON + 6, tip_y + 20)
		_tip_slot.position = Vector2(tip_x, tip_y + 44)
		_tip_stats.position = Vector2(tip_x, tip_y + 58)
		_tip_stats.size = Vector2(pw - 20, 40)
	else:
		_tip_icon.position = Vector2(tip_x, py + 32)
		_tip_name.position = Vector2(tip_x + ICON + 6, py + 32)
		_tip_name.size = Vector2(px + pw - tip_x - ICON - 16, 28)
		_tip_rarity.position = Vector2(tip_x + ICON + 6, py + 54)
		_tip_slot.position = Vector2(tip_x, py + 74)
		_tip_stats.position = Vector2(tip_x, py + 88)
		_tip_stats.size = Vector2(px + pw - tip_x - 10, 70)

	_title.position = Vector2(px, py + 6)
	_title.size = Vector2(pw, 16)

	for i in _cells.size():
		var cell: Dictionary = _cells[i]
		var pos: Vector2
		if i < COLS * ROWS:
			pos = grid_origin + Vector2(float(i % COLS) * CELL, float(i / COLS) * CELL)
		else:
			pos = grid_origin + Vector2(float((i - COLS * ROWS) % COLS) * CELL, ROWS * CELL + 10)
		(cell["frame"] as ColorRect).position = pos
		(cell["frame"] as ColorRect).size = Vector2(CELL - 2, CELL - 2)
		(cell["button"] as Button).position = pos + Vector2(1,1)
		(cell["button"] as Button).size = Vector2(CELL - 4, CELL - 4)
		if cell.has("icon"):
			(cell["icon"] as TextureRect).position = Vector2.ZERO
			(cell["icon"] as TextureRect).size = Vector2(CELL - 4, CELL - 4)

	_worn_label.position = grid_origin + Vector2(0, ROWS * CELL + 10 - 14)
	_weight.position = Vector2(px + 10, py + ph - 28)
	_hint.position = Vector2(px, py + ph - 14)
	_hint.size = Vector2(pw, 12)

func _make_cell(index: int) -> Dictionary:
	var frame := ColorRect.new()
	frame.color = Color(0.3, 0.3, 0.36)
	_root.add_child(frame)
	var btn := Button.new()
	btn.flat = true
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_cell_pressed.bind(index))
	_root.add_child(btn)
	var icon := TextureRect.new()
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

# ------------------------------------------------------------------ open ---
func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	Inventory.screen_open = true
	_layout()
	_refresh()

func close() -> void:
	visible = false
	Inventory.screen_open = false

# ----------------------------------------------------------------- input ----
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch and event.pressed:
		# tap outside panel closes (touch-native)
		var vp := get_viewport()
		if vp != null:
			var touch_pos: Vector2 = event.position
			# panel rect check
			if not Rect2(_panel.position, _panel.size).has_point(touch_pos):
				close()
				get_viewport().set_input_as_handled()
				return

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
			frame.color = Color(0.15, 0.15, 0.19)
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
