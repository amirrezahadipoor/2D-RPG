# Game Manager - Phase 11 Polish - Complete Fix
# Central game flow: new game, load, pause, death, win, settings
# Offline, deterministic, hardcore-aware

extends Node
class_name GameManager

enum GameState { MENU, PLAYING, PAUSED, CUTSCENE, INVENTORY, DIALOGUE, DEAD, VICTORY }

var current_state: GameState = GameState.MENU
var playtime: float = 0.0
var is_hardcore: bool = true
var player_level: int = 1

signal state_changed(new_state: GameState, old_state: GameState)
signal playtime_updated(time: float)
signal intro_finished()
signal game_started()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load hardcore setting
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		is_hardcore = cfg.get_value("game", "hardcore", true)
	
	# Connect to SaveManager if exists
	_setup_autoloads()

func _setup_autoloads() -> void:
	# Ensure all required nodes exist
	if not has_node("/root/PlayerStats"):
		var ps = Node.new()
		ps.set_script(load("res://src/core/player_stats.gd"))
		ps.name = "PlayerStats"
		add_child(ps)
	
	if not has_node("/root/CombatManager"):
		var cm = Node.new()
		cm.set_script(load("res://src/core/combat_manager.gd"))
		cm.name = "CombatManager"
		add_child(cm)
	
	if not has_node("/root/InventoryManager"):
		var im = Node.new()
		im.set_script(load("res://src/core/inventory_manager.gd"))
		im.name = "InventoryManager"
		add_child(im)
	
	if not has_node("/root/WorldManager"):
		var wm = Node.new()
		wm.set_script(load("res://src/core/world_manager.gd"))
		wm.name = "WorldManager"
		add_child(wm)
	
	if not has_node("/root/DungeonManager"):
		var dm = Node.new()
		dm.set_script(load("res://src/core/dungeon_manager.gd"))
		dm.name = "DungeonManager"
		add_child(dm)
	
	if not has_node("/root/QuestManager"):
		var qm = Node.new()
		qm.set_script(load("res://src/core/quest_manager.gd"))
		qm.name = "QuestManager"
		add_child(qm)
	
	if not has_node("/root/TalentTree"):
		var tt = Node.new()
		tt.set_script(load("res://src/core/talent_tree.gd"))
		tt.name = "TalentTree"
		add_child(tt)
	
	print("[GameManager] All game systems initialized")

func _process(delta: float) -> void:
	if current_state == GameState.PLAYING:
		playtime += delta
		if int(playtime) % 10 == 0:
			emit_signal("playtime_updated", playtime)

func change_state(new_state: GameState) -> void:
	var old := current_state
	current_state = new_state
	emit_signal("state_changed", new_state, old)
	match new_state:
		GameState.PAUSED:
			get_tree().paused = true
		GameState.PLAYING:
			get_tree().paused = false
		GameState.DEAD:
			_handle_death()
		GameState.VICTORY:
			_handle_victory()
	print("[GameManager] state ", GameState.keys()[old], " -> ", GameState.keys()[new_state])

func new_game(hardcore: bool = true) -> void:
	is_hardcore = hardcore
	playtime = 0.0
	player_level = 1
	
	# Clear save if exists
	_delete_save()
	
	# Reset all game systems
	_reset_game_systems()
	
	# Initialize player stats
	_initialize_player()
	
	# Generate world
	_generate_world()
	
	# Play intro cutscene
	_play_intro()

func _play_intro() -> void:
	change_state(GameState.CUTSCENE)
	
	# Get intro controller
	if has_node("/root/Main/IntroController"):
		get_node("/root/Main/IntroController").play_intro()
	else:
		# Skip intro in headless/test mode
		on_intro_finished()

func on_intro_finished() -> void:
	change_state(GameState.PLAYING)
	emit_signal("intro_finished")
	emit_signal("game_started")
	print("[GameManager] Game started!")

func _initialize_player() -> void:
	if has_node("/root/PlayerStats"):
		var stats = get_node("/root/PlayerStats")
		stats.level = 1
		stats.xp = 0
		stats.xp_to_next = 100
		stats.hp = stats.max_hp
		stats.stamina = stats.max_stamina
		stats.gold = 50  # Starting gold

func _generate_world() -> void:
	if has_node("/root/WorldManager"):
		get_node("/root/WorldManager").generate_world()

func load_game() -> bool:
	if not has_save():
		print("[GameManager] no save to load")
		return false
	
	var data = _load_save_data()
	if data.is_empty():
		return false
	
	playtime = data.get("playtime", 0.0)
	player_level = data.get("player", {}).get("level", 1)
	is_hardcore = data.get("hardcore", true)
	
	# Load all systems
	_load_game_systems(data)
	
	change_state(GameState.PLAYING)
	emit_signal("game_started")
	print("[GameManager] loaded level ", player_level, " playtime ", playtime)
	return true

func _load_save_data() -> Dictionary:
	var path = "user://savegame.save"
	if not FileAccess.file_exists(path):
		return {}
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	
	var json_str = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_str) != OK:
		return {}
	
	return json.data if json.data is Dictionary else {}

