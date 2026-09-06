# Procedural overworld — a whole country, not a garden.
#
# 384x256 tiles (16x the M0 map): 8 biomes incl. graveyards, 4 settlements
# (3 villages + 1 town) with roofed houses, plazas, wells and ring roads,
# cobble roads connecting them, and NPCs that live there on a day schedule.
class_name Overworld
extends Node2D

signal biome_changed(biome: String)

const TILE := 16
const WORLD_W := 384
const WORLD_H := 256

const SOLID_PROPS := {"tree": Rect2(0, 10, 16, 6), "rock": Rect2(0, 6, 16, 10),
	"tomb": Rect2(0, 10, 16, 6), "well": Rect2(0, 9, 16, 7),
	"fence": Rect2(0, 12, 16, 4)}

var terrain_layer: TileMapLayer
var props_layer: TileMapLayer
var shade_layer: TileMapLayer
var decals: Node2D
var _water_cells: Array = []
var _water_phase := 0
var _shimmer_t := 0.0
var actors: Node2D
var hero: Hero
var spawner: Spawner

var settlements: Array = []   # {type, rect: Rect2i, plaza: Vector2i, index}
var npcs: Array = []
var ambient: AmbientFX
var _lights: Array = []       # PointLight2D torches / wisps

var _biome_grid: PackedStringArray = PackedStringArray()
var _road_grid: PackedByteArray = PackedByteArray()
var _current_biome := ""
var world_seed: int = 0

var forced_seed := -1

func _ready() -> void:
	Settings.settings_changed.connect(apply_quality)
	build(forced_seed if forced_seed >= 0 else randi())

# ---------------------------------------------------------------- build -----
func build(seed_value: int) -> void:
	world_seed = seed_value
	_generate_biomes()
	_place_settlements()
	_carve_roads()
	_build_tileset_and_layers()
	_paint()
	_spawn_actors_root()
	_spawn_hero()
	_spawn_spawner()
	_spawn_npcs()
	_place_chests()
	_place_cave_entrance()
	_place_house_doors()
	_paint_shade()
	_collect_water()
	_spawn_decals()
	_place_lights()
	ambient = AmbientFX.new()
	ambient.name = "Ambient"
	add_child(ambient)
	ambient.world = self
	Juice.register_camera(hero.cam)
	apply_quality()

## Quality tiers: low drops contact shadows + torch glows, medium keeps the
## shadows, high adds the point lights that make nights and caves glow.
func apply_quality() -> void:
	if shade_layer != null:
		shade_layer.visible = Settings.quality != "low"
	if decals != null:
		decals.visible = Settings.quality != "low"
	for entry in _lights:
		entry["light"].visible = Settings.quality == "high"
	Juice.register_world(actors)
	print("[World] seed=%d size=%dx%d settlements=%d" % [world_seed, WORLD_W, WORLD_H, settlements.size()])

func _generate_biomes() -> void:
	var elev := FastNoiseLite.new()
	elev.seed = world_seed
	elev.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elev.frequency = 0.012
	var temp := FastNoiseLite.new()
	temp.seed = world_seed + 31
	temp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	temp.frequency = 0.008
	var moist := FastNoiseLite.new()
	moist.seed = world_seed + 77
	moist.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moist.frequency = 0.015
	# graveyards: rare, small, cursed clearings
	var grav := FastNoiseLite.new()
	grav.seed = world_seed + 913
	grav.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	grav.frequency = 0.05

	_biome_grid.resize(WORLD_W * WORLD_H)
	for y in WORLD_H:
		for x in WORLD_W:
			var e := elev.get_noise_2d(x, y)
			var t := temp.get_noise_2d(x, y)
			var m := moist.get_noise_2d(x, y)
			var g := grav.get_noise_2d(x, y)
			var biome := "forest"
			if e < -0.42:
				biome = "water"
			elif e > 0.52:
				biome = "caves"
			elif t < -0.32:
				biome = "snow"
			elif t > 0.42:
				biome = "desert"
			elif m > 0.28:
				biome = "swamp"
			if biome in ["forest", "snow"] and g > 0.62:
				biome = "graveyard"
			_biome_grid[y * WORLD_W + x] = biome
	_road_grid.resize(WORLD_W * WORLD_H)

