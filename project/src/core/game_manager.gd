# Game Manager - Phase 11 Polish
# Central game flow: new game, load, pause, death, win, settings
# Offline, deterministic, hardcore-aware

extends Node
# class_name GameManager

enum GameState { MENU, PLAYING, PAUSED, CUTSCENE, INVENTORY, DIALOGUE, DEAD, VICTORY }

var current_state: GameState = GameState.MENU
var playtime: float = 0.0
var is_hardcore: bool = true
var player_level: int = 1

@onready var save_mgr: SaveManager = $SaveManager if has_node("SaveManager") else get_node_or_null("/root/SaveManager")
@onready var polish: Node = get_node_or_null("/root/PolishManager")

signal state_changed(new_state: GameState, old_state: GameState)
signal playtime_updated(time: float)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Load hardcore setting
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		is_hardcore = cfg.get_value("game", "hardcore", true)

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
	if save_mgr and save_mgr.has_method("delete_save"):
		save_mgr.delete_save()
	# Reset other managers
	get_tree().call_group("reset_on_new_game", "reset_for_new_game")
	change_state(GameState.CUTSCENE) # play intro cutscene
	# After cutscene, go to PLAYING
	await get_tree().create_timer(0.1).timeout # placeholder for cutscene
	if current_state == GameState.CUTSCENE:
		change_state(GameState.PLAYING)
	print("[GameManager] new game hardcore=", hardcore)

func load_game() -> bool:
	if not save_mgr or not save_mgr.has_save():
		print("[GameManager] no save to load")
		return false
	var data: Dictionary = save_mgr.load_game()
	if data.is_empty():
		return false
	playtime = data.get("playtime", 0.0)
	player_level = data.get("player", {}).get("level", 1)
	is_hardcore = data.get("hardcore", true)
	# Apply to other systems via groups
	get_tree().call_group("loadable", "apply_save_data", data)
	change_state(GameState.PLAYING)
	print("[GameManager] loaded level ", player_level, " playtime ", playtime)
	return true

func save_game(is_checkpoint: bool = false) -> bool:
	if not save_mgr:
		return false
	var data := save_mgr.collect_game_state() if save_mgr.has_method("collect_game_state") else {}
	data["playtime"] = playtime
	data["state"] = current_state
	return save_mgr.save_game(data, is_checkpoint)

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)

func _handle_death() -> void:
	get_tree().paused = true
	if save_mgr and save_mgr.has_method("on_player_death"):
		save_mgr.on_player_death()
	# Show death screen via UIManager
	if has_node("/root/UIManager") and get_node("/root/UIManager").has_method("show_death_screen"):
		get_node("/root/UIManager").show_death_screen(is_hardcore)

func _handle_victory() -> void:
	save_game(true)
	if has_node("/root/UIManager") and get_node("/root/UIManager").has_method("show_victory_screen"):
		get_node("/root/UIManager").show_victory_screen()

func quit_to_menu() -> void:
	change_state(GameState.MENU)
	get_tree().paused = false

func get_formatted_playtime() -> String:
	var total := int(playtime)
	var h := total / 3600
	var m := (total % 3600) / 60
	var s := total % 60
	# Use Persian numerals if locale is FA
	if has_node("/root/LocalizationManager") and get_node("/root/LocalizationManager").get_locale() == "fa":
		return _to_persian_numbers("%02d:%02d:%02d" % [h, m, s])
	return "%02d:%02d:%02d" % [h, m, s]

func _to_persian_numbers(s: String) -> String:
	if has_node("/root/LocalizationManager") and get_node("/root/LocalizationManager").has_method("to_persian_numerals"):
		return get_node("/root/LocalizationManager").to_persian_numerals(s)
	return s

func set_hardcore(enabled: bool) -> void:
	is_hardcore = enabled
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("game", "hardcore", enabled)
	cfg.save("user://settings.cfg")
