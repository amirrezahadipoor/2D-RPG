# Global game state machine + session bookkeeping.
#
# Deliberately tiny. The previous revision had two competing save systems and
# a GameManager that tried to instantiate every other autoload by hand. Here
# the autoloads are real autoloads (declared in project.godot) and this node
# only owns *state transitions*.
extends Node

enum State { BOOT, MENU, PLAYING, PAUSED, DEAD, VICTORY }

signal state_changed(new_state: State, old_state: State)
signal playtime_ticked(seconds: int)

const SAVE_PATH := "user://savegame.save"
const SAVE_FILE := "savegame.save"
const SAVE_VERSION := 1

var state: State = State.BOOT
var is_hardcore: bool = true
var playtime: float = 0.0
var last_death_was_hardcore: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[Game] boot")

func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	playtime += delta
	var whole := int(playtime)
	if whole != int(playtime - delta):
		playtime_ticked.emit(whole)

func change_state(next_state: State) -> void:
	if next_state == state:
		return
	var old := state
	state = next_state
	match next_state:
		State.PAUSED:
			get_tree().paused = true
		State.PLAYING, State.MENU, State.DEAD:
			# the tree stays unpaused while dead so the death screen is clickable
			get_tree().paused = false
	state_changed.emit(next_state, old)
	print("[Game] %s -> %s" % [State.keys()[old], State.keys()[next_state]])

func toggle_pause() -> void:
	if state == State.PLAYING:
		change_state(State.PAUSED)
	elif state == State.PAUSED:
		change_state(State.PLAYING)

func formatted_playtime() -> String:
	var total := int(playtime)
	var s := "%02d:%02d" % [total / 60, total % 60]
	return I18N.digits(s)

# ---------------------------------------------------------------- death -----
## Called once when HP hits zero. In hardcore this is the end of the run and
## the save file is deleted here, in one place only.
func die() -> void:
	if state == State.DEAD:
		return
	last_death_was_hardcore = is_hardcore
	if is_hardcore:
		wipe_save()
	change_state(State.DEAD)

func start_new_run(hardcore: bool = true) -> void:
	is_hardcore = hardcore
	playtime = 0.0
	Stats.reset_run()
	Inventory.reset_run()
	change_state(State.PLAYING)

# ----------------------------------------------------------------- save -----
## Single save path for the whole game (the previous revision had two).
func has_save() -> bool:
	var dir := DirAccess.open("user://")
	return dir != null and dir.file_exists(SAVE_FILE)

func save_run() -> bool:
	var payload := {
		"version": SAVE_VERSION,
		"hardcore": is_hardcore,
		"playtime": playtime,
		"stats": Stats.serialize(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[Game] cannot open save for writing")
		return false
	f.store_string(JSON.stringify(payload, "  "))
	f.close()
	return true

func load_run() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[Game] save file is not a JSON object")
		return false
	is_hardcore = bool(parsed.get("hardcore", true))
	playtime = float(parsed.get("playtime", 0.0))
	Stats.deserialize(parsed.get("stats", {}))
	return true

func wipe_save() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(SAVE_FILE):
		dir.remove(SAVE_FILE)