# ---------------------------------------------------------- settlements -----
func _place_settlements() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0xC17
	var specs := [["town", 26, 18], ["village", 14, 10], ["village", 14, 10], ["village", 14, 10]]
	var tries := 0
	for spec in specs:
		var placed := false
		while not placed and tries < 900:
			tries += 1
			var w: int = spec[1]
			var h: int = spec[2]
			var x0 := rng.randi_range(8, WORLD_W - w - 9)
			var y0 := rng.randi_range(8, WORLD_H - h - 9)
			var rect := Rect2i(x0, y0, w, h)
			# settlements need dry, gentle land and personal space
			var ok := true
			for yy in range(y0, y0 + h, 2):
				for xx in range(x0, x0 + w, 2):
					if _biome_grid[yy * WORLD_W + xx] in ["water", "caves"]:
						ok = false
						break
				if not ok:
					break
			if ok:
				for other in settlements:
					if rect.grow(14).intersects(other["rect"]):
						ok = false
						break
			if not ok:
				continue
			settlements.append({
				"type": spec[0],
				"rect": rect,
				"plaza": Vector2i(x0 + w / 2, y0 + h / 2),
				"index": settlements.size(),
			})
			for yy in range(y0, y0 + h):
				for xx in range(x0, x0 + w):
					_biome_grid[yy * WORLD_W + xx] = spec[0]
			placed = true

func _carve_roads() -> void:
	# L-shaped cobble roads between consecutive settlements
	for i in range(1, settlements.size()):
		var a: Vector2i = settlements[i - 1]["plaza"]
		var b: Vector2i = settlements[i]["plaza"]
		_road_line(a, Vector2i(b.x, a.y))
		_road_line(Vector2i(b.x, a.y), b)

