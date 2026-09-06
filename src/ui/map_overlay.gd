# Overworld map: a baked 240x160 render of the whole realm (biomes + roads)
# with the hero, every settlement, the cave mouth and the current objective.
# Opens over the frozen world; tapping a settlement fast-travels the hero
# there, tapping empty map closes it. Built for touch first.
class_name MapOverlay
extends CanvasLayer

signal travel_requested(settlement_index: int)

const MAP_PX := Vector2(240, 160)
const PANEL_POS := Vector2(120, 55)

var world: Overworld = null
var _root: Control
var _map_tex: TextureRect
var _hero_dot: ColorRect
var _obj_dot: ColorRect
var _markers: Array = []      # [sett_index, ColorRect]
var _baked_seed := -1
var _title: Label
var _hint: Label

func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false

func _build() -> void:
	_root = Control.new()
	_root.name = "MapRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_tap)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var border := ColorRect.new()
	border.color = Color(0.5, 0.42, 0.28)
	border.position = PANEL_POS - Vector2(2, 2)
	border.size = MAP_PX + Vector2(4, 4)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(border)

	_map_tex = TextureRect.new()
	_map_tex.position = PANEL_POS
	_map_tex.size = MAP_PX
	_map_tex.stretch_mode = TextureRect.STRETCH_KEEP
	_map_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_map_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_map_tex)

	_title = _label(Vector2(0, 6), Color(1, 0.86, 0.4), 12)
	_hint = _label(Vector2(0, 244), Color(0.62, 0.64, 0.72), 8)

	_hero_dot = _dot(Color(1, 0.92, 0.55), 4)
	_obj_dot = _dot(Color(1, 0.6, 0.2), 5)

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
	_root.add_child(d)
	return d

func show_map(w: Overworld) -> void:
	world = w
	_bake_if_needed()
	_title.text = I18N.tr_str("map.title")
	_hint.text = I18N.tr_str("map.hint")
	I18N.tag(_title)
	I18N.tag(_hint)
	_place_markers()
	visible = true

func hide_map() -> void:
	visible = false

## Map pixel for a world pixel: the map is 240x160 over a 384x256-tile world,
## so one map pixel is 25.6 world px in both axes.
func _to_map(world_pos: Vector2) -> Vector2:
	return Vector2(world_pos.x / 25.6, world_pos.y / 25.6) + PANEL_POS

func _to_world(map_pos: Vector2) -> Vector2:
	var p := map_pos - PANEL_POS
	return Vector2(p.x * 25.6, p.y * 25.6)

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
	var img := Image.create(int(MAP_PX.x), int(MAP_PX.y), false, Image.FORMAT_RGB8)
	for y in int(MAP_PX.y):
		for x in int(MAP_PX.x):
			var t := Vector2i(int(x * 25.6 / 16.0), int(y * 25.6 / 16.0))
			t.x = clampi(t.x, 0, Overworld.WORLD_W - 1)
			t.y = clampi(t.y, 0, Overworld.WORLD_H - 1)
			var biome := world._biome_grid[t.y * Overworld.WORLD_W + t.x]
			var col: Color = BIOME_COLORS.get(biome, Color(0.3, 0.3, 0.3))
			if world._road_grid[t.y * Overworld.WORLD_W + t.x] == 1 \
					and biome not in ["village", "town"]:
				col = ROAD_COLOR
			img.set_pixel(x, y, col)
	_map_tex.texture = ImageTexture.create_from_image(img)

# ------------------------------------------------------------ markers -------
func _place_markers() -> void:
	if world == null:
		return
	# hero
	var hp := _to_map(world.hero.global_position)
	_hero_dot.position = hp - _hero_dot.size / 2.0
	# settlements + cave mouth
	for m in _markers:
		if is_instance_valid(m[1]):
			m[1].free()
	_markers.clear()
	for st in world.settlements:
		var col := Color(0.95, 0.85, 0.45) if st["type"] == "town" else Color(0.9, 0.8, 0.6)
		var d := _dot(col, 3 if st["type"] == "village" else 5)
		var plaza := Vector2(st["plaza"].x * 16.0 + 8.0, st["plaza"].y * 16.0 + 8.0)
		d.position = _to_map(plaza) - d.size / 2.0
		_markers.append([int(st["index"]), d])
	# cave mouth
	var cave := world.find_child("CaveEntrance", true, false)
	if cave != null:
		var cd := _dot(Color(0.6, 0.5, 0.95), 3)
		cd.position = _to_map(cave.global_position) - cd.size / 2.0
		_markers.append([-1, cd])
	# current objective (a place worth going to right now)
	var obj := _objective_world_pos()
	if obj.x >= 0.0:
		_obj_dot.position = _to_map(obj) - _obj_dot.size / 2.0
		_obj_dot.visible = true
	else:
		_obj_dot.visible = false

## Where the player should head right now: a ready turn-in, a talk target, a
## deliver target - otherwise nowhere (the map still shows settlements).
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
			return _settlement_pos(int(m.get("settlement", 0)))
	return Vector2(-1, -1)

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

# ------------------------------------------------------------- tapping ------
var _tap_frame := -1

func _on_tap(event: InputEvent) -> void:
	if not visible:
		return
	var pressed := false
	var p := Vector2.ZERO
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		p = mb.position
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		pressed = st.pressed
		p = st.position
	if not pressed:
		return
	if Engine.get_process_frames() == _tap_frame:
		return
	_tap_frame = Engine.get_process_frames()
	var panel := Rect2(PANEL_POS, MAP_PX)
	if not panel.has_point(p):
		# tapped the dark outside: dismiss
		close_request()
		return
	# inside the map: did we hit a settlement? travel there, else dismiss
	for m in _markers:
		if int(m[0]) >= 0 and is_instance_valid(m[1]):
			var r: Rect2 = (m[1] as ColorRect).get_global_rect()
			if r.grow(3.0).has_point(p):
				travel_requested.emit(int(m[0]))
				return
	close_request()

## Ask Main to hide us (used from the empty-map tap).
func close_request() -> void:
	for child in get_tree().root.get_children():
		if child.has_method("close_map") and child.name == "Main":
			child.close_map()
			return
	hide_map()
