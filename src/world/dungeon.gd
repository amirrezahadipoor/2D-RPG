# Dungeons: room-and-corridor depths under the caves. Dark by design - the
# hero's lantern and wall torches are the only light. The last depth (6)
# ends in the dragon boss; demon guards sit deeper on the way down.
class_name Dungeon
extends Node2D

const TILE := 16
const W := 72
const H := 54
const MAX_DEPTH := 6
const SPAWN_CAP := 6
const DEPTH_TYPES := ["wolf", "skeleton", "orc", "golem", "demon", "demon"]

var depth := 1
var terrain_layer: TileMapLayer
var shade_layer: TileMapLayer
var actors: Node2D
var hero: Hero = null
var rooms: Array = []
var stairs_up := Vector2.ZERO
var stairs_down := Vector2.ZERO
var boss: Enemy = null
var _stairs_down_node: Stairs = null

var _grid: PackedByteArray = PackedByteArray()
var _lights: Array = []
var _dark: CanvasModulate = null   # legacy handle kept null; tint lives on layers
var props_layer: TileMapLayer
var torch_cells: Array = []
var bone_cells: Array = []
var _spawn_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _seed := 0
var secret_walls: Array = []   # Vector2i cracked-wall tiles
var edge_painter: EdgePainter
var secret_rooms: Array = []   # Rect2i hidden chambers

signal secret_opened()

func is_dungeon() -> bool:
	return true

func ambient_light_need() -> float:
	return 0.9

func build(depth_value: int, seed_value: int) -> void:
	depth = depth_value
	_seed = seed_value
	_rng.seed = seed_value ^ (depth * 7919)
	_grid.resize(W * H)
	_gen_rooms()
	_build_tileset_and_layer()
	_build_props_layer()
	_paint()
	# depth mood: the tile layers themselves carry the tint, so actors and
	# lantern light stay readable on top of it (Phase A5)
	apply_quality()
	Settings.settings_changed.connect(apply_quality)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	_place_entities()
	print("[Dungeon] depth=%d rooms=%d" % [depth, rooms.size()])

# ------------------------------------------------------------- generate -----
## Low quality keeps dungeons readable with a lighter dim and no torch glows.
## Phase A5: every depth owns a mood — mossy brown, cold blue, hellish red.
func _depth_tint() -> Color:
	match depth:
		2: return Color(0.17, 0.20, 0.28)
		3: return Color(0.27, 0.15, 0.17)
		_: return Color(0.20, 0.19, 0.25)

func apply_quality() -> void:
	var tint := _depth_tint()
	if Settings.quality != "high":
		tint = tint.lerp(Color(0.62, 0.60, 0.66), 0.65)
	for layer in [terrain_layer, props_layer, shade_layer, edge_painter]:
		if layer != null:
			layer.modulate = tint
	for entry in _lights:
		entry["light"].visible = Settings.quality == "high"