func save_game(is_checkpoint: bool = false) -> bool:
	var data := _collect_game_state()
	data["playtime"] = playtime
	data["state"] = current_state
	return _save_game_data(data, is_checkpoint)

func _save_game_data(data: Dictionary, is_checkpoint: bool) -> bool:
	var path = "user://savegame.save"
	data["timestamp"] = Time.get_unix_time_from_system()
	data["version"] = "1.0-complete"
	data["is_checkpoint"] = is_checkpoint
	
	# Backup
	if FileAccess.file_exists(path):
		var dir = DirAccess.open("user://")
		if dir:
			dir.copy(path, "user://savegame_backup.save")
	
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[GameManager] cannot open save file")
		return false
	
	var json_str = JSON.stringify(data)
	file.store_string(json_str)
	file.close()
	
	print("[GameManager] game saved, size=", json_str.length())
	return true

func _collect_game_state() -> Dictionary:
	var player_data := {}
	if has_node("/root/PlayerStats"):
		player_data = get_node("/root/PlayerStats").get_save_data()
	
	var inventory_data := {}
	if has_node("/root/InventoryManager"):
		inventory_data = get_node("/root/InventoryManager").get_save_data()
	
	var world_data := {}
	if has_node("/root/WorldManager"):
		world_data = get_node("/root/WorldManager").get_save_data()
	
	var quest_data := {}
	if has_node("/root/QuestManager"):
		quest_data = get_node("/root/QuestManager").get_save_data()
	
	var talent_data := {}
	if has_node("/root/TalentTree"):
		talent_data = get_node("/root/TalentTree").get_save_data()
	
	var dungeon_data := {}
	if has_node("/root/DungeonManager"):
		dungeon_data = get_node("/root/DungeonManager").get_save_data()
	
	return {
		"player": player_data,
		"inventory": inventory_data,
		"world": world_data,
		"quests": quest_data,
		"talents": talent_data,
		"dungeons": dungeon_data,
		"hardcore": is_hardcore
	}

func _load_game_systems(data: Dictionary) -> void:
	if has_node("/root/PlayerStats"):
		get_node("/root/PlayerStats").load_save_data(data.get("player", {}))
	
	if has_node("/root/InventoryManager"):
		get_node("/root/InventoryManager").load_save_data(data.get("inventory", {}))
	
	if has_node("/root/WorldManager"):
		get_node("/root/WorldManager").load_save_data(data.get("world", {}))
	
	if has_node("/root/QuestManager"):
		get_node("/root/QuestManager").load_save_data(data.get("quests", {}))
	
	if has_node("/root/TalentTree"):
		get_node("/root/TalentTree").load_save_data(data.get("talents", {}))
	
	if has_node("/root/DungeonManager"):
		get_node("/root/DungeonManager").load_save_data(data.get("dungeons", {}))

func _reset_game_systems() -> void:
	if has_node("/root/PlayerStats"):
		var stats = get_node("/root/PlayerStats")
		stats.level = 1
		stats.xp = 0
		stats.hp = stats.max_hp
		stats.stamina = stats.max_stamina
		stats.gold = 50
	
	if has_node("/root/CombatManager"):
		get_node("/root/CombatManager").clear_all_enemies()
	
	if has_node("/root/InventoryManager"):
		get_node("/root/InventoryManager").inventory.clear()
		get_node("/root/InventoryManager").equipment = {
			"weapon": null, "helmet": null, "chest": null,
			"legs": null, "boots": null, "accessory": null
		}
	
	if has_node("/root/QuestManager"):
		get_node("/root/QuestManager").active_quests.clear()
		get_node("/root/QuestManager").completed_quests.clear()
	
	if has_node("/root/TalentTree"):
		get_node("/root/TalentTree").talent_points_available = 0
		get_node("/root/TalentTree").learned_talents.clear()

func _delete_save() -> void:
	var path = "user://savegame.save"
	if FileAccess.file_exists(path):
		var dir = DirAccess.open("user://")
		if dir:
			dir.remove(path)

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)

func _handle_death() -> void:
	get_tree().paused = true
	
	if is_hardcore:
		_delete_save()
		print("[GameManager] HARDCORE DEATH - save deleted")
	
	# Show death screen
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").show_death_screen(is_hardcore)

func _handle_victory() -> void:
	save_game(true)
	if has_node("/root/UIManager"):
		get_node("/root/UIManager").show_victory_screen()

func quit_to_menu() -> void:
	change_state(GameState.MENU)
	get_tree().paused = false

func has_save() -> bool:
	return FileAccess.file_exists("user://savegame.save")

func get_formatted_playtime() -> String:
	var total := int(playtime)
	var h := total / 3600
	var m := (total % 3600) / 60
	var s := total % 60
	
	var time_str = "%02d:%02d:%02d" % [h, m, s]
	
	if has_node("/root/LocalizationManager"):
		var lm = get_node("/root/LocalizationManager")
		if lm.get_locale() == "fa":
			return lm.to_persian_numerals(time_str)
	
	return time_str

func set_hardcore(enabled: bool) -> void:
	is_hardcore = enabled
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		pass
	cfg.set_value("game", "hardcore", enabled)
	cfg.save("user://settings.cfg")
