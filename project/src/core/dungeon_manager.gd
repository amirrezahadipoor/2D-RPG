# Dungeon Manager - Phase 7 Core System
# Procedural room-and-corridor dungeons, up to 15 rooms, depth-scaled enemies
# 5 room types, boss rooms, checkpoints

extends Node
class_name DungeonManager

signal dungeon_generated(room_count: int, floor: int)
signal room_entered(room: Dictionary)
signal dungeon_completed()
signal checkpoint_reached()

const MAX_ROOMS: int = 15
const ROOM_TYPES = ["start", "normal", "treasure", "elite", "boss", "checkpoint"]

enum RoomType { START, NORMAL, TREASURE, ELITE, BOSS, CHECKPOINT }

var current_dungeon: Dictionary = {}
var current_floor: int = 1
var current_room: Dictionary = {}
var rooms: Array[Dictionary] = []
var is_in_dungeon: bool = false

# Dungeon difficulty scaling per floor
const DIFFICULTY_SCALING = {
	1: {"enemy_mult": 1.0, "hp_mult": 1.0, "dmg_mult": 1.0},
	2: {"enemy_mult": 1.2, "hp_mult": 1.15, "dmg_mult": 1.1},
	3: {"enemy_mult": 1.4, "hp_mult": 1.3, "dmg_mult": 1.2},
	4: {"enemy_mult": 1.6, "hp_mult": 1.5, "dmg_mult": 1.35},
	5: {"enemy_mult": 1.8, "hp_mult": 1.7, "dmg_mult": 1.5},
	6: {"enemy_mult": 2.0, "hp_mult": 1.9, "dmg_mult": 1.65},
	7: {"enemy_mult": 2.2, "hp_mult": 2.1, "dmg_mult": 1.8},
	8: {"enemy_mult": 2.5, "hp_mult": 2.35, "dmg_mult": 1.95},
	9: {"enemy_mult": 2.8, "hp_mult": 2.6, "dmg_mult": 2.1},
	10: {"enemy_mult": 3.0, "hp_mult": 2.85, "dmg_mult": 2.25}
}

var rng: RandomNumberGenerator

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	print("[DungeonManager] ready")

func generate_dungeon(floor: int = 1, size: int = -1) -> Dictionary:
	current_floor = clamp(floor, 1, 10)
	if size < 0:
		size = rng.randi_range(8, MAX_ROOMS)
	
	rng.randomize()
	rooms.clear()
	
	# Generate rooms
	var room_count = min(size, MAX_ROOMS)
	var start_pos = Vector2i(0, 0)
	
	# Place start room
	var start_room = _create_room(start_pos, RoomType.START)
	rooms.append(start_room)
	
	# Generate corridor-connected rooms
	var placed = 1
	var frontier = [start_pos]
	var attempts = 0
	const MAX_ATTEMPTS = 1000
	
	while placed < room_count and attempts < MAX_ATTEMPTS:
		attempts += 1
		var base = frontier[rng.randi() % frontier.size()]
		var direction = _random_direction()
		var new_pos = base + direction
		
		# Check if position is valid
		if _is_position_valid(new_pos, placed):
			var room_type = _pick_room_type(placed, room_count)
			var room = _create_room(new_pos, room_type)
			room["connections"] = [base]
			rooms.append(room)
			
			# Add corridor
			_create_corridor(base, new_pos, rooms[rooms.size() - 2], room)
			
			frontier.append(new_pos)
			placed += 1
	
	current_dungeon = {
		"floor": current_floor,
		"rooms": rooms,
		"start_room": start_room
	}
	
	is_in_dungeon = true
	emit_signal("dungeon_generated", rooms.size(), current_floor)
	
	print("[DungeonManager] Generated dungeon floor ", current_floor, " with ", rooms.size(), " rooms")
	return current_dungeon

func _create_room(pos: Vector2i, room_type: int) -> Dictionary:
	var room_size = Vector2i(96, 96)
	match room_type:
		RoomType.BOSS:
			room_size = Vector2i(128, 128)
		RoomType.TREASURE:
			room_size = Vector2i(80, 80)
	
	return {
		"position": pos,
		"size": room_size,
		"type": room_type,
		"type_name": ROOM_TYPES[room_type],
		"world_pos": _grid_to_world(pos),
		"cleared": room_type == RoomType.START,
		"enemies_remaining": _get_enemy_count(room_type),
		"chest_type": _get_chest_type(room_type),
		"connections": []
	}

func _create_corridor(from: Vector2i, to: Vector2i, room_from: Dictionary, room_to: Dictionary) -> void:
	# Simple L-shape corridor
	pass  # Visual corridors are handled by rendering

func _random_direction() -> Vector2i:
	var dirs = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]
	return dirs[rng.randi() % dirs.size()]

func _is_position_valid(pos: Vector2i, current_count: int) -> bool:
	# Check bounds
	if pos.x < -20 or pos.x > 20 or pos.y < -20 or pos.y > 20:
		return false
	
	# Check for existing room
	for room in rooms:
		if room["position"] == pos:
			return false
	
	# Distance check
	for room in rooms:
		var dist = pos.distance_to(room["position"])
		if dist < 2:
			return false
	
	return true