func _road_line(a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	var y := a.y
	while x != b.x or y != b.y:
		for dy in range(0, 2):
			for dx in range(0, 2):
				var t := Vector2i(x + dx, y + dy)
				if t.x >= 0 and t.y >= 0 and t.x < WORLD_W and t.y < WORLD_H:
					if _biome_grid[t.y * WORLD_W + t.x] != "water":
						_road_grid[t.y * WORLD_W + t.x] = 1
		if x != b.x:
			x += signi(b.x - x)
		elif y != b.y:
			y += signi(b.y - y)

# ---------------------------------------------------------------- paint -----
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
		src_props.create_tile(Vector2i(i % 8, i / 8))
	ts.add_source(src_props, 1)

	_set_solid(src_terrain, ArtIndex.TERRAIN_INDEX["water"], Rect2(0, 0, TILE, TILE))
	_set_solid(src_terrain, ArtIndex.TERRAIN_INDEX["roof"], Rect2(0, 0, TILE, TILE))
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
	shade_layer = TileMapLayer.new()
	shade_layer.name = "Shade"
	shade_layer.tile_set = ts
	shade_layer.collision_enabled = false
	shade_layer.modulate = Color(1, 1, 1, 0.32)
	add_child(shade_layer)
	decals = Node2D.new()
	decals.name = "Decals"
	add_child(decals)

func _set_solid(src: TileSetAtlasSource, tile_index: int, rect: Rect2) -> void:
	var coords := Vector2i(tile_index % 8, tile_index / 8)
	var td: TileData = src.get_tile_data(coords, 0)
	if td == null:
		return
	# NOTE: TileData collision polygons are specified RELATIVE TO THE TILE
	# CENTER, not the top-left corner. Forgetting this offsets every collider
	# by half a tile: a silent "walls in the wrong place" bug.
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

func _paint() -> void:
	for y in WORLD_H:
		for x in WORLD_W:
			var i := y * WORLD_W + x
			var biome := _biome_grid[i]
			var tidx := _terrain_tile(biome, x, y)
			var prop := _prop_at(biome, x, y)
			if _road_grid[i] == 1 and biome not in ["village", "town"]:
				tidx = ArtIndex.TERRAIN_INDEX["cobble"]
				prop = ""
			if biome == "village" or biome == "town":
				var st: Dictionary = _settlement_at_tile(Vector2i(x, y))
				var override: Array = _settlement_tile(st, Vector2i(x, y))
				tidx = override[0]
				prop = override[1]
			terrain_layer.set_cell(Vector2i(x, y), 0, Vector2i(tidx % 8, tidx / 8))
			if prop != "":
				props_layer.set_cell(Vector2i(x, y), 1, Vector2i(ArtIndex.PROP_INDEX[prop] % 8, ArtIndex.PROP_INDEX[prop] / 8))

## Contact shadows under anything solid ground the scene: trees, rocks and
## walls stop looking like stickers pasted on the grass.
func _paint_shade() -> void:
	var shade_atlas := Vector2i(ArtIndex.TERRAIN_INDEX["shade"] % 8,
		ArtIndex.TERRAIN_INDEX["shade"] / 8)
	var solid_props := {"tree": 1, "rock": 1, "bush": 1, "tomb": 1,
		"fence": 1, "well": 1, "sign": 1, "chest": 1}
	for cell in props_layer.get_used_cells():
		var atlas: Vector2i = props_layer.get_cell_atlas_coords(cell)
		var name: String = ""
		for key in ArtIndex.PROP_INDEX:
			if ArtIndex.PROP_INDEX[key] == atlas.y * 8 + atlas.x:
				name = key
		if name == "" or not solid_props.has(name):
			continue
		var below := Vector2i(cell.x, cell.y + 1)
		if props_layer.get_cell_atlas_coords(below) == Vector2i(-1, -1):
			shade_layer.set_cell(below, 0, shade_atlas)

func _collect_water() -> void:
	var water := ArtIndex.TERRAIN_INDEX["water"]
	for cell in terrain_layer.get_used_cells():
		var atlas: Vector2i = terrain_layer.get_cell_atlas_coords(cell)
		if atlas.y * 8 + atlas.x == water:
			_water_cells.append(cell)

## Sparse ground dressing per biome: flowers, pebbles, puddles, snow drifts.
func _spawn_decals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0xDECA
	var props_tex := load("res://assets/sprites/tiles/props.png")
	var terrain_tex := load("res://assets/sprites/tiles/terrain.png")
	var placed := 0
	var tries := 0
	while placed < 160 and tries < 4000:
		tries += 1
		var t := Vector2i(rng.randi_range(2, WORLD_W - 3), rng.randi_range(2, WORLD_H - 3))
		var pos := Vector2(t.x * TILE + 8.0, t.y * TILE + 8.0)
		if not is_walkable_at(pos):
			continue
		var biome := biome_at(pos)
		var spr := Sprite2D.new()
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.centered = true
		var at := AtlasTexture.new()
		match biome:
			"forest", "grass", "village", "town":
				at.atlas = props_tex
				at.region = Rect2(Vector2(ArtIndex.PROP_INDEX["flower"] % 8,
					ArtIndex.PROP_INDEX["flower"] / 8) * 16.0, Vector2(16, 16))
				spr.modulate = [Color(1, 1, 1), Color(1, 0.85, 0.9),
					Color(0.9, 0.9, 1), Color(1, 0.95, 0.7)][rng.randi_range(0, 3)]
			"desert", "caves", "graveyard":
				at.atlas = props_tex
				at.region = Rect2(Vector2(ArtIndex.PROP_INDEX["rock"] % 8,
					ArtIndex.PROP_INDEX["rock"] / 8) * 16.0, Vector2(16, 16))
				spr.scale = Vector2(0.35, 0.35)
				spr.modulate = Color(0.8, 0.78, 0.75, 0.8)
			"swamp":
				at.atlas = terrain_tex
				at.region = Rect2(Vector2(ArtIndex.TERRAIN_INDEX["water2"] % 8,
					ArtIndex.TERRAIN_INDEX["water2"] / 8) * 16.0, Vector2(16, 16))
				spr.scale = Vector2(0.6, 0.4)
				spr.modulate = Color(0.7, 0.9, 0.8, 0.5)
			"snow":
				at.atlas = terrain_tex
				at.region = Rect2(Vector2(ArtIndex.TERRAIN_INDEX["snow"] % 8,
					ArtIndex.TERRAIN_INDEX["snow"] / 8) * 16.0, Vector2(16, 16))
				spr.scale = Vector2(0.5, 0.25)
				spr.modulate = Color(1, 1, 1, 0.55)
			_:
				spr.free()
				continue
		spr.texture = at
		spr.global_position = pos + Vector2(rng.randf_range(-6, 6), rng.randf_range(-5, 5))
		decals.add_child(spr)
		placed += 1

func _settlement_at_tile(t: Vector2i) -> Dictionary:
	for st in settlements:
		if st["rect"].has_point(t):
			return st
	return {}

## House/plaza pattern inside a settlement rect. Returns [terrain_idx, prop].
func _settlement_tile(st: Dictionary, t: Vector2i) -> Array:
	var rect: Rect2i = st["rect"]
	var rel := t - rect.position
	var w := rect.size.x
	var h := rect.size.y
	var plaza: Vector2i = st["plaza"]
	# ring road around the plot
	if rel.x == 0 or rel.y == 0 or rel.x == w - 1 or rel.y == h - 1:
		return [ArtIndex.TERRAIN_INDEX["cobble"], ""]
	# houses: roof blocks with a wood "door" tile at the bottom middle
	for hr in _house_rects(st):
		var house: Rect2i = hr
		if house.has_point(t):
			var door_x: int = house.position.x + house.size.x / 2
			if t.y == house.position.y + house.size.y - 1 and t.x == door_x:
				return [ArtIndex.TERRAIN_INDEX["wood"], ""]
			return [ArtIndex.TERRAIN_INDEX["roof"], ""]
	# plaza props
	if t == plaza:
		return [ArtIndex.TERRAIN_INDEX["cobble"], "well"]
	# the free cross around the well is row plaza.y and columns plaza.x..x+1;
	# every furniture offset must stay inside it (audit P0-2: chests and
	# torches used to be painted onto house roofs)
	if t == plaza + Vector2i(1, 0) or t == plaza + Vector2i(-1, 0):
		return [ArtIndex.TERRAIN_INDEX["cobble"], "torch"]
	if t == plaza + Vector2i(0, 2):
		return [ArtIndex.TERRAIN_INDEX["cobble"], "sign"]
	if t == plaza + Vector2i(0, -2):
		return [ArtIndex.TERRAIN_INDEX["cobble"], "chest"]
	if t == rect.position + Vector2i(1, h - 1):
		return [ArtIndex.TERRAIN_INDEX["cobble"], "torch"]
	# grassy yards with flowers
	var hh := _hash2(t.x, t.y)
	if hh > 0.94:
		return [ArtIndex.TERRAIN_INDEX["grass"], "flower"]
	if hh < 0.03:
		return [ArtIndex.TERRAIN_INDEX["grass"], "fence"]
	return [ArtIndex.TERRAIN_INDEX["grass"], ""]

func _house_rects(st: Dictionary) -> Array:
	var rect: Rect2i = st["rect"]
	var houses := []
	if st["type"] == "town":
		# rows hug the top and bottom; the middle band (y6..y11) stays open so
		# the plaza, its furniture and the story spawn never land on a roof
		for hx in [2, 9, 17]:
			for hy in [2, 12]:
				houses.append(Rect2i(rect.position + Vector2i(hx, hy), Vector2i(5, 4)))
	else:
		houses.append(Rect2i(rect.position + Vector2i(2, 2), Vector2i(4, 3)))
		houses.append(Rect2i(rect.position + Vector2i(8, 2), Vector2i(4, 3)))
		houses.append(Rect2i(rect.position + Vector2i(2, 6), Vector2i(4, 3)))
	return houses

func _terrain_tile(biome: String, x: int, y: int) -> int:
	var alt := _hash2(x, y) > 0.5
	match biome:
		"water": return ArtIndex.TERRAIN_INDEX["water"]
		"snow": return ArtIndex.TERRAIN_INDEX["snow"]
		"desert": return ArtIndex.TERRAIN_INDEX["sand2" if alt else "sand"]
		"caves": return ArtIndex.TERRAIN_INDEX["cave" if alt else "stone"]
		"swamp": return ArtIndex.TERRAIN_INDEX["swamp"]
		"graveyard": return ArtIndex.TERRAIN_INDEX["dirt" if alt else "grass2"]
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
		"graveyard":
			if h < 0.16: return "tomb"
			if h < 0.20: return "fence"
			if h < 0.22: return "tree"
	return ""

func _hash2(x: int, y: int) -> float:
	var n := (x * 374761393 + y * 668265263 + world_seed) & 0x7FFFFFFF
	n = (n ^ (n >> 13)) * 1274126177 & 0x7FFFFFFF
	return float(n & 0xFFFF) / 65535.0

# ---------------------------------------------------------------- query -----
## True when an entity can stand here: in bounds, not water, not inside a
## solid prop, not inside a house roof.
## Nearest walkable tile centre, spiral-searched out to `radius` tiles.
## Every spawn (hero, NPC homes and fields) goes through here so nobody can
## ever start the game embedded in a roof, a well or a tree (audit P0-2).
func nearest_walkable(pos: Vector2, radius: int = 8) -> Vector2:
	var c := tile_at(pos)
	for r in range(0, radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := Vector2i(c.x + dx, c.y + dy)
				var centre := Vector2(t.x * TILE + 8.0, t.y * TILE + 8.0)
				if is_walkable_at(centre):
					return centre
	return pos

func is_walkable_at(world_pos: Vector2) -> bool:
	var t := tile_at(world_pos)
	if t.x < 0 or t.y < 0 or t.x >= WORLD_W or t.y >= WORLD_H:
		return false
	var biome := _biome_grid[t.y * WORLD_W + t.x]
	if biome == "water":
		return false
	if biome in ["village", "town"]:
		var tile: Array = _settlement_tile(_settlement_at_tile(t), t)
		if tile[0] == ArtIndex.TERRAIN_INDEX["roof"]:
			return false
		return tile[1] == "" or not SOLID_PROPS.has(tile[1])
	var prop := _prop_at(biome, t.x, t.y)
	return prop == "" or not SOLID_PROPS.has(prop)

func biome_at(world_pos: Vector2) -> String:
	var t := tile_at(world_pos)
	if t.x < 0 or t.y < 0 or t.x >= WORLD_W or t.y >= WORLD_H:
		return "water"
	return _biome_grid[t.y * WORLD_W + t.x]

func tile_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(TILE)), floori(world_pos.y / float(TILE)))

