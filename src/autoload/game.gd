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

var state: State = State.BOOT
var is_hardcore: bool = true
var playtime: float = 0.0

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
		State.PLAYING:
			get_tree().paused = false
		State.MENU:
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