func _gen_rooms() -> void:
	var target := 6 + depth
	var tries := 0
	while rooms.size() < target and tries < 400:
		tries += 1
		var rw := _rng.randi_range(6, 12)
		var rh := _rng.randi_range(5, 9)
		var rect := Rect2i(_rng.randi_range(2, W - rw - 3), _rng.randi_range(2, H - rh - 3), rw, rh)
		var ok := true
		for other in rooms:
			if rect.grow(2).intersects(other):
				ok = false
				break
		if ok and secret_rooms.size() < 2:
			for other in secret_rooms:
				if rect.grow(2).intersects(other):
					ok = false
					break
		if ok:
			rooms.append(rect)
	# room floors first, then corridors chain the rooms in order
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_grid[y * W + x] = 1
	for i in range(1, rooms.size()):
		_carve_corridor(_center(rooms[i - 1]), _center(rooms[i]))
	# hidden chambers go wherever the rock ring is still untouched
	var order: Array = range(0, rooms.size())
	for i in range(order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = order[i]
		order[i] = order[j]
		order[j] = tmp
	for ri in order:
		if secret_rooms.size() >= 2:
			break
		_try_secret_twin(rooms[ri])

## Hidden chambers: a sealed room reserved right next to its host while the
## map is still being placed, joined by a single cracked wall row. Corridors
## are carved afterwards, so any chamber a corridor nicked is dropped.
func _try_secret_twin(r: Rect2i) -> void:
	if rooms.size() < 2 or secret_rooms.size() >= 2:
		return
	var ch_w := clampi(r.size.x - 2, 4, 8)
	var ch_h := clampi(r.size.y - 2, 3, 5)
	var cx := clampi(r.position.x + 1, 1, W - ch_w - 2)
	var options := []
	if r.position.y - ch_h - 1 >= 1:
		options.append(Rect2i(cx, r.position.y - ch_h - 1, ch_w, ch_h))
	if r.end.y + ch_h + 1 < H - 1:
		options.append(Rect2i(cx, r.end.y + 1, ch_w, ch_h))
	for chamber in options:
		# every tile of the chamber AND its one-tile ring must still be raw
		# rock: the ring is what seals it (the host-side ring row is exactly
		# the single cracked wall row)
		var clear := true
		for y in range(chamber.position.y - 1, chamber.end.y + 1):
			for x in range(chamber.position.x - 1, chamber.end.x + 1):
				if y < 0 or y >= H or x < 0 or x >= W or _grid[y * W + x] != 0:
					clear = false
		if not clear:
			continue
		for y in range(chamber.position.y, chamber.end.y):
			for x in range(chamber.position.x, chamber.end.x):
				_grid[y * W + x] = 1
		secret_rooms.append(chamber)
		var wall_row := r.position.y - 1 if chamber.position.y < r.position.y else r.end.y
		secret_walls.append(Vector2i(cx + ch_w / 2, wall_row))
		return

func open_secret(tile: Vector2i) -> void:
	if tile.x < 0 or tile.y < 0 or tile.x >= W or tile.y >= H:
		return
	_grid[tile.y * W + tile.x] = 1
	var idx: int = ArtIndex.TERRAIN_INDEX["stone"]
	terrain_layer.set_cell(tile, 0, Vector2i(idx % 8, idx / 8))
	secret_opened.emit()

func _center(r: Rect2i) -> Vector2i:
	return r.position + r.size / 2

func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	var y := a.y
	while x != b.x or y != b.y:
		for dy in range(0, 2):
			for dx in range(0, 2):
				var t := Vector2i(x + dx, y + dy)
				if t.x >= 0 and t.y >= 0 and t.x < W and t.y < H:
					_grid[t.y * W + t.x] = 1
		if x != b.x:
			x += signi(b.x - x)
		elif y != b.y:
			y += signi(b.y - y)

# ---------------------------------------------------------------- paint -----
func _build_tileset_and_layer() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/sprites/tiles/terrain.png")
	src.texture_region_size = Vector2i(TILE, TILE)
	for i in ArtIndex.TERRAIN_INDEX.size():
		src.create_tile(Vector2i(i % 8, i / 8))
	ts.add_source(src, 0)
	# walls are solid
	var td: TileData = src.get_tile_data(Vector2i(ArtIndex.TERRAIN_INDEX["cave"] % 8, ArtIndex.TERRAIN_INDEX["cave"] / 8), 0)
	if td:
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	terrain_layer = TileMapLayer.new()
	terrain_layer.name = "Terrain"
	terrain_layer.tile_set = ts
	terrain_layer.collision_enabled = true
	add_child(terrain_layer)
	shade_layer = TileMapLayer.new()
	shade_layer.name = "Shade"
	shade_layer.tile_set = ts
	shade_layer.collision_enabled = false
	shade_layer.modulate = Color(1, 1, 1, 0.35)
	add_child(shade_layer)
	edge_painter = EdgePainter.new()
	edge_painter.name = "WallRims"
	add_child(edge_painter)

func _paint() -> void:
	for y in H:
		for x in W:
			var floor_here := _grid[y * W + x] == 1
			var idx: int
			if floor_here:
				idx = ArtIndex.TERRAIN_INDEX["stone" if (x + y) % 7 != 0 else "cobble"]
			else:
				idx = ArtIndex.TERRAIN_INDEX["cave" if (x * 3 + y) % 5 != 0 else "stone"]
			terrain_layer.set_cell(Vector2i(x, y), 0, Vector2i(idx % 8, idx / 8))
	# contact shade where a wall looms over floor sells the depth
	var shade_atlas := Vector2i(ArtIndex.TERRAIN_INDEX["shade"] % 8,
		ArtIndex.TERRAIN_INDEX["shade"] / 8)
	for y in H:
		for x in W:
			if _grid[y * W + x] == 1 and y > 0 and _grid[(y - 1) * W + x] == 0:
				shade_layer.set_cell(Vector2i(x, y), 0, shade_atlas)
	_paint_edges()
	_scatter_dungeon_props()

func is_walkable_at(world_pos: Vector2) -> bool:
	var t := Vector2i(floori(world_pos.x / float(TILE)), floori(world_pos.y / float(TILE)))
	if t.x < 0 or t.y < 0 or t.x >= W or t.y >= H:
		return false
	return _grid[t.y * W + t.x] == 1

func biome_at(_world_pos: Vector2) -> String:
	return "caves"

func tile_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(TILE)), floori(world_pos.y / float(TILE)))

