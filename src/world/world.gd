# Procedural overworld.
#
# Renders an actual tilemap (the previous revision generated biome data into
# arrays and never drew a single pixel). Biomes come from coherent
# FastNoiseLite fields -- not per-tile randf(), which produced TV static.
class_name Overworld
extends Node2D

signal biome_changed(biome: String)

const TILE := 16
const WORLD_W := 96
const WORLD_H := 64

const SOLID_PROPS := {"tree": Rect2(0, 10, 16, 6), "rock": Rect2(0, 6, 16, 10)}

var terrain_layer: TileMapLayer
var props_layer: TileMapLayer
var actors: Node2D
var hero: Hero
var spawner: Spawner

var _biome_grid: PackedStringArray = PackedStringArray()
var _current_biome := ""
var world_seed: int = 0

func _ready() -> void:
	build(randi())

# ---------------------------------------------------------------- build -----
func build(seed_value: int) -> void:
	world_seed = seed_value
	_generate_biomes()
	_build_tileset_and_layers()
	_paint()
	_spawn_actors_root()
	_spawn_hero()
	_spawn_spawner()
	_place_chests()
	Juice.register_camera(hero.cam)
	Juice.register_world(actors)
	print("[World] seed=%d size=%dx%d" % [world_seed, WORLD_W, WORLD_H])

func _generate_biomes() -> void:
	var elev := FastNoiseLite.new()
	elev.seed = world_seed
	elev.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elev.frequency = 0.022

	var temp := FastNoiseLite.new()
	temp.seed = world_seed + 101
	temp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	temp.frequency = 0.016

	var moist := FastNoiseLite.new()
	moist.seed = world_seed + 202
	moist.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moist.frequency = 0.03

	_biome_grid.resize(WORLD_W * WORLD_H)
	for y in range(WORLD_H):
		for x in range(WORLD_W):
			var e := elev.get_noise_2d(float(x), float(y))
			var t := temp.get_noise_2d(float(x), float(y))
			var m := moist.get_noise_2d(float(x), float(y))
			var biome: String
			if e < -0.42:
				biome = "water"
			elif t < -0.32:
				biome = "snow"
			elif t > 0.42:
				biome = "desert"
			elif e > 0.52:
				biome = "caves"
			elif m > 0.28:
				biome = "swamp"
			else:
				biome = "forest"
			_biome_grid[y * WORLD_W + x] = biome

func _terrain_tile(biome: String, x: int, y: int) -> int:
	var alt := ((x * 7 + y * 13) % 5) == 0
	match biome:
		"water": return ArtIndex.TERRAIN_INDEX["water"]
		"snow": return ArtIndex.TERRAIN_INDEX["snow"]
		"desert": return ArtIndex.TERRAIN_INDEX["sand2" if alt else "sand"]
		"caves": return ArtIndex.TERRAIN_INDEX["cave" if alt else "stone"]
		"swamp": return ArtIndex.TERRAIN_INDEX["swamp"]
		"forest": return ArtIndex.TERRAIN_INDEX["grass2" if alt else "grass"]
	return ArtIndex.TERRAIN_INDEX["grass"]

func _prop_at(biome: String, x: int, y: int) -> String:
	var h := _hash2(x, y)
	match biome:
		"forest":
			if h < 0.075: return "tree"
			if h < 0.10: return "bush"
			if h < 0.12: return "flower"
		"snow":
			if h < 0.03: return "tree"
			if h < 0.05: return "rock"
		"desert":
			if h < 0.035: return "rock"
			if h < 0.045: return "sign"
		"caves":
			if h < 0.06: return "rock"
			if h < 0.075: return "torch"
		"swamp":
			if h < 0.05: return "bush"
			if h < 0.07: return "tree"
	return ""

func _hash2(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263 + world_seed * 69069) & 0x7FFFFFFF
	n = (n ^ (n >> 13)) * 1274126177 & 0x7FFFFFFF
	return float(n & 0xFFFF) / 65535.0

# -------------------------------------------------------------- tileset -----
func _build_tileset_and_layers() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()

	var src_terrain := TileSetAtlasSource.new()
	src_terrain.texture = load("res://assets/sprites/tiles/terrain.png")
	src_terrain.texture_region_size = Vector2i(TILE, TILE)
	for i in ArtIndex.TERRAIN_INDEX.size():
		src_terrain.create_tile(Vector2i(i % 8, i / 8))
	ts.add_source(src_terrain, 0)

	var src_props := TileSetAtlasSource.new()
	src_props.texture = load("res://assets/sprites/tiles/props.png")
	src_props.texture_region_size = Vector2i(TILE, TILE)
	for i in ArtIndex.PROP_INDEX.size():
		src_props.create_tile(Vector2i(i, 0))
	ts.add_source(src_props, 1)

	# water blocks movement
	_set_solid(src_terrain, ArtIndex.TERRAIN_INDEX["water"], Rect2(0, 0, TILE, TILE))
	# props block only their lower band, so you can walk "behind" a canopy
	for prop_name in SOLID_PROPS:
		_set_solid(src_props, ArtIndex.PROP_INDEX[prop_name], SOLID_PROPS[prop_name])

	terrain_layer = TileMapLayer.new()
	terrain_layer.name = "Terrain"
	terrain_layer.tile_set = ts
	terrain_layer.collision_enabled = true
	add_child(terrain_layer)

	props_layer = TileMapLayer.new()
	props_layer.name = "Props"
	props_layer.tile_set = ts
	props_layer.collision_enabled = true
	props_layer.y_sort_enabled = true
	add_child(props_layer)