func settlement_at(world_pos: Vector2) -> Dictionary:
	return _settlement_at_tile(tile_at(world_pos))

# ---------------------------------------------------------------- actors ----
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

## The story starts in the first village plaza, not in the wilderness.
func _spawn_hero() -> void:
	hero = Hero.new()
	hero.name = "Hero"
	actors.add_child(hero)
	if not settlements.is_empty():
		var plaza: Vector2i = settlements[0]["plaza"]
		hero.global_position = nearest_walkable(
			Vector2(plaza.x * TILE + 8.0, (plaza.y + 1) * TILE + 8.0))
	else:
		hero.global_position = Vector2(WORLD_W * TILE * 0.5, WORLD_H * TILE * 0.5)
	hero.cam.limit_left = 0
	hero.cam.limit_top = 0
	hero.cam.limit_right = WORLD_W * TILE
	hero.cam.limit_bottom = WORLD_H * TILE

func _spawn_npcs() -> void:
	for st in settlements:
		var plaza: Vector2i = st["plaza"]
		var roles := ["elder", "merchant", "guard", "villager", "villager", "villager"]
		if st["type"] == "town":
			roles += ["merchant", "guard", "villager", "villager", "villager", "villager", "guard"]
		for i in roles.size():
			var npc := NPC.new()
			npc.name = "NPC_%d_%d" % [st["index"], i]
			actors.add_child(npc)
			var angle := TAU * float(i) / float(roles.size())
			npc.home = Vector2(plaza.x * TILE + 8 + cos(angle) * 26.0,
				plaza.y * TILE + 8 + sin(angle) * 18.0)
			npc.global_position = npc.home
			npc.setup(roles[i], st, i)
			npc.home = nearest_walkable(npc.home)
			npc.field = nearest_walkable(npc.field)
			npc.global_position = npc.home
			npcs.append(npc)
		# the realm's sovereign rules from the town's palace: a unique, named
		# presence rather than one more copy of the eight generic villagers
		if st["type"] == "town":
			var door_tile := _town_palace_door(st)
			var king := NPC.new()
			king.name = "NPC_KING"
			actors.add_child(king)
			king.home = Vector2((door_tile.x) * TILE + 8.0, (door_tile.y + 1) * TILE + 8.0)
			king.global_position = king.home
			king.setup("king", st, 99)
			king.home = nearest_walkable(king.home)
			king.global_position = king.home
			king.display_name = I18N.tr_str("npc.name.king")
			npcs.append(king)