# ------------------------------------------------------------- entities -----
func _place_entities() -> void:
	var glow := load("res://assets/sprites/fx/glow.png")
	var up_room: Rect2i = rooms[0]
	var last_room: Rect2i = rooms[rooms.size() - 1]
	stairs_up = _pos_of(_center(up_room))
	var boss_types := {1: "ghoul_king", 2: "frost_warden", 3: "dragon"}
	if depth < MAX_DEPTH:
		stairs_down = _pos_of(_center(last_room)) + Vector2(0, 28.0)
		var down := Stairs.new()
		down.direction = 1
		down.locked = true
		_stairs_down_node = down
		actors.add_child(down)
		down.global_position = stairs_down
	boss = Enemy.new()
	actors.add_child(boss)
	boss.setup(boss_types.get(depth, "dragon"), Stats.level + depth)
		# the boss is spawned here, NOT by _dungeon_spawn(), so it used to miss
	# the died hook entirely: no XP/kill/quest progress for slaying the
	# dragon at the bottom of the world
	boss.died.connect(_on_enemy_died)
	boss.global_position = _pos_of(_center(last_room))
	var up := Stairs.new()
	up.direction = -1
	actors.add_child(up)
	up.global_position = stairs_up

	# cracked walls + the treasure they hide
	for i in secret_walls.size():
		var sw := SecretWall.new()
		actors.add_child(sw)
		sw.tile = secret_walls[i]
		sw.global_position = _pos_of(secret_walls[i])
		sw.broken.connect(open_secret)
		var ch: Rect2i = secret_rooms[i]
		var chest := Chest.new()
		chest.secret = true
		actors.add_child(chest)
		chest.global_position = _pos_of(_center(ch))

	# torches on room edges + chests inside rooms
	for i in rooms.size():
		var r: Rect2i = rooms[i]
		for k in range(0, r.size.x, 4):
			var tp := Vector2((r.position.x + k) * TILE + 8, r.position.y * TILE + 8)
			var light := PointLight2D.new()
			light.texture = glow
			light.color = Color(1.0, 0.7, 0.35)
			light.scale = Vector2(2.2, 2.2)
			light.energy = 0.75
			add_child(light)
			light.global_position = tp
			var flame := Sprite2D.new()
			flame.texture = load("res://assets/sprites/fx/flame.png")
			flame.hframes = 2
			flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(flame)
			flame.global_position = tp + Vector2(0, -4)
			_lights.append({"light": light, "phase": randf() * TAU, "flame": flame})
		if i > 0 and i % 2 == 0:
			var chest := Chest.new()
			actors.add_child(chest)
			chest.global_position = _pos_of(Vector2i(r.position.x + 2, r.position.y + r.size.y - 2))

func _pos_of(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + 8.0, t.y * TILE + 8.0)

# ---------------------------------------------------------------- loop ------
func _process(delta: float) -> void:
	_update_boss_bar()
	for entry in _lights:
		entry["phase"] += delta
		entry["light"].energy = 0.7 + 0.15 * sin(entry["phase"] * 8.0)
		entry["flame"].frame = int(entry["phase"] * 8.0) % 2
	_dungeon_spawn(delta)

## Phase C1: a boss health bar while the king of the depth still breathes.
func _update_boss_bar() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("set_boss"):
		return
	if boss == null or not is_instance_valid(boss) or boss.state == boss.State.DEAD:
		hud.set_boss("", 0.0, false)
		return
	var hero := get_tree().get_first_node_in_group("player")
	var near: bool = hero != null and (hero.global_position - boss.global_position).length() < 220.0
	hud.set_boss(I18N.tr_str("enemy." + boss.enemy_type), float(boss.hp) / float(boss.max_hp), near)

func _on_boss_down() -> void:
	if _stairs_down_node != null and is_instance_valid(_stairs_down_node):
		_stairs_down_node.set_locked(false)
	if boss != null:
		# R1.2: the world remembers - town NPCs get one rumor line about this
		# the next time they are talked to (see dialogue.gd _maybe_rumor_page)
		Game.report_boss_defeated(boss.enemy_type)
	if not is_inside_tree():
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.show_toast(I18N.tr_str("toast.boss_down"))

