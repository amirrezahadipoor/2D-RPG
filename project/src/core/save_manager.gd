# Save Manager - Phase 11 Polish
# Hardcore save system: checkpoint rooms (dungeons), autosave (open world), permadeath option
# Offline-only: uses user:// saves, no cloud, encrypted if needed

extends Node
class_name SaveManager

const SAVE_PATH := "user://savegame.save"
const SETTINGS_PATH := "user://settings.cfg"
const BACKUP_PATH := "user://savegame_backup.save"

# Hardcore options
@export var hardcore_permdeath: bool = true # if true, death deletes save (Phase 9/10)
@export var autosave_interval: float = 45.0 # seconds
@export var checkpoint_only: bool = false # if true, only checkpoint rooms can save

var _autosave_timer: float = 0.0
var _last_save_data: Dictionary = {}

signal game_saved(slot: String)
signal game_loaded(data: Dictionary)
signal save_deleted()

func _ready() -> void:
	set_process(true)
	print("[SaveManager] hardcore=", hardcore_permdeath, " checkpoint_only=", checkpoint_only)

func _process(delta: float) -> void:
	if checkpoint_only:
		return # no autosave in checkpoint-only hardcore
	_autosave_timer += delta
	if _autosave_timer >= autosave_interval:
		_autosave_timer = 0.0
		if _should_autosave():
			autosave()

func _should_autosave() -> bool:
	# Don't autosave in combat or in boss room
	if has_node("/root/CombatManager"):
		var cm = get_node("/root/CombatManager")
		if cm.has_method("is_in_combat") and cm.is_in_combat():
			return false
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(data: Dictionary, is_checkpoint: bool = false) -> bool:
	# Validate data has required fields
	if not data.has("player"):
		push_warning("[SaveManager] save data missing player key")
		return false
	data["timestamp"] = Time.get_unix_time_from_system()
	data["version"] = "1.0-polish"
	data["is_checkpoint"] = is_checkpoint
	data["playtime"] = data.get("playtime", 0.0)
	
	# Backup previous save
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.copy(SAVE_PATH, BACKUP_PATH)
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] cannot open save file for writing")
		return false
	var json_str := JSON.stringify(data)
	file.store_string(json_str)
	file.close()
	_last_save_data = data
	emit_signal("game_saved", "autosave" if not is_checkpoint else "checkpoint")
	print("[SaveManager] game saved checkpoint=", is_checkpoint, " size=", json_str.length())
	return true

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("[SaveManager] no save file")
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var json_str := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_str) != OK:
		push_error("[SaveManager] corrupt save, trying backup")
		return _load_backup()
	var data: Dictionary = json.data
	if not data is Dictionary:
		return _load_backup()
	_last_save_data = data
	emit_signal("game_loaded", data)
	print("[SaveManager] game loaded, playtime=", data.get("playtime", 0))
	return data

func _load_backup() -> Dictionary:
	if not FileAccess.file_exists(BACKUP_PATH):
		return {}
	var file := FileAccess.open(BACKUP_PATH, FileAccess.READ)
	if not file:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	return json.data

func autosave() -> bool:
	# Collect current game state
	var data := collect_game_state()
	if data.is_empty():
		return false
	return save_game(data, false)

func save_checkpoint(checkpoint_data: Dictionary) -> bool:
	checkpoint_data["is_checkpoint"] = true
	return save_game(checkpoint_data, true)

func collect_game_state() -> Dictionary:
	# Gather from other managers if present
	var player_data := {}
	if has_node("/root/Player"):
		var p = get_node("/root/Player")
		player_data = {
			"position": {"x": p.global_position.x, "y": p.global_position.y} if "global_position" in p else {"x": 0, "y": 0},
			"level": p.get_meta("level", 1) if p.has_meta("level") else 1,
			"hp": p.get_meta("hp", 100) if p.has_meta("hp") else 100,
			"max_hp": p.get_meta("max_hp", 100) if p.has_meta("max_hp") else 100,
			"stamina": p.get_meta("stamina", 100) if p.has_meta("stamina") else 100,
		}
	var inventory_data := {}
	if has_node("/root/InventoryManager") and get_node("/root/InventoryManager").has_method("get_save_data"):
		inventory_data = get_node("/root/InventoryManager").get_save_data()
	var world_data := {}
	if has_node("/root/WorldManager") and get_node("/root/WorldManager").has_method("get_save_data"):
		world_data = get_node("/root/WorldManager").get_save_data()
	var quest_data := {}
	if has_node("/root/QuestManager") and get_node("/root/QuestManager").has_method("get_save_data"):
		quest_data = get_node("/root/QuestManager").get_save_data()
	
	return {
		"player": player_data,
		"inventory": inventory_data,
		"world": world_data,
		"quests": quest_data,
		"playtime": _last_save_data.get("playtime", 0.0),
		"hardcore": hardcore_permdeath
	}

func on_player_death() -> void:
	if hardcore_permdeath:
		# Hardcore: delete save, force new game (Phase 9)
		delete_save()
		print("[SaveManager] HARDCORE DEATH - save deleted (permadeath)")
	else:
		# Softcore: reload last checkpoint
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.open("user://").copy(BACKUP_PATH, SAVE_PATH)

func delete_save() -> bool:
	var dir := DirAccess.open("user://")
	if dir and FileAccess.file_exists(SAVE_PATH):
		var err := dir.remove(SAVE_PATH)
		emit_signal("save_deleted")
		return err == OK
	return false

func get_save_info() -> Dictionary:
	if not has_save():
		return {"exists": false}
	var data := load_game()
	return {
		"exists": true,
		"timestamp": data.get("timestamp", 0),
		"level": data.get("player", {}).get("level", 1),
		"playtime": data.get("playtime", 0),
		"is_checkpoint": data.get("is_checkpoint", false),
		"hardcore": data.get("hardcore", true)
	}
