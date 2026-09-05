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
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.name = "Main"
	get_tree().root.add_child(main)
	for i in 6:
		await get_tree().process_frame

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