## The palace is the top-centre house of the town's house grid: the king
## rules from there, its door is the entrance to the throne-hall interior,
## and two torches flank the door so it reads as the seat of power.
func _town_palace_door(st: Dictionary) -> Vector2i:
	var houses := _house_rects(st)
	if houses.size() < 2:
		return st["plaza"]
	var palace: Rect2i = houses[1]
	return Vector2i(palace.position.x + palace.size.x / 2,
		palace.position.y + palace.size.y - 1)

## Scatter chests: a few per settlement plus some in the wild.
func _place_chests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0x51ED
	var placed := 0
	var tries := 0
	while placed < 26 and tries < 1400:
		tries += 1
		var t := Vector2i(rng.randi_range(4, WORLD_W - 5), rng.randi_range(4, WORLD_H - 5))
		var pos := Vector2(t.x * TILE + 8.0, t.y * TILE + 8.0)
		if not is_walkable_at(pos):
			continue
		if pos.distance_to(hero.global_position) < 40.0:
			continue
		var chest := Chest.new()
		chest.name = "Chest_%d" % placed
		actors.add_child(chest)
		chest.global_position = pos
		placed += 1

## The dungeon's mouth: one reachable Stairs on the walkable fringe of the
## starting settlement. enter_dungeon()/exit_dungeon() (Main) own the actual
## depth switching; this node only exists so the 330 lines of dungeon content
## are actually reachable from the overworld instead of orphaned.
func _place_cave_entrance() -> void:
	if settlements.is_empty():
		return
	var center: Vector2i = settlements[0]["plaza"]
	var best := Vector2i(-1, -1)
	# spiral outward from the plaza to the first legal tile
	for radius in range(4, 30):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var t := center + Vector2i(dx, dy)
				if t.x < 2 or t.y < 2 or t.x >= WORLD_W - 2 or t.y >= WORLD_H - 2:
					continue
				var p := Vector2(t.x * TILE + 8.0, t.y * TILE + 8.0)
				if not is_walkable_at(p):
					continue
				var b := biome_at(p)
				if b == "water" or b in ["village", "town"]:
					continue
				best = t
				break
			if best.x >= 0:
				break
		if best.x >= 0:
			break
	if best.x < 0:
		return
	var entrance := Stairs.new()
	entrance.name = "CaveEntrance"
	entrance.direction = 1
	actors.add_child(entrance)
	entrance.global_position = Vector2(best.x * TILE + 8.0, best.y * TILE + 8.0)

