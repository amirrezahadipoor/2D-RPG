# Walk-in house interiors. Each home in a settlement has a door (a Stairs on
# the overworld); using it lifts the hero into a small furnished interior map
# that covers the viewport, so entering a house finally means entering a house
# instead of leaning against a painted door tile.
#
# Layout: one living room in the upper area with a corridor running down the
# middle to the front door (the ExitDoor stairs). Walls are one tile thick;
# everything outside the floor is solid roof so no overworld peeks in.
class_name Interior
extends Node2D

const TILE := 16
const MAP_W := 32
const MAP_H := 18
const ROOM_Y0 := 5
const CORRIDOR_X := MAP_W / 2      # the door axis of the house

const ROOM_SIZES := {
	"home": Vector2i(11, 6),
	"town_house": Vector2i(13, 7),
	"palace": Vector2i(17, 9),
}

var kind := "home"
var room := Rect2i()
var entry_tile := Vector2i()      # interior front door (ExitDoor stairs)
var spawn_tile := Vector2i()      # where the hero appears after stepping in

var terrain_layer: TileMapLayer
var actors: Node2D
var exit_stairs: Stairs = null
var _grid := PackedByteArray()
var _furniture: Node2D
var _lights: Array = []

signal exited()

func build(kind_value: String, house_id: int, seed_value: int) -> void:
	kind = kind_value
	var dim: Vector2i = ROOM_SIZES.get(kind, ROOM_SIZES["home"])
	room = Rect2i(CORRIDOR_X - dim.x / 2, ROOM_Y0, dim.x, dim.y)
	entry_tile = Vector2i(CORRIDOR_X, MAP_H - 2)
	spawn_tile = Vector2i(CORRIDOR_X, MAP_H - 3)
	_grid.resize(MAP_W * MAP_H)
	_generate_floor(seed_value)
	_build_layers(house_id, seed_value)
	print("[Interior] kind=%s house=%d room=%s" % [kind, house_id, room])

# ------------------------------------------------------------- layout ------
func _generate_floor(_seed_value: int) -> void:
	# living-room floor
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			_grid[y * MAP_W + x] = 1
	# the front-door corridor drops from the room's bottom edge to the door
	for y in range(room.end.y, entry_tile.y + 1):
		_grid[y * MAP_W + CORRIDOR_X] = 1

func is_walkable_at(world_pos: Vector2) -> bool:
	var t := Vector2i(floori(world_pos.x / float(TILE)), floori(world_pos.y / float(TILE)))
	if t.x < 0 or t.y < 0 or t.x >= MAP_W or t.y >= MAP_H:
		return false
	return _grid[t.y * MAP_W + t.x] == 1

func tile_at(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / float(TILE)), floori(world_pos.y / float(TILE)))

func cell_center(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + 8.0, t.y * TILE + 8.0)

# ------------------------------------------------------------- visuals -----
func _build_layers(house_id: int, seed_value: int) -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	var terrain := TileSetAtlasSource.new()
	terrain.texture = load("res://assets/sprites/tiles/terrain.png")
	terrain.texture_region_size = Vector2i(TILE, TILE)
	for i in ArtIndex.TERRAIN_INDEX.size():
		terrain.create_tile(Vector2i(i % 8, i / 8))
	ts.add_source(terrain, 0)
	# everything that is not floor is solid wall
	var wall: TileData = terrain.get_tile_data(
		Vector2i(ArtIndex.TERRAIN_INDEX["roof"] % 8, ArtIndex.TERRAIN_INDEX["roof"] / 8), 0)
	if wall:
		wall.add_collision_polygon(0)
		wall.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	terrain_layer = TileMapLayer.new()
	terrain_layer.name = "Terrain"
	terrain_layer.tile_set = ts
	terrain_layer.collision_enabled = true
	add_child(terrain_layer)

	# base paint: whole map is wall, then carve floor + furniture
	for y in MAP_H:
		for x in MAP_W:
			terrain_layer.set_cell(Vector2i(x, y), 0,
				Vector2i(ArtIndex.TERRAIN_INDEX["roof"] % 8, ArtIndex.TERRAIN_INDEX["roof"] / 8))
	var floor_atlas := Vector2i(ArtIndex.TERRAIN_INDEX["wood"] % 8, ArtIndex.TERRAIN_INDEX["wood"] / 8)
	for y in MAP_H:
		for x in MAP_W:
			if _grid[y * MAP_W + x] == 1:
				terrain_layer.set_cell(Vector2i(x, y), 0, floor_atlas)

	# furniture (bed, table, hearth, rug) as flat slabs that block walking
	_furniture = Node2D.new()
	_furniture.name = "Furniture"
	add_child(_furniture)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ (house_id * 7919) ^ 0x1FAB
	_place_furniture(rng)

	actors = Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)

	# the front door back to the overworld
	exit_stairs = Stairs.new()
	exit_stairs.name = "ExitDoor"
	exit_stairs.direction = -1
	actors.add_child(exit_stairs)
	exit_stairs.global_position = cell_center(entry_tile)

	# a locked-away chest: every home hides a little stash
	var chest := Chest.new()
	chest.name = "Chest"
	actors.add_child(chest)
	var stash: Vector2i = Vector2i(room.position.x + room.size.x - 2, room.end.y - 2)
	_grid[stash.y * MAP_W + stash.x] = 1
	terrain_layer.set_cell(stash, 0, floor_atlas)
	chest.global_position = cell_center(stash)

	# warm hearth light makes the room feel lived-in
	var glow := load("res://assets/sprites/fx/glow.png")
	var hearth: Vector2i = Vector2i(room.position.x + 2, room.end.y - 2)
	_grid[hearth.y * MAP_W + hearth.x] = 1
	terrain_layer.set_cell(hearth, 0, floor_atlas)
	var light := PointLight2D.new()
	light.texture = glow
	light.color = Color(1.0, 0.6, 0.3)
	light.scale = Vector2(3.0, 3.0)
	light.energy = 1.1
	add_child(light)
	light.global_position = cell_center(hearth)
	_lights.append(light)

