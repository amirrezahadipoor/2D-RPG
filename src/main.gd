# Scene bootstrap: owns the overworld + HUD and the global hotkeys.
extends Node2D

var world: Overworld
var hud: Hud

func _ready() -> void:
	world = Overworld.new()
	world.name = "Overworld"
	add_child(world)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)

	world.biome_changed.connect(hud.set_biome)
	world.biome_changed.connect(func(b): print("[Main] biome -> ", b))

	# push initial gear to the HUD once the hero exists
	await get_tree().process_frame
	if world.hero:
		hud.set_gear(world.hero.doll.get_gear())
		world.hero.gear_changed.connect(hud.set_gear)
	Game.change_state(Game.State.PLAYING)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Game.toggle_pause()
	elif event.is_action_pressed("locale"):
		I18N.toggle_locale()