## Every painted house gets a real door (a Stairs) standing on its door tile.
## Using it walks the hero into that house's Interior (see Main.enter_house).
## The door id encodes settlement * 16 + house index so Main can look up the
## layout kind without any scene-side registry.
func _place_house_doors() -> void:
	for st in settlements:
		var houses := _house_rects(st)
		for hi in houses.size():
			var h: Rect2i = houses[hi]
			var door_t := Vector2i(h.position.x + h.size.x / 2,
				h.position.y + h.size.y - 1)
			var door := Stairs.new()
			door.name = "HouseDoor_%d" % (int(st["index"]) * 16 + hi)
			door.direction = 1
			actors.add_child(door)
			door.global_position = Vector2(door_t.x * TILE + 8.0, door_t.y * TILE + 8.0)

## The Interior flavour for a house id (door tile + layout kind).
func house_kind(house_id: int) -> String:
	var sett_index := house_id / 16
	var house_index := house_id % 16
	for st in settlements:
		if int(st["index"]) == sett_index:
			if st["type"] == "town":
				return "palace" if house_index == 1 else "town_house"
			return "home"
	return "home"

## How many door ids this world carries (kept tiny so tests can assert).
func house_door_count() -> int:
	var n := 0
	for st in settlements:
		n += _house_rects(st).size()
	return n

