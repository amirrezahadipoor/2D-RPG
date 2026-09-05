# Dungeons: room-and-corridor depths under the caves. Dark by design - the
# hero's lantern and wall torches are the only light. Depth 3 ends in a boss.
class_name Dungeon
extends Node2D

const TILE := 16
const W := 72
const H := 54
const MAX_DEPTH := 3
const SPAWN_CAP := 6

var depth := 1
var terrain_layer: TileMapLayer
var actors: Node2D
var hero: Hero = null
var rooms: Array = []
var stairs_up := Vector2.ZERO
var stairs_down := Vector2.ZERO
var boss: Enemy = null

var _grid: PackedByteArray = PackedByteArray()
var _lights: Array = []
var _spawn_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _seed := 0

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
	_paint()
	# darkness: the whole canvas dims while a dungeon is in the tree, so the
	# torches and the hero's lantern are what you actually see by
	var dark := CanvasModulate.new()
	dark.name = "Darkness"
	dark.color = Color(0.2, 0.19, 0.25)
	add_child(dark)
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	_place_entities()
	print("[Dungeon] depth=%d rooms=%d" % [depth, rooms.size()])

# ------------------------------------------------------------- generate -----
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
		if ok:
			rooms.append(rect)
	# corridors chain the rooms in order
	for i in range(1, rooms.size()):
		_carve_corridor(_center(rooms[i - 1]), _center(rooms[i]))
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_grid[y * W + x] = 1

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
	if depth < MAX_DEPTH:
		stairs_down = _pos_of(_center(last_room))
		var down := Stairs.new()
		down.direction = 1
		actors.add_child(down)
		down.global_position = stairs_down
	else:
		var boss_type := "dragon" if depth == MAX_DEPTH else "demon"
		boss = Enemy.new()
		actors.add_child(boss)
		boss.setup(boss_type, Stats.level + depth)
		boss.global_position = _pos_of(_center(last_room))
		stairs_down = Vector2.ZERO
	var up := Stairs.new()
	up.direction = -1
	actors.add_child(up)
	up.global_position = stairs_up

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
			_lights.append({"light": light, "phase": randf() * TAU})
		if i > 0 and i % 2 == 0:
			var chest := Chest.new()
			actors.add_child(chest)
			chest.global_position = _pos_of(Vector2i(r.position.x + 2, r.position.y + r.size.y - 2))

func _pos_of(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + 8.0, t.y * TILE + 8.0)

# ---------------------------------------------------------------- loop ------
func _process(delta: float) -> void:
	for entry in _lights:
		entry["phase"] += delta
		entry["light"].energy = 0.7 + 0.15 * sin(entry["phase"] * 8.0)
	_dungeon_spawn(delta)

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
		var type: String = ["skeleton", "orc", "demon"][clampi(depth - 1, 0, 2)]
		enemy.setup(type, maxi(1, Stats.level + depth - 1))
		enemy.global_position = pos
		enemy.died.connect(_on_enemy_died)
		return

func _on_enemy_died(enemy: Enemy) -> void:
	Stats.add_kill()
	QuestLog.on_kill(enemy.enemy_type, "caves")