func _block_visual(t: Vector2i, color: Color, w: int = 1, h: int = 1) -> void:
	for y in range(t.y, t.y + h):
		for x in range(t.x, t.x + w):
			if x >= 0 and y >= 0 and x < MAP_W and y < MAP_H:
				_grid[y * MAP_W + x] = 0
	var slab := ColorRect.new()
	slab.color = color
	slab.position = Vector2(t.x * TILE, t.y * TILE)
	slab.size = Vector2(w * TILE, h * TILE)
	_furniture.add_child(slab)

func _place_furniture(_rng: RandomNumberGenerator) -> void:
	var cx := CORRIDOR_X
	# rug at the door axis of the room (decorative, walkable)
	var rug_w := mini(room.size.x - 2, 7)
	var rug := ColorRect.new()
	rug.color = Color(0.55, 0.35, 0.22, 0.5)
	rug.position = Vector2((cx - rug_w / 2) * TILE, (room.position.y + 1) * TILE)
	rug.size = Vector2(rug_w * TILE, (room.size.y - 2) * TILE)
	_furniture.add_child(rug)
	# bed against the top-left wall
	var bed: Vector2i = Vector2i(room.position.x + 1, room.position.y + 1)
	_block_visual(bed, Color(0.42, 0.26, 0.18), 3, 2)
	_block_visual(bed + Vector2i(0, 1), Color(0.95, 0.9, 0.75), 3, 1)  # pillow line
	# side table by the bed
	_block_visual(bed + Vector2i(4, 0), Color(0.5, 0.36, 0.22), 1, 1)
	# hearth with glow against the top-right wall
	var hearth: Vector2i = Vector2i(room.end.x - 3, room.position.y + 1)
	_block_visual(hearth, Color(0.25, 0.2, 0.2), 2, 1)
	var flame := ColorRect.new()
	flame.color = Color(1.0, 0.6, 0.25, 0.9)
	flame.position = Vector2((hearth.x + 1) * TILE - 3, hearth.y * TILE - 3)
	flame.size = Vector2(6, 5)
	_furniture.add_child(flame)
	# palace: a throne seat centred on the far wall
	if kind == "palace":
		var throne: Vector2i = Vector2i(cx - 1, room.position.y)
		_block_visual(throne, Color(0.85, 0.7, 0.25), 3, 1)
		_block_visual(throne + Vector2i(0, 1), Color(0.6, 0.4, 0.2), 1, 1)
		_block_visual(throne + Vector2i(2, 1), Color(0.6, 0.4, 0.2), 1, 1)
	# a little potted luck by the door
	var pot: Vector2i = Vector2i(cx - 2, room.end.y - 1)
	_grid[pot.y * MAP_W + pot.x] = 1
	var pa := Vector2i(ArtIndex.TERRAIN_INDEX["wood"] % 8, ArtIndex.TERRAIN_INDEX["wood"] / 8)
	terrain_layer.set_cell(pot, 0, pa)
