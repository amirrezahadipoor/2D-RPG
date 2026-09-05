# Scene bootstrap: overworld + every screen + global hotkeys + story intro.
extends Node2D

var world: Overworld
var hud: Hud
var death_screen: DeathScreen
var inv_screen: InventoryScreen
var journal: JournalUI
var talents: TalentsUI
var dialogue: DialogueUI
var cutscene: Cutscene
var events: WorldEvents

func _ready() -> void:
	world = Overworld.new()
	world.name = "Overworld"
	add_child(world)

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)

	death_screen = DeathScreen.new()
	death_screen.name = "DeathScreen"
	add_child(death_screen)
	death_screen.retry_pressed.connect(_on_retry)

	inv_screen = InventoryScreen.new()
	inv_screen.name = "InventoryScreen"
	add_child(inv_screen)

	journal = JournalUI.new()
	journal.name = "JournalUI"
	add_child(journal)

	talents = TalentsUI.new()
	talents.name = "TalentsUI"
	add_child(talents)

	dialogue = DialogueUI.new()
	dialogue.name = "DialogueUI"
	add_child(dialogue)

	cutscene = Cutscene.new()
	cutscene.name = "Cutscene"
	add_child(cutscene)
	cutscene.finished.connect(func(): Game.change_state(Game.State.PLAYING))

	events = WorldEvents.new()
	events.name = "Events"
	add_child(events)
	events.world = world

	Inventory.denied.connect(func(key): hud.show_toast(I18N.tr_str(key)))
	QuestLog.toast.connect(func(key): hud.show_toast(I18N.tr_str(key)))

	world.biome_changed.connect(hud.set_biome)
	world.biome_changed.connect(func(b): print("[Main] biome -> ", b))

	# push initial gear to the HUD once the hero exists
	await get_tree().process_frame
	if world.hero:
		hud.set_gear(world.hero.doll.get_gear())
		world.hero.gear_changed.connect(hud.set_gear)
		world.hero.gear_changed.connect(Inventory.on_hero_gear)
		Inventory.on_hero_gear(world.hero.doll.get_gear())

	Stats.died.connect(_on_player_died)
	Game.state_changed.connect(_on_game_state)

	if Game.seen_intro:
		Game.change_state(Game.State.PLAYING)
	else:
		cutscene.play()

func _unhandled_input(event: InputEvent) -> void:
	if Game.state == Game.State.DEAD:
		return
	if event.is_action_pressed("pause"):
		Game.toggle_pause()
	elif event.is_action_pressed("inventory"):
		inv_screen.toggle()
	elif event.is_action_pressed("quests"):
		journal.toggle()
	elif event.is_action_pressed("talents"):
		talents.toggle()
	elif event.is_action_pressed("locale"):
		I18N.toggle_locale()

# ----------------------------------------------------------------- death ----
func _on_player_died() -> void:
	Game.die()

func _on_game_state(new_state: int, _old_state: int) -> void:
	if new_state == Game.State.DEAD:
		death_screen.show_death()
	else:
		death_screen.hide_death()

## Hardcore: the save was already deleted inside Game.die(), so "Start Over"
## simply rebuilds a fresh world with reset stats.
func _on_retry() -> void:
	Game.start_new_run(Game.is_hardcore)
	get_tree().reload_current_scene()