func _dungeon_spawn(delta: float) -> void:
	if Game.state != Game.State.PLAYING or hero == null:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = 1.0
	var live := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if node.get_parent() == actors:
			live += 1
	if live >= SPAWN_CAP:
		return
	for i in 10:
		var r: Rect2i = rooms[_rng.randi_range(0, rooms.size() - 1)]
		var t := Vector2i(_rng.randi_range(r.position.x, r.end.x - 1), _rng.randi_range(r.position.y, r.end.y - 1))
		var pos := _pos_of(t)
		if pos.distance_to(hero.global_position) < 90.0:
			continue
		var enemy := Enemy.new()
		actors.add_child(enemy)
		var type: String = DEPTH_TYPES[clampi(depth - 1, 0, DEPTH_TYPES.size() - 1)]
		enemy.setup(type, maxi(1, Stats.level + depth - 1))
		if _rng.randf() < 0.1:
			enemy.mark_elite()
		enemy.global_position = pos
		enemy.died.connect(_on_enemy_died)
		return

func _on_enemy_died(enemy: Enemy) -> void:
	if enemy == boss:
		_on_boss_down()
	Stats.add_kill()
	QuestLog.on_kill(enemy.enemy_type, "caves")

## Readability pass (Phase 3.5): faint floor checker so tiles read as tiles,
## and a warm rim on every wall face that looks at floor (lantern catch).
func _build_props_layer() -> void:
	props_layer = TileMapLayer.new()
	props_layer.name = "Props"
	var pset := TileSet.new()
	pset.tile_size = Vector2i(16, 16)
	var psrc := TileSetAtlasSource.new()
	psrc.texture = load("res://assets/sprites/tiles/props.png")
	psrc.texture_region_size = Vector2i(16, 16)
	for i in ArtIndex.PROP_INDEX.size():
		psrc.create_tile(Vector2i(i % 8, i / 8))
	pset.add_source(psrc)
	props_layer.tile_set = pset
	props_layer.y_sort_enabled = true
	add_child(props_layer)

## Wall torches with real glow, bone piles and cracks: the floor tells
## stories even before the first skeleton rounds the corner (Phase A5).
func _scatter_dungeon_props() -> void:
	torch_cells.clear()
	bone_cells.clear()
	var torch_at := Vector2i(ArtIndex.PROP_INDEX["torch"] % 8, ArtIndex.PROP_INDEX["torch"] / 8)
	var bones_at := Vector2i(ArtIndex.PROP_INDEX["bones"] % 8, ArtIndex.PROP_INDEX["bones"] / 8)
	var crack_at := Vector2i(ArtIndex.PROP_INDEX["crack"] % 8, ArtIndex.PROP_INDEX["crack"] / 8)
	for y in H:
		for x in W:
			var i := y * W + x
			if _grid[i] == 1:
				var r := _rng.randf()
				if r < 0.025:
					props_layer.set_cell(Vector2i(x, y), 0, bones_at)
					bone_cells.append(Vector2i(x, y))
				elif r < 0.07:
					props_layer.set_cell(Vector2i(x, y), 0, crack_at)
				continue
			if y + 1 < H and _grid[(y + 1) * W + x] == 1 and _rng.randf() < 0.12:
				props_layer.set_cell(Vector2i(x, y), 0, torch_at)
				torch_cells.append(Vector2i(x, y))
				if _lights.size() < 10 and Settings.quality == "high":
					var tp := Vector2(x * 16.0 + 8.0, y * 16.0 + 8.0)
					var light := PointLight2D.new()
					light.texture = load("res://assets/sprites/fx/glow.png")
					light.color = Color(1.0, 0.72, 0.35)
					light.energy = 0.8
					light.scale = Vector2(1.6, 1.6)
					add_child(light)
					light.global_position = tp
					var flame := Sprite2D.new()
					flame.texture = load("res://assets/sprites/fx/flame.png")
					flame.hframes = 2
					flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					add_child(flame)
					flame.global_position = tp + Vector2(0, -4)
					_lights.append({"light": light, "phase": _rng.randf() * TAU, "flame": flame})

func _paint_edges() -> void:
	edge_painter.edges.clear()
	for y in H:
		for x in W:
			var p := Vector2(x * 16.0, y * 16.0)
			if _grid[y * W + x] == 1:
				if (x + y) % 2 == 0:
					edge_painter.edges.append([Rect2(p, Vector2(16, 16)), Color(0, 0, 0, 0.07)])
				continue
			if y + 1 < H and _grid[(y + 1) * W + x] == 1:
				edge_painter.edges.append([Rect2(p + Vector2(0, 14), Vector2(16, 2)), Color(1, 0.85, 0.6, 0.12)])
			if x + 1 < W and _grid[y * W + x + 1] == 1:
				edge_painter.edges.append([Rect2(p + Vector2(14, 0), Vector2(2, 16)), Color(1, 0.85, 0.6, 0.08)])
			if x > 0 and _grid[y * W + x - 1] == 1:
				edge_painter.edges.append([Rect2(p, Vector2(2, 16)), Color(1, 0.85, 0.6, 0.08)])
	edge_painter.rebuild()