## How much the hero's lantern is needed here (caves are dark).
func ambient_light_need() -> float:
	var b := biome_at(hero.global_position) if hero else ""
	return 0.8 if b == "caves" else 0.0

func _place_lights() -> void:
	var glow := load("res://assets/sprites/fx/glow.png")
	for st in settlements:
		var plaza: Vector2i = st["plaza"]
		for off in [Vector2(2, 0), Vector2(-2, 0), Vector2(1 - st["rect"].size.x / 2, st["rect"].size.y - 1)]:
			var flame := Sprite2D.new()
			flame.texture = load("res://assets/sprites/fx/flame.png")
			flame.hframes = 2
			flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(flame)
			flame.global_position = Vector2((plaza.x + off.x) * TILE + 8, (plaza.y + off.y) * TILE - 6)
			var light := PointLight2D.new()
			light.texture = glow
			light.color = Color(1.0, 0.75, 0.4)
			light.scale = Vector2(2.6, 2.6)
			light.energy = 0.0
			add_child(light)
			light.global_position = Vector2((plaza.x + off.x) * TILE + 8, (plaza.y + off.y) * TILE + 4)
			_lights.append({"light": light, "kind": "torch", "phase": randf() * TAU,
				"flame": flame})
	# cursed green glows over a few graveyard clusters
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed ^ 0xA115
	var placed := 0
	var tries := 0
	while placed < 8 and tries < 600:
		tries += 1
		var t := Vector2i(rng.randi_range(4, WORLD_W - 5), rng.randi_range(4, WORLD_H - 5))
		var pos := Vector2(t.x * TILE + 8.0, t.y * TILE + 8.0)
		if biome_at(pos) != "graveyard":
			continue
		var light := PointLight2D.new()
		light.texture = glow
		light.color = Color(0.4, 1.0, 0.55)
		light.scale = Vector2(1.8, 1.8)
		light.energy = 0.0
		add_child(light)
		light.global_position = pos
		_lights.append({"light": light, "kind": "wisp", "phase": randf() * TAU})
		placed += 1

func _process(delta: float) -> void:
	for entry in _lights:
		var light: PointLight2D = entry["light"]
		entry["phase"] += delta
		if entry["kind"] == "torch":
			light.energy = 0.9 + 0.12 * sin(entry["phase"] * 9.0) if Game.is_night() else 0.0
			var flame: Sprite2D = entry["flame"]
			flame.frame = int(entry["phase"] * 9.0) % 2
			flame.visible = Game.is_night() or light.energy > 0.0
		else:
			light.energy = (0.3 + 0.2 * sin(entry["phase"] * 2.2)) if Game.is_night() else 0.12
	_shimmer_t += delta
	if _shimmer_t >= 0.7 and not _water_cells.is_empty():
		_shimmer_t = 0.0
		_water_phase = 1 - _water_phase
		var atlas := Vector2i(ArtIndex.TERRAIN_INDEX["water" if _water_phase == 0 else "water2"] % 8,
			ArtIndex.TERRAIN_INDEX["water" if _water_phase == 0 else "water2"] / 8)
		for cell in _water_cells:
			terrain_layer.set_cell(cell, 0, atlas)
	if hero == null or hero.get_parent() != actors:
		return   # hero is elsewhere (a dungeon): keep its biome label
	var b := biome_at(hero.global_position)
	if b != _current_biome:
		_current_biome = b
		biome_changed.emit(b)
