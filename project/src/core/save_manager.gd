# Save Manager - Phase 11 Polish - Fixed
# Hardcore save system: checkpoint rooms (dungeons), autosave (open world), permadeath option
# Offline-only: uses user:// saves, no cloud

extends Node
class_name SaveManager

const SAVE_PATH := "user://savegame.save"
const BACKUP_PATH := "user://savegame_backup.save"

@export var hardcore_permdeath: bool = true
@export var autosave_interval: float = 45.0
@export var checkpoint_only: bool = false

var _autosave_timer: float = 0.0

signal game_saved(slot: String)
signal game_loaded(data: Dictionary)
signal save_deleted()

func _ready() -> void:
	set_process(true)
	print("[SaveManager] hardcore=", hardcore_permdeath, " checkpoint_only=", checkpoint_only)

func _process(delta: float) -> void:
	if checkpoint_only:
		return
	_autosave_timer += delta
	if _autosave_timer >= autosave_interval:
		_autosave_timer = 0.0
		if _should_autosave():
			_autosave()

func _should_autosave() -> bool:
	# Don't autosave in combat
	if has_node("/root/CombatManager"):
		var cm = get_node("/root/CombatManager")
		if cm.is_in_combat():
			return false
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(data: Dictionary, is_checkpoint: bool = false) -> bool:
	if not data.has("player"):
		push_warning("[SaveManager] save data missing player key")
		return false
	
	data["timestamp"] = Time.get_unix_time_from_system()
	data["version"] = "1.0-complete"
	data["is_checkpoint"] = is_checkpoint
	
	# Backup previous save
	if FileAccess.file_exists(SAVE_PATH):
		var dir = DirAccess.open("user://")
		if dir:
			dir.copy(SAVE_PATH, BACKUP_PATH)
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[SaveManager] cannot open save file for writing")
		return false
	
	var json_str = JSON.stringify(data)
	file.store_string(json_str)
	file.close()
	
	emit_signal("game_saved", "checkpoint" if is_checkpoint else "autosave")
	print("[SaveManager] game saved, size=", json_str.length())
	return true

func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		push_warning("[SaveManager] no save file")
		return {}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_str) != OK:
		push_error("[SaveManager] corrupt save, trying backup")
		return _load_backup()
	
	var data = json.data
	if not data is Dictionary:
		return _load_backup()
	
	emit_signal("game_loaded", data)
	print("[SaveManager] game loaded, playtime=", data.get("playtime", 0))
	return data

func _load_backup() -> Dictionary:
	if not FileAccess.file_exists(BACKUP_PATH):
		return {}
	
	var file = FileAccess.open(BACKUP_PATH, FileAccess.READ)
	if not file:
		return {}
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	
	return json.data if json.data is Dictionary else {}

func autosave() -> bool:
	if not has_node("/root/GameManager"):
		return false
	var gm = get_node("/root/GameManager")
	var data = gm._collect_game_state()
	return save_game(data, false)

func _autosave() -> void:
	autosave()

func save_checkpoint(checkpoint_data: Dictionary) -> bool:
	checkpoint_data["is_checkpoint"] = true
	return save_game(checkpoint_data, true)

func on_player_death() -> void:
	if hardcore_permdeath:
		delete_save()
		print("[SaveManager] HARDCORE DEATH - save deleted (permadeath)")
	else:
		if FileAccess.file_exists(BACKUP_PATH):
			var dir = DirAccess.open("user://")
			if dir:
				dir.copy(BACKUP_PATH, SAVE_PATH)

func delete_save() -> bool:
	var dir = DirAccess.open("user://")
	if dir and FileAccess.file_exists(SAVE_PATH):
		var err = dir.remove(SAVE_PATH)
		emit_signal("save_deleted")
		return err == OK
	return false

func get_save_info() -> Dictionary:
	if not has_save():
		return {"exists": false}
	
	var data = load_game()
	return {
		"exists": true,
		"timestamp": data.get("timestamp", 0),
		"level": data.get("player", {}).get("level", 1),
		"playtime": data.get("playtime", 0),
		"is_checkpoint": data.get("is_checkpoint", false),
		"hardcore": data.get("hardcore", true)
	}
