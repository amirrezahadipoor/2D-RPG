# World Manager - Phase 6 Core System
# Procedural open world with 7 biomes, 200x200 tile map
# Village/town placement, NPC system, entity spawning

extends Node
class_name WorldManager

signal biome_changed(new_biome: String)
signal location_changed(location_type: String)

const BIOMES = ["forest", "desert", "snow", "swamp", "caves", "village", "town"]
const BIOME_COLORS = {
	"forest": Color(0.15, 0.45, 0.15),
	"desert": Color(0.76, 0.7, 0.5),
	"snow": Color(0.9, 0.95, 1.0),
	"swamp": Color(0.3, 0.4, 0.3),
	"caves": Color(0.25, 0.22, 0.2),
	"village": Color(0.6, 0.5, 0.3),
	"town": Color(0.5, 0.45, 0.4)
}

const WORLD_SIZE: int = 200
const TILE_SIZE: int = 32

var current_biome: String = "forest"
var current_location: String = "wilderness"
var world_seed: int = 0
var rng: RandomNumberGenerator

# World data (procedural)
var biome_map: Array = []
var npcs: Array[Dictionary] = []
var chests: Array[Dictionary] = []
var dungeon_entrances: Array[Vector2i] = []

# TileMap reference
var tile_map: TileMap = null

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	world_seed = randi()
	rng.seed = world_seed
	print("[WorldManager] initialized, seed: ", world_seed)

func generate_world() -> void:
	print("[WorldManager] Generating world ", WORLD_SIZE, "x", WORLD_SIZE)
	
	# Generate biome map
	_generate_biome_map()
	
	# Place villages and towns
	_place_villages()
	_place_towns()
	
	# Place dungeon entrances
	_place_dungeons()
	
	print("[WorldManager] World generated: ", npcs.size(), " NPCs, ", dungeon_entrances.size(), " dungeons")

func _generate_biome_map() -> void:
	biome_map.clear()
	
	# Simple noise-based biome distribution
	for y in range(WORLD_SIZE):
		var row = []
		for x in range(WORLD_SIZE):
			var biome = _get_biome_at(x, y)
			row.append(biome)
		biome_map.append(row)
	
	# Determine current biome based on player position
	# Default to center
	current_biome = _get_biome_at(WORLD_SIZE / 2, WORLD_SIZE / 2)

func _get_biome_at(x: int, y: int) -> String:
	# Use noise for biome determination
	var nx = float(x) / float(WORLD_SIZE) * 4.0
	var ny = float(y) / float(WORLD_SIZE) * 4.0
	
	var noise = rng.randf() * 0.5 + sin(nx * 2.1) * cos(ny * 1.7) * 0.3 + sin(nx * 0.5 + ny * 0.3) * 0.2
	
	var biome_idx = int((noise + 1.0) * 3.5) % BIOMES.size()
	biome_idx = clamp(biome_idx, 0, BIOMES.size() - 2)  # Exclude village/town from random
	
	return BIOMES[biome_idx]

func update_biome_at(pos: Vector2) -> void:
	var tile_x = int(pos.x / TILE_SIZE) % WORLD_SIZE
	var tile_y = int(pos.y / TILE_SIZE) % WORLD_SIZE
	tile_x = clamp(tile_x, 0, WORLD_SIZE - 1)
	tile_y = clamp(tile_y, 0, WORLD_SIZE - 1)
	
	var new_biome = biome_map[tile_y][tile_x]
	if new_biome != current_biome:
		current_biome = new_biome
		emit_signal("biome_changed", current_biome)
		# Update music
		if has_node("/root/AudioManager"):
			get_node("/root/AudioManager").play_music_for_biome(current_biome)
		
		# Spawn appropriate enemies
		_spawn_biome_enemies(pos, current_biome)

func _spawn_biome_enemies(pos: Vector2, biome: String) -> void:
	if not has_node("/root/CombatManager"):
		return
	
	var combat = get_node("/root/CombatManager")
	
	# Spawn 1-3 enemies based on biome
	var enemy_count = rng.randi_range(1, 3)
	var enemies = CombatManager.BIOME_ENEMIES.get(biome, CombatManager.BIOME_ENEMIES["forest"])
	
	for i in range(enemy_count):
		var enemy_type = enemies[rng.randi() % enemies.size()]
		var offset = Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50))
		combat.spawn_enemy(enemy_type, pos + offset, 1)

