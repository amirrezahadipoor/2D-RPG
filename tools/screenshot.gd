# Renders the real game under a virtual display and saves PNGs.
#   xvfb-run -s "-screen 0 1440x810x24" godot --path . res://tools/screenshot.tscn
#
# This exists because "it compiles" is not evidence that a game LOOKS right.
extends Node

const OUT_DIR := "/tmp/shots/"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	run.call_deferred()

func run() -> void:
	# NOTE: add as a child of root, NOT change_scene_to_file(): changing the
	# scene frees the current scene, which is this very node, and get_tree()
	# then returns null mid-coroutine.
	Settings.tutorial_seen = false   # capture the first-run flow every time
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.name = "Main"
	get_tree().root.add_child(main)
	for i in 6:
		await get_tree().process_frame

	# the story intro must not eat the early captures: end it, replay it later
	var cs0: Cutscene = main.get_node_or_null("Cutscene")
	if cs0 and cs0.active:
		cs0._end()

	# first-run tutorial evidence, then get it out of the way of later shots
	var tut0 := main.get_node_or_null("Tutorial") as Tutorial
	if tut0:
		tut0._auto = false
		tut0.open()
		for i in 4:
			await get_tree().process_frame
		await _grab("00_tutorial")
		tut0.close()

	# captures always show the game at its best: full quality tier
	Settings.set_quality("high")
	# deterministic capture: the world is populated by hand further down
	var world: Overworld = _world()
	if world and world.spawner:
		world.spawner.spawn_enabled = false

	await _grab("01_boot")

	# walk right for a bit
	Input.action_press("move_right", 1.0)
	Input.action_press("move_down", 0.6)
	for i in 40:
		await get_tree().physics_frame
	Input.action_release("move_right")
	Input.action_release("move_down")
	await _grab("02_walked")

	# swap some gear so the paper-doll change is visible, then attack
	var hero := _hero()
	if hero:
		hero.doll.equip("helmet", "wizard_hat")
		hero.doll.equip("chest", "iron_plate")
		hero.doll.equip("accessory", "red_cloak")
		hero.doll.equip("weapon", "battle_axe")
	for i in 4:
		await get_tree().process_frame
	await _grab("03_geared")

	Input.action_press("attack", 1.0)
	for i in 6:
		await get_tree().physics_frame
	await _grab("04_attack")
	Input.action_release("attack")

	# Persian / RTL
	I18N.set_locale("fa")
	for i in 4:
		await get_tree().process_frame
	await _grab("05_persian")
	I18N.set_locale("en")

	print("[dbg] pre-combat hp=%d state=%d enemies=%d armor=%d" % [Stats.hp, Game.state, _count_enemies(), Stats.armor])
	# ---- real combat: enemies that chase, a swing that connects, juice ----
	if hero and world and world.spawner:
		world.spawner.spawn_enabled = false
		world.spawner.spawn("goblin", hero.global_position + Vector2(20, 6), 2)
		world.spawner.spawn("slime", hero.global_position + Vector2(-24, 12), 1)
		world.spawner.spawn("bat", hero.global_position + Vector2(8, -18), 1)
		for i in 36:
			await get_tree().physics_frame
		hero.facing = "right"
		Input.action_press("attack", 1.0)
		for i in 3:
			await get_tree().physics_frame
		print("[dbg] at-combat hp=%d state=%d enemies=%d" % [Stats.hp, Game.state, _count_enemies()])
		await _grab("06_combat")
		Input.action_release("attack")
		for i in 20:
			await get_tree().physics_frame

	# ---- death + hardcore permadeath screen ----
	Game.save_run()
	Stats.damage(99999)
	for i in 12:
		await get_tree().process_frame
	await _grab("07_death")

	I18N.set_locale("fa")
	for i in 8:
		await get_tree().process_frame
	await _grab("08_death_fa")
	I18N.set_locale("en")

	# ---- inventory with big icons + rarity, and chest loot on the ground ----
	I18N.set_locale("en")
	Game.start_new_run(true)   # leave the DEAD state so the screens are clean
	# no scene reload here, so re-sync the worn entries with the doll by hand
	if hero:
		Inventory.on_hero_gear(hero.doll.get_gear())
	for node in get_tree().get_nodes_in_group("pickup"):
		node.queue_free()
	for i in 4:
		await get_tree().process_frame
	# fill the bag directly (not via add()) so no "bag full" toast fires here
	for i in 7:
		var demo_entry: Dictionary = Inventory.roll_entry(ItemGen.random_id(Inventory.rng), 0.45)
		demo_entry["weight"] = 1
		Inventory.bag.append(demo_entry)
	Inventory.changed.emit()
	var inv: InventoryScreen = null
	for child in get_tree().root.get_children():
		var node := child.get_node_or_null("InventoryScreen")
		if node is InventoryScreen:
			inv = node
	if inv:
		inv.selected = 2
		inv.open()
		for i in 6:
			await get_tree().process_frame
		await _grab("09_inventory")
		inv.close()
		Inventory.bag.clear()
		Inventory.changed.emit()

	if hero and world:
		var chest := Chest.new()
		world.actors.add_child(chest)
		chest.global_position = hero.global_position + Vector2(58, 16)
		for i in 4:
			await get_tree().physics_frame
		# open it by hand so the hero stays put, then freeze the drops in place
		chest.open()
		for i in 10:
			await get_tree().physics_frame
		var offs := [Vector2(-18, -8), Vector2(16, -12), Vector2(-4, 12)]
		var ps := get_tree().get_nodes_in_group("pickup")
		for i in ps.size():
			ps[i].freeze = true
			if i < offs.size():
				ps[i].global_position = chest.global_position + offs[i]
		for i in 6:
			await get_tree().process_frame
		await _grab("10_loot")

	# ---- story intro slide (pixel cutscene) ----
	var main_node := get_tree().root.get_node_or_null("Main")
	var cs: Cutscene = main_node.get_node_or_null("Cutscene") if main_node else null
	if cs:
		cs.play()
		cs._slide = 3
		cs._apply_slide()
		cs._reveal = 300.0
		for i in 6:
			await get_tree().process_frame
		await _grab("11_story")
		cs._end()

	# ---- village at noon with people on their schedule ----
	if hero and world and not world.settlements.is_empty():
		var plaza: Vector2i = world.settlements[0]["plaza"]
		hero.global_position = Vector2(plaza.x * 16 + 8, (plaza.y + 2) * 16)
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()   # stragglers from the combat phase would follow us in
		Game.game_minutes = float(Game.day()) * 1440.0 + 12.0 * 60.0
		for i in 90:
			await get_tree().physics_frame
		await _grab("12_village")

		# ---- a roadside shrine (POI) ----
		var shrine: Node2D = null
		for node in get_tree().get_nodes_in_group("interact"):
			if node is Shrine:
				shrine = node
				break
		if shrine:
			hero.global_position = shrine.global_position + Vector2(0, 22)
			for i in 40:
				await get_tree().physics_frame
			await _grab("12b_shrine")

		# ---- house facade + lit windows (Phase A1) ----
		if world and not world.settlements.is_empty():
			var h0: Rect2i = world._house_rects(world.settlements[0])[0]
			hero.global_position = Vector2((h0.position.x + h0.size.x / 2) * 16.0 + 8.0,
					h0.end.y * 16.0 + 8.0)
			for i in 45:
				await get_tree().physics_frame
			await _grab("12c_facade")
			world._discover_t = 999.0   # freeze the day/night window tick
			world.set_windows_lit(true)
			await get_tree().create_timer(0.2).timeout
			await _grab("12d_windows_lit")
			world.set_windows_lit(false)
			world._discover_t = 0.0

		# ---- a hand-built landmark (Phase A2) ----
		if world and not world.landmarks.is_empty():
			var lm: Dictionary = world.landmarks[0]
			hero.global_position = Vector2(lm["pos"].x * 16.0 + 8.0, lm["pos"].y * 16.0 + 56.0)
			for i in 45:
				await get_tree().physics_frame
			await _grab("12e_landmark")

		# ---- animated shore foam + biome blend (Phase A3) ----
		if world and not world._shore_cells.is_empty():
			var sh: Vector2i = world._shore_cells[world._shore_cells.size() / 2]
			hero.global_position = Vector2(sh.x * 16.0 + 8.0, (sh.y - 2) * 16.0)
			for i in 45:
				await get_tree().physics_frame
			await _grab("12f_shore")

		# ---- moonlight grade + lit windows (Phase A6) ----
		if world and not world.settlements.is_empty():
			var keep_min: float = Game.game_minutes
			Game.game_minutes = 23.0 * 60.0
			var plz: Vector2i = world.settlements[0]["plaza"]
			hero.global_position = Vector2(plz.x * 16 + 8, (plz.y + 3) * 16)
			for i in 45:
				await get_tree().physics_frame
			await _grab("12g_night_village")

		# ---- rain (Phase B2) ----
		if world and world.weather:
			var keep_rain: float = Game.game_minutes
			Game.game_minutes = (1.0 * 1440.0) + 12.0 * 60.0
			world._tick_weather()
			await get_tree().create_timer(0.3).timeout
			await _grab("12h_rain")
			Game.game_minutes = keep_rain
			world._tick_weather()
			world._apply_night()

		# ---- dialogue with the first NPC ----
		var dlg: DialogueUI = main_node.get_node_or_null("DialogueUI") if main_node else null
		if dlg and not world.npcs.is_empty():
			var npc: NPC = world.npcs[0]
			npc.global_position = hero.global_position + Vector2(10, 0)
			for i in 4:
				await get_tree().physics_frame
			dlg.open_with(npc)
			dlg._reveal = 400.0
			for i in 4:
				await get_tree().process_frame
			await _grab("13_dialogue")
			dlg.close()

	# ---- journal with live quests ----
	QuestLog.start_side(0)
	QuestLog.start_side(4)
	QuestLog.start_side(8)
	var journal: JournalUI = main_node.get_node_or_null("JournalUI") if main_node else null
	if journal:
		journal.toggle()
		for i in 4:
			await get_tree().process_frame
		await _grab("14_journal")
		journal.toggle()

	# ---- graveyard at night ----
	if world:
		var grave := Vector2(-1, -1)
		for y in range(0, Overworld.WORLD_H, 2):
			for x in range(0, Overworld.WORLD_W, 2):
				if world.biome_at(Vector2(x * 16 + 8, y * 16 + 8)) == "graveyard":
					grave = Vector2(x * 16 + 8, y * 16 + 8)
					break
			if grave.x >= 0:
				break
		if grave.x >= 0:
			hero.global_position = grave
			Game.game_minutes = float(Game.day()) * 1440.0 + 23.0 * 60.0
			for i in 40:
				await get_tree().physics_frame
			await _grab("15_night_grave")

	# ---- dungeon depth 2: torches, rock, monsters ----
	if main_node and main_node.has_method("enter_dungeon") and hero:
		Game.game_minutes = float(Game.day()) * 1440.0 + 12.0 * 60.0
		main_node.enter_dungeon(2)
		for i in 150:
			await get_tree().physics_frame
		if main_node.dungeon != null:
			var dh: Hero = main_node.dungeon.hero
			if dh:
				dh.global_position = main_node.dungeon.stairs_up + Vector2(0, 12)
				var skel := Enemy.new()
				main_node.dungeon.actors.add_child(skel)
				skel.setup("skeleton", 3)
				skel.global_position = main_node.dungeon.stairs_up + Vector2(38, 14)
				skel.speed = 0.0
				skel.detect = 0.0
			for i in 6:
				await get_tree().process_frame
			await _grab("16_dungeon")

		# ---- boss of the depth + boss bar (Phase C1) ----
		var dun: Node = get_tree().root.find_child("Dungeon", true, false)
		if dun != null and dun.boss != null:
			hero.global_position = dun.boss.global_position + Vector2(0, 70.0)
			for i in 45:
				await get_tree().physics_frame
			await _grab("16b_boss")
		main_node.exit_dungeon()
		for i in 6:
			await get_tree().physics_frame

	# ---- merchant shop page ----
	if main_node and world:
		var merchant: NPC = null
		for n in world.npcs:
			if n.role_name == "merchant":
				merchant = n
				break
		if merchant:
			hero.global_position = merchant.global_position + Vector2(22, 6)
			for i in 8:
				await get_tree().physics_frame
			var dlg2: DialogueUI = main_node.dialogue
			Stats.add_gold(300)
			dlg2.npc = merchant
			dlg2._make_shop()
			dlg2._pages = [{"text": "", "mode": "shop"}]
			dlg2._page = 0
			dlg2._apply_page()
			dlg2.visible = true
			for i in 6:
				await get_tree().process_frame
			await _grab("17_shop")

		# ---- crafting bench book (Phase C3) ----
		var cui: Node = get_tree().get_first_node_in_group("craft_ui")
		if cui != null:
			Inventory.add({"id": "iron", "qty": 3})
			Inventory.add({"id": "hide", "qty": 2})
			cui.open()
			for i in 6:
				await get_tree().process_frame
			await _grab("17b_craft")
			cui.close()
			dlg2.close()

	# ---- hidden chamber: cracked wall shattered, relic chest glowing ----
	if main_node and main_node.dungeon == null and hero:
		main_node.enter_dungeon(3)
		for i in 10:
			await get_tree().physics_frame
		var dg: Dungeon = main_node.dungeon
		if dg and dg.secret_rooms.size() > 0:
			for node in dg.actors.get_children():
				if node is SecretWall:
					node.break_open()
			for i in 8:
				await get_tree().process_frame
			var ch: Rect2i = dg.secret_rooms[0]
			var dh2: Hero = dg.hero
			if dh2:
				dh2.global_position = dg._pos_of(Vector2i(ch.position.x + 1, ch.end.y - 1))
			for i in 30:
				await get_tree().physics_frame
			await _grab("18_secret")
		main_node.exit_dungeon()
		for i in 6:
			await get_tree().physics_frame

	# ---- bestiary lineup: the new species, one of them elite ----
	if world and hero:
		var types := ["wolf", "shaman", "golem", "demon", "orc"]
		var offs := [Vector2(-52, 14), Vector2(-26, 22), Vector2(4, 24),
			Vector2(34, 18), Vector2(58, 26)]
		var made: Array = []
		for i in types.size():
			var e := Enemy.new()
			world.actors.add_child(e)
			e.setup(types[i], 3)
			e.speed = 0.0
			e.detect = 0.0
			e.global_position = hero.global_position + offs[i]
			if i == 2:
				e.mark_elite()
			made.append(e)
		for i in 20:
			await get_tree().physics_frame
		await _grab("19_bestiary")
		for e in made:
			if is_instance_valid(e):
				e.queue_free()
		for i in 6:
			await get_tree().physics_frame

	# ---- 20: main menu (night sky, title, entries) ----
	var mm := MainMenu.new()
	mm.name = "MainMenuShot"
	get_tree().root.add_child.call_deferred(mm)
	for i in 4:
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	await _grab("20_menu")
	# ---- 20b: the same menu in Persian (RTL) ----
	I18N.set_locale("fa")
	for i in 12:
		await get_tree().process_frame
	await _grab("24_menu_fa")
	I18N.set_locale("en")
	for i in 6:
		await get_tree().process_frame
	# ---- 21: settings overlay on top of the menu ----
	mm._open_settings()
	for i in 10:
		await get_tree().process_frame
	await _grab("21_settings")
	mm.settings_ui.close()
	mm.queue_free()
	for i in 6:
		await get_tree().process_frame
	# ---- 22: pause menu over the live game ----
	Game.change_state(Game.State.PLAYING)
	await get_tree().physics_frame
	Game.change_state(Game.State.PAUSED)
	for i in 6:
		await get_tree().process_frame
	await _grab("22_pause")
	Game.change_state(Game.State.PLAYING)
	# ---- 23: touch controls overlay ----
	var touch := TouchUI.new()
	get_tree().root.add_child.call_deferred(touch)
	for i in 4:
		await get_tree().process_frame
	touch.set_enabled(true)
	for i in 8:
		await get_tree().process_frame
	await _grab("23_touch")
	touch.set_enabled(false)
	touch.queue_free()

	print("[screenshot] done")
	get_tree().quit(0)

func _count_enemies() -> int:
	return get_tree().get_nodes_in_group("enemy").size()

func _hero() -> Hero:
	var node := get_tree().get_first_node_in_group("player")
	return node as Hero

func _world() -> Overworld:
	for child in get_tree().root.get_children():
		var w: Node = child.get_node_or_null("Overworld")
		if w is Overworld:
			return w
	return null

# MUST be awaited by every caller: a coroutine called without await is silently
# discarded, and the screenshot is then never written.
func _grab(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path := OUT_DIR + label + ".png"
	img.save_png(path)
	print("[screenshot] " + path + "  " + str(img.get_size()))