func _set_solid(src: TileSetAtlasSource, tile_index: int, rect: Rect2) -> void:
	var coords := Vector2i(tile_index % 8, tile_index / 8)
	var td: TileData = src.get_tile_data(coords, 0)
	if td == null:
		return
	# NOTE: TileData collision polygons are specified RELATIVE TO THE TILE
	# CENTER, not the top-left corner (verified empirically with a point-probe
	# against the physics space). Forgetting this offsets every collider by
	# half a tile: a silent "walls in the wrong place" bug.
	var half := Vector2(TILE, TILE) * 0.5
	var p0 := rect.position - half
	var p1 := rect.position + rect.size - half
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(p0.x, p0.y),
		Vector2(p1.x, p0.y),
		Vector2(p1.x, p1.y),
		Vector2(p0.x, p1.y),
	]))

# ---------------------------------------------------------------- paint -----
func _paint() -> void:
	for y in range(WORLD_H):
		for x in range(WORLD_W):
			var biome := _biome_grid[y * WORLD_W + x]
			terrain_layer.set_cell(Vector2i(x, y), 0, Vector2i(_terrain_tile(biome, x, y) % 8, _terrain_tile(biome, x, y) / 8))
			var prop := _prop_at(biome, x, y)
			if prop != "":
				var pi: int = ArtIndex.PROP_INDEX[prop]
				props_layer.set_cell(Vector2i(x, y), 1, Vector2i(pi, 0))

## True when an entity can stand here: in bounds, not water, not inside a
## solid prop. Used by the spawner so enemies never appear in a tree.
func is_walkable_at(world_pos: Vector2) -> bool:
	var t := tile_at(world_pos)
	if t.x < 0 or t.y < 0 or t.x >= WORLD_W or t.y >= WORLD_H:
		return false
	var biome := _biome_grid[t.y * WORLD_W + t.x]
	if biome == "water":
		return false
	var prop := _prop_at(biome, t.x, t.y)
	return prop == "" or not SOLID_PROPS.has(prop)

func biome_at(world_pos: Vector2) -> String:
	var t := tile_at(world_pos)
	if t.x < 0 or t.y < 0 or t.x >= WORLD_W or t.y >= WORLD_H:
		return "water"
	return _biome_grid[t.y * WORLD_W + t.x]

func tile_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(TILE)), floori(world_pos.y / float(TILE)))

## Hero + enemies live in one y-sorted container so they draw over/under each
## other by foot position instead of by spawn order.
func _spawn_actors_root() -> void:
	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)

func _spawn_spawner() -> void:
	spawner = Spawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.world = self

## Scatter a handful of chests on walkable ground away from the spawn point.
func _place_chests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x51ED
	var placed := 0
	var tries := 0
	while placed < 10 and tries < 400:
		tries += 1
		var t := Vector2i(rng.randi_range(4, WORLD_W - 5), rng.randi_range(4, WORLD_H - 5))
		var pos := Vector2(t.x * TILE + 8.0, t.y * TILE + 8.0)
		if not is_walkable_at(pos):
			continue
		if pos.distance_to(hero.global_position) < 70.0:
			continue
		var chest := Chest.new()
		chest.name = "Chest_%d" % placed
		actors.add_child(chest)
		chest.global_position = pos
		placed += 1

func _spawn_hero() -> void:
	hero = Hero.new()
	hero.name = "Hero"
	actors.add_child(hero)
	# find a walkable forest-ish tile near the centre
	var cx := WORLD_W / 2
	var cy := WORLD_H / 2
	for radius in range(0, 40):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var t := Vector2i(cx + dx, cy + dy)
				if t.x < 1 or t.y < 1 or t.x >= WORLD_W - 1 or t.y >= WORLD_H - 1:
					continue
				var biome := _biome_grid[t.y * WORLD_W + t.x]
				if biome in ["forest", "desert", "snow", "swamp"] and _prop_at(biome, t.x, t.y) == "":
					hero.global_position = Vector2(t.x * TILE + 8.0, t.y * TILE + 8.0)
					hero.cam.limit_left = 0
					hero.cam.limit_top = 0
					hero.cam.limit_right = WORLD_W * TILE
					hero.cam.limit_bottom = WORLD_H * TILE
					return
	hero.global_position = Vector2(cx * TILE, cy * TILE)

func _process(_delta: float) -> void:
	if hero == null:
		return
	var b := biome_at(hero.global_position)
	if b != _current_biome:
		_current_biome = b
		biome_changed.emit(b)
