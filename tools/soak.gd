extends Node
## Headless soak-play: drives the real game with random input for minutes,
## forces night events / dungeons / dialogs, and reports anything broken.
var main: Node
var rng := RandomNumberGenerator.new()
var held := ""
var t := 0.0
var frames := 0
var errors := 0
var phase := 0

func _ready() -> void:
	rng.seed = 424242
	Game.is_hardcore = false
	var args := OS.get_cmdline_user_args()
	if "--low" in args:
		Settings.set_quality("low")
	elif "--med" in args:
		Settings.set_quality("medium")
	main = load("res://scenes/main.tscn").instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)

func _process(delta: float) -> void:
	frames += 1
	t += delta
	if t < 1.0:
		return
	var cs: Cutscene = main.get_node_or_null("Cutscene")
	if cs and cs.active:
		cs._end()
	# random player input, like a chaotic toddler with a keyboard
	if held != "" and rng.randf() < 0.25:
		Input.action_release(held)
		held = ""
	if held == "" and rng.randf() < 0.7:
		held = ["move_up", "move_down", "move_left", "move_right"][rng.randi() % 4]
		Input.action_press(held)
	if rng.randf() < 0.12:
		Input.action_press("attack")
		Input.action_release("attack")
	if rng.randf() < 0.03:
		Input.action_press("dodge")
		Input.action_release("dodge")
	if rng.randf() < 0.02 and Stats.hp < Stats.max_hp * 0.5:
		Input.action_press("use_potion")
		Input.action_release("use_potion")
	if rng.randf() < 0.015:
		Input.action_press("interact")
		Input.action_release("interact")
	if rng.randf() < 0.008:
		for act in ["inventory", "quests", "talents"]:
			Input.action_press(act)
			Input.action_release(act)
	# scripted chaos on a timer
	if t > 20.0 and phase == 0:
		phase = 1
		Game.game_minutes = 20.0 * 60.0      # blood moon / night lights
	if t > 40.0 and phase == 1:
		phase = 2
		main.enter_dungeon(1)                 # dungeons + torches + stairs
	if t > 70.0 and phase == 2:
		phase = 3
		main.enter_dungeon(3)                 # deeper floor
	if t > 95.0 and phase == 3:
		phase = 4
		main.exit_dungeon()
	if t > 110.0 and phase == 4:
		phase = 5
		Game.game_minutes = 23.6 * 60.0       # midnight graveyard wave window
	if t > 125.0 and phase == 5:
		phase = 6
		Stats.damage(999999)                   # adventure death keeps the save
	if t > 133.0 and phase == 6:
		phase = 7
		Game.start_new_run(false)              # back to life for the final sweep
	if t > 145.0:
		_finish()

func _finish() -> void:
	print("SOAK frames=", frames, " fps~=", snapped(float(frames) / t, 0.1))
	print("SOAK nodes=", get_tree().get_node_count(),
		" enemies=", get_tree().get_nodes_in_group("enemy").size(),
		" orphans=", get_tree().get_nodes_in_group("projectile").size())
	print("SOAK state=", Game.state, " day=", Game.hour(), " gold=", Stats.gold,
		" hp=", Stats.hp, "/", Stats.max_hp, " lvl=", Stats.level)
	print("SOAK objects=", Performance.get_monitor(Performance.OBJECT_COUNT),
		" nodes2=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("SOAK DONE")
	get_tree().quit(0)
