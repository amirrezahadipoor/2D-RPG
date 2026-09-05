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
var dungeon: Dungeon = null
var touch: TouchUI = null
var _overworld_hero_pos := Vector2.ZERO

func _ready() -> void:
	world = Overworld.new()
	world.name = "Overworld"
	if Game.pending_load:
		Game.load_run()
		world.forced_seed = Game.saved_world_seed
	add_child(world)
	if Game.pending_load and Game.saved_hero_pos != Vector2.ZERO \
			and world.is_walkable_at(Game.saved_hero_pos):
		world.hero.global_position = Game.saved_hero_pos
	Game.pending_load = false

	_hook_autosave()

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)

	death_screen = DeathScreen.new()
	death_screen.name = "DeathScreen"
	add_child(death_screen)
	death_screen.retry_pressed.connect(_on_retry)
	death_screen.revive_pressed.connect(_on_revive)

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

	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)

	touch = TouchUI.new()
	touch.name = "TouchUI"
	add_child(touch)

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
	world.biome_changed.connect(func(b): Sfx.set_biome(b))

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

# -------------------------------------------------------------- dungeons ----
func enter_dungeon(raw_depth: int) -> void:
	var depth_value := clampi(raw_depth, 1, Dungeon.MAX_DEPTH)
	if dungeon == null:
		_overworld_hero_pos = world.hero.global_position
		world.spawner.spawn_enabled = false
		world.ambient.set_process(false)
	var hero := world.hero if dungeon == null else dungeon.hero
	if dungeon != null:
		dungeon.actors.remove_child(hero)
		dungeon.queue_free()
	else:
		world.actors.remove_child(hero)
	dungeon = Dungeon.new()
	dungeon.name = "Dungeon"
	add_child(dungeon)
	dungeon.build(depth_value, world.world_seed)
	dungeon.actors.add_child(hero)
	dungeon.hero = hero
	hero.global_position = dungeon.stairs_up + Vector2(0, 10)
	hero.cam.limit_left = 0
	hero.cam.limit_top = 0
	hero.cam.limit_right = Dungeon.W * Dungeon.TILE
	hero.cam.limit_bottom = Dungeon.H * Dungeon.TILE
	for node in dungeon.actors.get_children():
		if node is Stairs:
			node.used.connect(_on_stairs)
	dungeon.secret_opened.connect(_on_secret)
	hud.set_biome_text("%s %s" % [I18N.tr_str("biome.dungeon"), I18N.num(depth_value)])
	hud.show_toast(I18N.tr_str("toast.depth") % I18N.num(depth_value))
	Sfx.set_biome("dungeon")

func exit_dungeon() -> void:
	if dungeon == null:
		return
	var hero := dungeon.hero
	dungeon.actors.remove_child(hero)
	dungeon.queue_free()
	dungeon = null
	world.actors.add_child(hero)
	hero.global_position = _overworld_hero_pos
	hero.cam.limit_right = Overworld.WORLD_W * Overworld.TILE
	hero.cam.limit_bottom = Overworld.WORLD_H * Overworld.TILE
	world.spawner.spawn_enabled = true
	world.ambient.set_process(true)
	hud.set_biome(world.biome_at(hero.global_position))
	Sfx.set_biome(world.biome_at(hero.global_position))

func _on_secret() -> void:
	hud.show_toast(I18N.tr_str("toast.secret"))

func _on_stairs(direction: int) -> void:
	Game.save_checkpoint()
	Sfx.play("stairs")
	if direction > 0:
		enter_dungeon(dungeon.depth + 1)
	else:
		exit_dungeon()

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
## Autosave rhythm: every new in-game day, every level, every stair.
func _hook_autosave() -> void:
	Game.hour_changed.connect(func(h: int, _d: int):
		if h == 8:
			Game.save_checkpoint())
	Stats.level_changed.connect(func(_l: int, _x: int, _n: int): Game.save_checkpoint())

func _reload_scene() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_revive() -> void:
	Game.pending_load = true
	_reload_scene()

func _on_retry() -> void:
	if not Game.is_hardcore:
		Game.wipe_save()   # abandoning an adventure run deletes it
	Game.start_new_run(Game.is_hardcore)
	_reload_scene()
	get_tree().reload_current_scene()
