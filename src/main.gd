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
var victory_screen: VictoryScreen
var act_card: ActCard
var world_map: MapOverlay
var _announced_act := -1
var _interiors := {}          # house_id -> Interior
var _house_id := -1
var _house_return_pos := Vector2.ZERO
var _overworld_hero_pos := Vector2.ZERO

func _ready() -> void:
	var loading := Game.pending_load
	world = Overworld.new()
	world.name = "Overworld"
	if loading:
		Game.load_run()
		world.forced_seed = Game.saved_world_seed
	add_child(world)
	if loading and Game.saved_hero_pos != Vector2.ZERO \
			and world.is_walkable_at(Game.saved_hero_pos):
		world.hero.global_position = Game.saved_hero_pos

	_hook_autosave()

	# the overworld's cave mouth leads to dungeon depth 1; its "used" signal
	# is connected here so the dungeon becomes reachable in normal play
	var entrance := world.find_child("CaveEntrance", true, false)
	if entrance != null and entrance.has_signal("used"):
		entrance.used.connect(_on_cave_entrance)

	# every house door leads into its own walk-in interior
	for door in world.actors.find_children("HouseDoor_*", "Stairs", false, false):
		var hid := int(String(door.name).trim_prefix("HouseDoor_"))
		door.used.connect(func(_d: int): enter_house(hid))

	hud = Hud.new()
	hud.name = "Hud"
	add_child(hud)

	death_screen = DeathScreen.new()
	death_screen.name = "DeathScreen"
	add_child(death_screen)
	death_screen.retry_pressed.connect(_on_retry)
	death_screen.revive_pressed.connect(_on_revive)

	victory_screen = VictoryScreen.new()
	victory_screen.name = "VictoryScreen"
	add_child(victory_screen)
	victory_screen.continue_pressed.connect(func(): Game.change_state(Game.State.PLAYING))
	victory_screen.new_run_pressed.connect(_on_retry)
	victory_screen.menu_pressed.connect(_on_victory_menu)

	act_card = ActCard.new()
	act_card.name = "ActCard"
	add_child(act_card)

	world_map = MapOverlay.new()
	world_map.name = "MapOverlay"
	add_child(world_map)
	world_map.travel_requested.connect(_on_map_travel)

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
		if loading:
			# Continue: dress the doll from the SAVED equipped entries. The
			# doll's own ids then match the stored entries, so on_hero_gear()
			# reconciles without re-rolling or discarding the saved loot.
			Inventory.restore_doll_from_save(world.hero.doll)
		else:
			Inventory.on_hero_gear(world.hero.doll.get_gear())

	Stats.died.connect(_on_player_died)
	Game.state_changed.connect(_on_game_state)

	# a save taken inside a dungeon must drop you back into that depth
	if Game.pending_load and Game.saved_dungeon_depth > 0:
		enter_dungeon(Game.saved_dungeon_depth)
		Game.pending_load = false
	Game.pending_load = false

	# chronicle interludes: mark the act we booted into so only real progress
	# (a finished objective that crosses an act boundary) raises a card
	_announced_act = QuestLog.current_act()
	QuestLog.changed.connect(_on_quest_changed)

	if Game.seen_intro:
		Game.change_state(Game.State.PLAYING)
	else:
		cutscene.play()

func _on_quest_changed() -> void:
	if Game.state != Game.State.PLAYING:
		return
	var act := QuestLog.current_act()
	if act <= _announced_act or act <= 0:
		return
	_announced_act = act
	# let the beat land alone: drop whatever modal was open (the turn-in box)
	for ui in get_tree().get_nodes_in_group("modal_ui"):
		if ui.has_method("close"):
			ui.close()
	act_card.show_act(act)

func _unhandled_input(event: InputEvent) -> void:
	if Game.state == Game.State.DEAD or Game.state == Game.State.VICTORY:
		return
	if event.is_action_pressed("pause"):
		# pausing while the map is open just closes the map first
		if world_map.visible:
			close_map()
			get_viewport().set_input_as_handled()
			return
		Game.toggle_pause()
	elif event.is_action_pressed("map"):
		_toggle_map()
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
	if new_state != Game.State.PLAYING:
		close_map()
	if new_state == Game.State.DEAD:
		victory_screen.hide_victory()
		death_screen.show_death()
	elif new_state == Game.State.VICTORY:
		death_screen.hide_death()
		_close_modals()
		victory_screen.show_victory()
	else:
		death_screen.hide_death()
		victory_screen.hide_victory()