func _pick_room_type(room_index: int, total: int) -> int:
	var progress = float(room_index) / float(total)
	
	if room_index == 0:
		return RoomType.START
	elif progress > 0.85 and current_floor >= 3:
		return RoomType.BOSS
	elif progress > 0.7 and rng.randf() < 0.3:
		return RoomType.ELITE
	elif progress > 0.5 and rng.randf() < 0.25:
		return RoomType.TREASURE
	elif progress > 0.3 and rng.randf() < 0.2:
		return RoomType.CHECKPOINT
	else:
		return RoomType.NORMAL

func _get_enemy_count(room_type: int) -> int:
	match room_type:
		RoomType.BOSS:
			return 1
		RoomType.ELITE:
			return rng.randi_range(2, 4)
		RoomType.TREASURE:
			return 0
		RoomType.CHECKPOINT:
			return rng.randi_range(1, 2)
		_:
			return rng.randi_range(2, 4)

func _get_chest_type(room_type: int) -> String:
	match room_type:
		RoomType.BOSS:
			return "boss"
		RoomType.ELITE:
			return "large"
		RoomType.TREASURE:
			return "medium"
		RoomType.CHECKPOINT:
			return "small"
		_:
			return "small"

func _grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * 200, grid_pos.y * 200)

func enter_room(room: Dictionary) -> void:
	current_room = room
	emit_signal("room_entered", room)
	
	if not room["cleared"]:
		_spawn_room_enemies(room)

func _spawn_room_enemies(room: Dictionary) -> void:
	var enemy_count = room.get("enemies_remaining", 0)
	if enemy_count <= 0:
		return
	
	if not has_node("/root/CombatManager"):
		return
	
	var combat = get_node("/root/CombatManager")
	var diff = DIFFICULTY_SCALING.get(current_floor, DIFFICULTY_SCALING[1])
	
	for i in range(enemy_count):
		var enemy_types = ["skeleton", "orc", "demon"]
		if current_floor >= 5:
			enemy_types.append("demon")
		if current_floor >= 8:
			enemy_types.append("dragon")
		
		var enemy_type = enemy_types[rng.randi() % enemy_types.size()]
		var offset = Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50))
		var pos = room["world_pos"] + Vector2(100, 100) + offset
		
		combat.spawn_enemy(enemy_type, pos, current_floor)

func on_enemy_killed() -> void:
	if current_room.is_empty():
		return
	
	current_room["enemies_remaining"] -= 1
	if current_room["enemies_remaining"] <= 0:
		current_room["cleared"] = true
		
		# Spawn chest if applicable
		var chest_type = current_room.get("chest_type", "")
		if chest_type != "":
			_spawn_chest(current_room["world_pos"] + Vector2(100, 100), chest_type)
		
		# Boss room = dungeon complete
		if current_room.get("type") == RoomType.BOSS:
			complete_dungeon()

func _spawn_chest(pos: Vector2, chest_type: String) -> void:
	if has_node("/root/WorldManager"):
		get_node("/root/WorldManager").spawn_chest_at(pos, chest_type)

func complete_dungeon() -> void:
	is_in_dungeon = false
	emit_signal("dungeon_completed")
	print("[DungeonManager] Dungeon floor ", current_floor, " completed!")

func reach_checkpoint() -> void:
	emit_signal("checkpoint_reached")
	
	# Save checkpoint
	if has_node("/root/SaveManager"):
		get_node("/root/PlayerStats").full_restore()
		get_node("/root/SaveManager").save_checkpoint({})

func get_current_difficulty() -> Dictionary:
	return DIFFICULTY_SCALING.get(current_floor, DIFFICULTY_SCALING[1])

func exit_dungeon() -> Dictionary:
	is_in_dungeon = false
	
	if has_node("/root/CombatManager"):
		get_node("/root/CombatManager").clear_all_enemies()
	
	return current_dungeon

func get_room_at(world_pos: Vector2) -> Dictionary:
	for room in rooms:
		var room_pos = room["world_pos"]
		var room_size = room["size"]
		if world_pos.x >= room_pos.x and world_pos.x < room_pos.x + room_size.x:
			if world_pos.y >= room_pos.y and world_pos.y < room_pos.y + room_size.y:
				return room
	return {}

func is_boss_room(room: Dictionary) -> bool:
	return room.get("type") == RoomType.BOSS

func get_boss_name() -> String:
	match current_floor:
		1: return "Cave Spider"
		2: return "Skeleton Warrior"
		3: return "Orc Chieftain"
		4: return "Dark Mage"
		5: return "Demon Lord"
		6: return "Ice Dragon"
		7: return "Flame Wyrm"
		8: return "Shadow King"
		9: return "Death Knight"
		_: return "Final Boss"

# Save/Load
func get_save_data() -> Dictionary:
	return {
		"current_floor": current_floor,
		"current_dungeon": current_dungeon,
		"is_in_dungeon": is_in_dungeon
	}

func load_save_data(data: Dictionary) -> void:
	current_floor = data.get("current_floor", 1)
	current_dungeon = data.get("current_dungeon", {})
	is_in_dungeon = data.get("is_in_dungeon", false)
	rooms = current_dungeon.get("rooms", [])