func _place_villages() -> void:
	var village_count = rng.randi_range(3, 6)
	
	for i in range(village_count):
		var x = rng.randi_range(20, WORLD_SIZE - 20)
		var y = rng.randi_range(20, WORLD_SIZE - 20)
		
		biome_map[y][x] = "village"
		
		# Add village NPC
		npcs.append({
			"type": "trader",
			"position": Vector2i(x, y) * TILE_SIZE,
			"dialogue": "Welcome to our village, traveler!",
			"biome": "village",
			"name": "Village Trader"
		})

func _place_towns() -> void:
	var town_count = rng.randi_range(1, 3)
	
	for i in range(town_count):
		var x = rng.randi_range(30, WORLD_SIZE - 30)
		var y = rng.randi_range(30, WORLD_SIZE - 30)
		
		biome_map[y][x] = "town"
		
		# Add town NPCs
		npcs.append({
			"type": "merchant",
			"position": Vector2i(x, y) * TILE_SIZE,
			"dialogue": "Welcome to our town! Browse my wares.",
			"biome": "town",
			"name": "Town Merchant"
		})
		npcs.append({
			"type": "quest_giver",
			"position": Vector2i(x + 1, y) * TILE_SIZE,
			"dialogue": "Adventure awaits! I have tasks for you.",
			"biome": "town",
			"name": "Town Quest Master"
		})

func _place_dungeons() -> void:
	var dungeon_count = rng.randi_range(5, 10)
	
	for i in range(dungeon_count):
		var x = rng.randi_range(10, WORLD_SIZE - 10)
		var y = rng.randi_range(10, WORLD_SIZE - 10)
		
		biome_map[y][x] = "caves"
		dungeon_entrances.append(Vector2i(x, y))
		
		# Place treasure chest nearby
		chests.append({
			"position": Vector2i(x + 1, y) * TILE_SIZE,
			"type": "medium",
			"rarity": rng.randi_range(1, 3)
		})

func spawn_chest_at(pos: Vector2, chest_type: String = "small") -> void:
	chests.append({
		"position": pos,
		"type": chest_type,
		"rarity": 1,
		"opened": false
	})

func get_npc_at(pos: Vector2, radius: float = 64.0) -> Dictionary:
	for npc in npcs:
		var npc_pos = npc.get("position", Vector2.ZERO)
		if pos.distance_to(npc_pos) < radius:
			return npc
	return {}

func interact_with_npc(npc: Dictionary) -> void:
	current_location = npc.get("type", "wilderness")
	emit_signal("location_changed", current_location)
	
	match npc.get("type"):
		"trader", "merchant":
			_show_trade_ui(npc)
		"quest_giver":
			_show_quest_ui(npc)

func _show_trade_ui(npc: Dictionary) -> void:
	if has_node("/root/UIManager"):
		var ui = get_node("/root/UIManager")
		if ui.has_method("show_trade_panel"):
			ui.show_trade_panel(npc)

func _show_quest_ui(npc: Dictionary) -> void:
	if has_node("/root/UIManager"):
		var ui = get_node("/root/UIManager")
		if ui.has_method("show_quest_panel"):
			ui.show_quest_panel(npc)

func get_tile_color(tile_pos: Vector2i) -> Color:
	if tile_pos.y < 0 or tile_pos.y >= biome_map.size():
		return Color.BLACK
	if tile_pos.x < 0 or tile_pos.x >= biome_map[tile_pos.y].size():
		return Color.BLACK
	return BIOME_COLORS.get(biome_map[tile_pos.y][tile_pos.x], Color.GRAY)

func world_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x / TILE_SIZE), int(world_pos.y / TILE_SIZE))

func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(tile_pos.x * TILE_SIZE, tile_pos.y * TILE_SIZE)

func is_in_dungeon() -> bool:
	return current_biome == "caves"

func get_npc_count() -> int:
	return npcs.size()

func get_dungeon_count() -> int:
	return dungeon_entrances.size()

# Save/Load
func get_save_data() -> Dictionary:
	return {
		"world_seed": world_seed,
		"current_biome": current_biome,
		"npcs": npcs,
		"chests": chests,
		"dungeon_entrances": dungeon_entrances
	}

func load_save_data(data: Dictionary) -> void:
	world_seed = data.get("world_seed", 0)
	rng.seed = world_seed
	current_biome = data.get("current_biome", "forest")
	npcs = data.get("npcs", [])
	chests = data.get("chests", [])
	dungeon_entrances = data.get("dungeon_entrances", [])
	_generate_biome_map()