func _close_modals() -> void:
	for ui in get_tree().get_nodes_in_group("modal_ui"):
		if ui.has_method("close"):
			ui.close()
		else:
			ui.visible = false

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
	Game.pending_load = false
	Game.start_new_run(Game.is_hardcore)
	_reload_scene()

func _on_victory_menu() -> void:
	Game.pending_load = false
	Game.change_state(Game.State.MENU)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

## Interact with the overworld cave mouth: drop into dungeon depth 1.
func _on_cave_entrance(_direction: int) -> void:
	if dungeon != null or _house_id >= 0 or Game.state != Game.State.PLAYING:
		return
	enter_dungeon(1)

# ------------------------------------------------------------ map ----------
func _toggle_map() -> void:
	if world_map.visible:
		close_map()
		return
	if dungeon != null or _house_id >= 0 or Game.state != Game.State.PLAYING:
		return
	world_map.show_map(world)
	get_tree().paused = true   # the map reads while the world is frozen

func close_map() -> void:
	if world_map == null or not world_map.visible:
		return
	world_map.hide_map()
	get_tree().paused = false

## Fast travel: the hero walks out of the realm and into another town.
func _on_map_travel(settlement_index: int) -> void:
	close_map()
	if dungeon != null or _house_id >= 0 or world == null:
		return
	for st in world.settlements:
		if int(st["index"]) == settlement_index:
			var p: Vector2i = st["plaza"]
			var pos := Vector2(p.x * Overworld.TILE + 8.0, (p.y + 1) * Overworld.TILE + 8.0)
			world.hero.global_position = pos
			world.hero.cam.reset_smoothing()
			hud.set_biome(world.biome_at(pos))
			Sfx.play("stairs")
			hud.show_toast(I18N.tr_str("toast.travel") % I18N.tr_str("sett.name.%d" % settlement_index))
			return

# ------------------------------------------------------------ houses -------
## Step through a house door into that home's furnished Interior.
func enter_house(house_id_value: int) -> void:
	if dungeon != null or _house_id >= 0 or Game.state != Game.State.PLAYING:
		return
	_house_id = house_id_value
	_house_return_pos = world.hero.global_position
	world.spawner.spawn_enabled = false
	if world.ambient:
		world.ambient.set_process(false)
	var interior: Interior = _interiors.get(_house_id)
	if interior == null:
		interior = Interior.new()
		interior.name = "House_%d" % _house_id
		add_child(interior)
		interior.build(world.house_kind(_house_id), _house_id, world.world_seed)
		interior.exit_stairs.used.connect(func(_d: int): exit_house())
		_interiors[_house_id] = interior
	world.actors.remove_child(world.hero)
	interior.actors.add_child(world.hero)
	world.hero.global_position = interior.cell_center(interior.spawn_tile)
	world.hero.cam.limit_left = 0
	world.hero.cam.limit_top = 0
	world.hero.cam.limit_right = Interior.MAP_W * Interior.TILE
	world.hero.cam.limit_bottom = Interior.MAP_H * Interior.TILE
	var kind := world.house_kind(_house_id)
	hud.set_biome_text(I18N.tr_str("house.title." + kind))
	hud.show_toast(I18N.tr_str("toast.enter_house") % I18N.tr_str("house.name." + kind))
	Sfx.set_biome("house")

## Leave the Interior through its front door back onto the overworld.
func exit_house() -> void:
	if _house_id < 0:
		return
	var interior: Interior = _interiors[_house_id]
	interior.actors.remove_child(world.hero)
	world.actors.add_child(world.hero)
	world.hero.global_position = _house_return_pos
	world.hero.cam.limit_left = 0
	world.hero.cam.limit_top = 0
	world.hero.cam.limit_right = Overworld.WORLD_W * Overworld.TILE
	world.hero.cam.limit_bottom = Overworld.WORLD_H * Overworld.TILE
	_house_id = -1
	world.spawner.spawn_enabled = true
	if world.ambient:
		world.ambient.set_process(true)
	hud.set_biome(world.biome_at(world.hero.global_position))
	Sfx.set_biome(world.biome_at(world.hero.global_position))
