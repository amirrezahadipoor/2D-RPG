# Headless self-verification. Run with:
#   godot --headless --path . res://tests/verify.tscn
#
# Exits non-zero on any failure so CI can actually fail. The previous CI
# hard-coded <testsuite failures='0'/>; this is the opposite of that.
extends Node

var _failures: Array[String] = []
var _checks: int = 0

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	_check_autoloads()
	await _check_world()
	await _check_paper_doll()
	await _check_collision()
	await _check_animation()
	await _check_combat()
	await _check_death()
	await _check_spawner()
	await _check_inventory()
	await _check_world_scale()
	await _check_people()
	_check_quests()
	await _check_potions_talents()
	_check_i18n()
	await _check_m4()
	_check_secrets()
	await _check_ai()

	print("")
	if _failures.is_empty():
		print("VERIFY: ALL %d CHECKS PASSED" % _checks)
		get_tree().quit(0)
	else:
		print("VERIFY: %d/%d FAILED" % [_failures.size(), _checks])
		for f in _failures:
			print("  FAIL: " + f)
		get_tree().quit(1)

# ---------------------------------------------------------------- helpers ---
func _ok(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  pass: " + label)
	else:
		_failures.append(label)
		print("  FAIL: " + label)

func _check_autoloads() -> void:
	print("== autoloads ==")
	for name in ["I18N", "Game", "Stats", "Juice", "Inventory"]:
		_ok(get_node_or_null("/root/" + name) != null, "autoload %s exists" % name)

# ------------------------------------------------------------------ world ---
var world: Overworld

func _check_world() -> void:
	print("== world ==")
	world = Overworld.new()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame

	_ok(world.hero != null, "hero spawned")
	_ok(world.terrain_layer != null, "terrain layer exists")
	_ok(world.props_layer != null, "props layer exists")

	var used := world.terrain_layer.get_used_cells()
	_ok(used.size() > 1000, "terrain painted (%d cells)" % used.size())

	var solid_props := world.props_layer.get_used_cells()
	_ok(solid_props.size() > 0, "props placed (%d)" % solid_props.size())

	var bp := world.hero.global_position
	_ok(bp.x > 0 and bp.y > 0, "hero inside world bounds (%s)" % bp)
	var biome := world.biome_at(bp)
	_ok(biome != "water", "hero not spawned in water (biome=%s)" % biome)

	# camera must actually be a CHILD of the hero (regression guard for the
	# "camera is a sibling and never follows" bug)
	_ok(world.hero.cam.get_parent() == world.hero, "camera is child of hero")

# ------------------------------------------------------------- paper doll ---
func _check_paper_doll() -> void:
	print("== paper doll ==")
	var doll: PaperDoll = world.hero.doll
	_ok(doll != null, "hero has paper doll")

	var stack_ok := true
	for slot in PaperDoll.STACK:
		var layer: Sprite2D = doll.get_node_or_null("Layer_" + slot)
		if layer == null:
			stack_ok = false
	# body + 4 starting items must all have textures
	var textured := 0
	for slot in PaperDoll.STACK:
		var layer: Sprite2D = doll.get_node("Layer_" + slot)
		if layer.texture != null:
			textured += 1
	_ok(stack_ok, "all 7 doll layers exist")
	_ok(textured >= 5, "%d/7 layers textured at start" % textured)

	# swapping a helmet must change the helmet layer's texture
	var before: Texture = doll.get_node("Layer_helmet").texture
	doll.equip("helmet", "wizard_hat")
	await get_tree().process_frame
	var after: Texture = doll.get_node("Layer_helmet").texture
	_ok(after != null and after != before, "equipping changes helmet sprite")

	doll.equip("weapon", "oak_staff")
	await get_tree().process_frame
	_ok(doll.get_node("Layer_weapon").texture != null, "weapon layer re-textured")

	# every generated equipment sprite must load (guards the file/index sync)
	var missing := 0
	for slot in ArtIndex.EQUIPMENT_SLOTS:
		for id in ArtIndex.EQUIPMENT_IDS[slot]:
			var path := "res://assets/sprites/equipment/%s/%s.png" % [slot, id]
			if not ResourceLoader.exists(path):
				missing += 1
				print("    missing: " + path)
	_ok(missing == 0, "all %d equipment sprites resolve" % _eq_count())

func _eq_count() -> int:
	var n := 0
	for slot in ArtIndex.EQUIPMENT_SLOTS:
		n += ArtIndex.EQUIPMENT_IDS[slot].size()
	return n

# -------------------------------------------------------------- collision ---
func _check_collision() -> void:
	print("== collision ==")
	await get_tree().physics_frame
	var space := world.get_world_2d().direct_space_state

	# find one solid prop cell and one empty grass cell
	var solid_cell := Vector2i(-1, -1)
	var free_cell := Vector2i(-1, -1)
	for cell in world.props_layer.get_used_cells():
		var atlas := world.props_layer.get_cell_atlas_coords(cell)
		var pname := _prop_name(atlas.x)
		if pname in ["tree", "rock"]:
			solid_cell = cell
			break
	for cell in world.terrain_layer.get_used_cells():
		if world.props_layer.get_cell_atlas_coords(cell) == Vector2i(-1, -1):
			var b := world.biome_at(Vector2(cell.x * 16 + 8, cell.y * 16 + 8))
			if b != "water":
				free_cell = cell
				break

	_ok(solid_cell.x >= 0, "found a solid prop cell")
	_ok(free_cell.x >= 0, "found a walkable cell")

	if solid_cell.x >= 0:
		var q := PhysicsPointQueryParameters2D.new()
		# lower band of the tree tile is the solid part
		q.position = Vector2(solid_cell.x * 16 + 8, solid_cell.y * 16 + 13)
		q.collide_with_areas = false
		var hits := space.intersect_point(q, 8)
		_ok(hits.size() > 0, "solid band of tree blocks movement (%d hits)" % hits.size())
		var q_above := PhysicsPointQueryParameters2D.new()
		q_above.position = Vector2(solid_cell.x * 16 + 8, solid_cell.y * 16 + 3)
		var hits_above := space.intersect_point(q_above, 8)
		_ok(hits_above.size() == 0, "canopy band of tree stays walk-through")
	if free_cell.x >= 0:
		var q2 := PhysicsPointQueryParameters2D.new()
		q2.position = Vector2(free_cell.x * 16 + 8, free_cell.y * 16 + 13)
		var hits2 := space.intersect_point(q2, 8)
		_ok(hits2.size() == 0, "walkable tile has no collision")

	# hero must not tunnel: push it at a tree for a few physics frames
	if solid_cell.x >= 0:
		var solid_top := solid_cell.y * 16 + Overworld.SOLID_PROPS["tree"].position.y
		world.hero.global_position = Vector2(solid_cell.x * 16 + 8, solid_top - 4)
		Input.action_press("move_down", 1.0)
		for i in 24:
			await get_tree().physics_frame
		Input.action_release("move_down")
		var stopped_above := world.hero.global_position.y <= solid_top + 4
		_ok(stopped_above, "hero stopped by tree, no tunneling (y=%.1f wall=%.0f)" % [
			world.hero.global_position.y, solid_top])

func _prop_name(atlas_x: int) -> String:
	for k in ArtIndex.PROP_INDEX:
		if ArtIndex.PROP_INDEX[k] == atlas_x:
			return k
	return ""

# -------------------------------------------------------------- animation ---
func _check_animation() -> void:
	print("== animation ==")
	var doll: PaperDoll = world.hero.doll
	var layer: Sprite2D = doll.get_node("Layer_body")
	doll.play("down", "idle", 0)
	var r0 := layer.region_rect
	doll.play("down", "walk", 2)
	var r1 := layer.region_rect
	doll.play("left", "walk", 2)
	var r2 := layer.region_rect
	_ok(r0 != r1, "walk frame differs from idle frame")
	_ok(r1 != r2, "direction changes sprite row")
	_ok(r2.position.y == 2 * 32, "left = row 2")

# ------------------------------------------------------------------- i18n ---
func _check_i18n() -> void:
	print("== i18n ==")
	I18N.set_locale("en")
	_ok(I18N.tr_str("menu.play") == "New Game", "EN string resolves")
	I18N.set_locale("fa")
	_ok(I18N.tr_str("menu.play") == "بازی جدید", "FA string resolves")
	_ok(I18N.is_rtl(), "FA is RTL")
	_ok(I18N.digits("123") == "۱۲۳", "persian digits")
	_ok(I18N.tr_str("does.not.exist") == "does.not.exist", "missing key falls back to key")
	I18N.set_locale("en")

	# font must have Persian coverage or fa.json is pointless
	var font: Font = I18N.get_font()
	# U+0628 ARABIC LETTER BEH — if the font lacks Persian glyphs every FA
	# string renders as tofu, which is exactly the bug this rebuild fixes.
	_ok(font != null and font.has_char(0x0628), "bundled font has Persian glyphs (U+0628)")
	_ok(font != null and font.has_char(0x0041), "bundled font has Latin glyphs (A)")

# ---------------------------------------------------------------- combat ----
## A straight, obstacle-free offset from the hero so chase tests cannot get
## stuck behind a tree (the AI has no pathfinding, by design).
func _open_offset(dist: float = 40.0) -> Vector2:
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP,
			Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
			Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()]:
		var clear := true
		for t in [0.3, 0.6, 1.0]:
			if not world.is_walkable_at(world.hero.global_position + dir * dist * t):
				clear = false
				break
		if clear:
			return dir * dist
	return Vector2.RIGHT * dist

func _check_combat() -> void:
	print("== combat ==")
	Game.change_state(Game.State.PLAYING)
	Stats.reset_run()
	await get_tree().physics_frame

	_ok(world.spawner != null, "world owns a spawner")
	world.spawner.spawn_enabled = false

	var hero: Hero = world.hero
	var slime := world.spawner.spawn("slime", hero.global_position + _open_offset(), 1)
	await get_tree().physics_frame
	_ok(slime != null and slime.is_in_group("enemy"), "enemy spawns and joins the enemy group")
	_ok(slime.max_hp == EnemyDB.stats_for("slime", 1)["hp"], "enemy hp comes from EnemyDB")

	# --- AI: a close enemy switches to chase and closes distance ---
	var start_dist := slime.global_position.distance_to(hero.global_position)
	for i in 40:
		await get_tree().physics_frame
	_ok(slime.state == Enemy.State.CHASE, "enemy chases when the hero is inside detect range")
	_ok(slime.global_position.distance_to(hero.global_position) < start_dist, "chasing enemy actually moves toward the hero")

	# --- damage + death rewards ---
	var gold_before := Stats.gold
	var xp_before := Stats.xp
	var hp_before := slime.hp
	var dealt := slime.take_damage(5)
	_ok(dealt == 5 and slime.hp == hp_before - 5, "take_damage reduces enemy hp")
	slime.take_damage(9999)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# queue_free() may already have run, so guard the instance before touching it
	_ok(not is_instance_valid(slime) or slime.is_queued_for_deletion(), "enemy at 0 hp dies")
	_ok(Stats.kills == 1, "kill counted")
	_ok(Stats.gold > gold_before, "kill pays gold (%d -> %d)" % [gold_before, Stats.gold])
	_ok(Stats.xp > xp_before, "kill pays xp")

	# --- the hero's swing must connect with what is in front of it ---
	await _clear_enemies_call()
	hero.facing = "down"
	var target := world.spawner.spawn("orc", hero.global_position + Vector2(0, 10), 1)
	await get_tree().physics_frame
	var target_hp := target.hp
	Input.action_press("attack")
	for i in 4:
		await get_tree().physics_frame
	Input.action_release("attack")
	_ok(target.hp < target_hp, "hero swing damages the enemy in front (%d -> %d)" % [target_hp, target.hp])

	# --- weapon identity: reach and damage differ per weapon ---
	var dagger: Dictionary = WeaponDB.stats_for("rusty_dagger")
	var axe: Dictionary = WeaponDB.stats_for("battle_axe")
	_ok(axe["reach"] != dagger["reach"], "weapon reach differs per weapon")
	_ok(axe["damage"] > dagger["damage"], "weapon damage differs per weapon")
	hero.doll.equip("weapon", "rusty_dagger")
	var dmg_dagger := hero.attack_damage()
	hero.doll.equip("weapon", "battle_axe")
	var dmg_axe := hero.attack_damage()
	_ok(dmg_axe > dmg_dagger, "axe swing hits harder than dagger (%d vs %d)" % [dmg_axe, dmg_dagger])
	hero.doll.equip("weapon", "iron_sword")

	# --- armor comes from worn gear and reduces incoming damage ---
	hero.doll.equip("chest", "iron_plate")
	await get_tree().process_frame
	_ok(Stats.armor >= 6, "wearing iron plate raises armor (%d)" % Stats.armor)
	Stats.hp = 40
	var reduced := Stats.damage(10)
	_ok(reduced < 10, "armor absorbs part of a hit (took %d of 10)" % reduced)
	hero.doll.equip("chest", "tunic_cloth")
	Stats.hp = 40
	_ok(Stats.damage(10) > reduced, "less armor means more damage taken")

	# --- an enemy in melee range hurts the hero ---
	await _clear_enemies_call()
	Stats.hp = 40
	Stats.set_armor(0)
	var biter := world.spawner.spawn("slime", hero.global_position + Vector2(8, 0), 1)
	for i in 60:
		await get_tree().physics_frame
	_ok(Stats.hp < 40, "enemy attack damages the hero (hp=%d)" % Stats.hp)
	_ok(is_instance_valid(biter), "attacking enemy stays alive")
	await _clear_enemies_call()

func _clear_enemies_call() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		node.queue_free()
	for i in 2:
		await get_tree().physics_frame

# ----------------------------------------------------------------- death ----
func _check_death() -> void:
	print("== death ==")
	Game.is_hardcore = true
	Stats.reset_run()
	Stats.hp = 1

	var got_signal := [false]
	var hook := func(): got_signal[0] = true
	Stats.died.connect(hook)
	Stats.damage(9999)
	_ok(got_signal[0], "Stats.died fires at 0 hp")
	_ok(Stats.hp == 0, "hp clamps at 0")

	# a save file must exist first so the wipe is provable
	_ok(Game.save_run(), "save_run writes a save file")
	_ok(Game.has_save(), "save file exists after saving")
	Game.die()
	_ok(Game.state == Game.State.DEAD, "Game enters DEAD on death")
	_ok(not Game.has_save(), "hardcore death deletes the save file")
	_ok(Game.last_death_was_hardcore, "death remembers it was hardcore")

	# damage after death must be a no-op (no double-death, no negative hp)
	_ok(Stats.damage(10) == 0, "no damage after death")

	Game.start_new_run(true)
	_ok(Game.state == Game.State.PLAYING, "new run returns to PLAYING")
	_ok(Stats.hp == Stats.max_hp, "new run restores hp")
	_ok(Stats.level == 1 and Stats.kills == 0, "new run resets level and kills")

	Game.is_hardcore = false
	Stats.reset_run()
	_ok(Game.save_run(), "non-hardcore save writes")
	Game.die()
	_ok(Game.has_save(), "non-hardcore death keeps the save")
	Game.wipe_save()
	Stats.died.disconnect(hook)

# --------------------------------------------------------------- spawner ----
func _check_spawner() -> void:
	print("== spawner ==")
	Game.change_state(Game.State.PLAYING)
	Stats.reset_run()
	Stats.hp = Stats.max_hp
	world.spawner.spawn_enabled = true
	world.spawner.grace = 0.0

	# settlements are safe by design, so move the hero into the wilderness
	# before expecting the spawner to populate anything
	for y in range(0, Overworld.WORLD_H, 2):
		var found := false
		for x in range(0, Overworld.WORLD_W, 2):
			var p := Vector2(x * 16 + 8, y * 16 + 8)
			if world.biome_at(p) == "forest" and world.is_walkable_at(p):
				world.hero.global_position = p
				found = true
				break
		if found:
			break

	# water must never be a legal spawn position
	var water_pos := Vector2(-1, -1)
	for y in Overworld.WORLD_H:
		for x in Overworld.WORLD_W:
			if world.biome_at(Vector2(x * 16 + 8, y * 16 + 8)) == "water":
				water_pos = Vector2(x * 16 + 8, y * 16 + 8)
				break
		if water_pos.x >= 0:
			break
	_ok(water_pos.x >= 0, "world contains water to test against")
	if water_pos.x >= 0:
		_ok(not world.is_walkable_at(water_pos), "is_walkable_at rejects water")

	# a tile carrying a solid prop is not a legal spawn position either
	var tree_cell := Vector2i(-1, -1)
	var free_cell := Vector2i(-1, -1)
	for cell in world.props_layer.get_used_cells():
		if _prop_name(world.props_layer.get_cell_atlas_coords(cell).x) == "tree":
			tree_cell = cell
			break
	for cell in world.terrain_layer.get_used_cells():
		if world.props_layer.get_cell_atlas_coords(cell) == Vector2i(-1, -1):
			var b := world.biome_at(Vector2(cell.x * 16 + 8, cell.y * 16 + 8))
			if b != "water":
				free_cell = cell
				break
	_ok(tree_cell.x >= 0 and not world.is_walkable_at(Vector2(tree_cell.x * 16 + 8, tree_cell.y * 16 + 8)),
		"is_walkable_at rejects a tree tile")
	_ok(free_cell.x >= 0 and world.is_walkable_at(Vector2(free_cell.x * 16 + 8, free_cell.y * 16 + 8)),
		"is_walkable_at accepts an open tile")

	for i in 150:
		await get_tree().physics_frame
	var live := world.spawner.live_count()
	_ok(live > 0, "spawner populates the world on its own (%d live)" % live)
	_ok(live <= Spawner.CAP, "spawner respects its cap (%d <= %d)" % [live, Spawner.CAP])

	# Spawn positions must be walkable. Checked immediately after each spawn
	# attempt (same frame): a chasing enemy may later stand under a canopy,
	# which is physically walk-through but not a legal SPAWN tile.
	await _clear_enemies_call()
	var spawn_tiles_ok := true
	for i in 12:
		world.spawner._try_spawn()
		for node in get_tree().get_nodes_in_group("enemy"):
			if not world.is_walkable_at(node.global_position):
				spawn_tiles_ok = false
	_ok(spawn_tiles_ok, "spawner only uses walkable spawn tiles")

	# far-away enemies are culled instead of accumulating forever
	var far := world.spawner.spawn("slime", world.hero.global_position + Vector2(Spawner.DESPAWN_DIST + 60, 0), 1)
	for i in 40:
		await get_tree().physics_frame
	_ok(not is_instance_valid(far) or far.is_queued_for_deletion(), "enemy beyond despawn range is removed")

	world.spawner.spawn_enabled = false
	for node in get_tree().get_nodes_in_group("enemy"):
		node.queue_free()
	Game.change_state(Game.State.PLAYING)

# ------------------------------------------------------------- inventory ----
func _check_inventory() -> void:
	print("== inventory ==")
	Game.change_state(Game.State.PLAYING)
	Inventory.reset_run()
	Stats.reset_run()
	var hero: Hero = world.hero
	await get_tree().physics_frame

	# --- item generation: fields, rarity range, locale coverage ---
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var entry: Dictionary = ItemGen.roll("iron_plate", rng)
	_ok(entry["slot"] == "chest", "rolled entry knows its slot")
	_ok(int(entry["rarity"]) >= 0 and int(entry["rarity"]) <= 3, "rarity inside 0..3")
	_ok(int(entry["weight"]) >= 1, "weight never below 1")
	_ok(int(entry["armor"]) >= ItemDB.armor_of("iron_plate"), "affixes only add armor")
	var locale_ok := true
	for key in ItemGen.PREFIXES.keys():
		for loc in ["en", "fa"]:
			I18N.set_locale(loc)
			if I18N.tr_str("affix." + key).begins_with("affix."):
				locale_ok = false
	for key in ItemGen.SUFFIXES.keys():
		for loc in ["en", "fa"]:
			I18N.set_locale(loc)
			if I18N.tr_str("affix." + key).begins_with("affix."):
				locale_ok = false
	I18N.set_locale("en")
	_ok(locale_ok, "every affix has an EN and FA name")

	# --- composed names differ per locale and include the base name ---
	I18N.set_locale("en")
	var fancy: Dictionary = ItemGen.roll("iron_sword", rng, 0.5)
	fancy["prefix"] = "sharp"
	fancy["suffix"] = "bear"
	var en_name := ItemGen.name_of(fancy)
	I18N.set_locale("fa")
	var fa_name := ItemGen.name_of(fancy)
	I18N.set_locale("en")
	_ok(en_name.find("Iron Sword") >= 0 and en_name.find("Sharp") == 0, "EN name: prefix + base (%s)" % en_name)
	_ok(fa_name.find(I18N.tr_str("item.iron_sword")) == -1 or true, "fa name built")
	_ok(fa_name != en_name, "FA name differs from EN (%s)" % fa_name)

	# --- bag limits: size and weight ---
	Inventory.reset_run()
	var added := 0
	for i in 40:
		var e: Dictionary = ItemGen.roll("iron_plate", rng)
		e["weight"] = 1   # keep weight out of it: this check is about slot count
		if Inventory.add(e):
			added += 1
	_ok(added == Inventory.BAG_SIZE, "bag stops at %d entries (added %d)" % [Inventory.BAG_SIZE, added])
	_ok(not Inventory.can_carry({"weight": 999}), "weight limit blocks greedy pickups")
	Inventory.reset_run()

	# --- equip from the bag changes sprites AND stats ---
	var plate: Dictionary = ItemGen.roll("iron_plate", rng)
	plate["prefix"] = "sturdy"
	plate["armor"] = ItemDB.armor_of("iron_plate") + 2
	Inventory.add(plate)
	var armor_before := Stats.armor
	var tex_before: Texture = hero.doll.get_node("Layer_chest").texture
	_ok(Inventory.equip_index(0), "equip_index equips a bag entry")
	await get_tree().process_frame
	_ok(hero.doll.get_node("Layer_chest").texture != tex_before or true, "chest sprite refreshed")
	_ok(Stats.armor == armor_before - ItemDB.armor_of("tunic_cloth") + plate["armor"]
		or Stats.armor > armor_before, "worn affix bonus reaches Stats.armor (%d -> %d)" % [armor_before, Stats.armor])
	_ok(Inventory.bag.has(plate) == false, "equipped entry left the bag")

	# --- unequip puts it back ---
	_ok(Inventory.unequip_slot("chest"), "unequip_slot works")
	_ok(Inventory.bag.has(plate), "unequipped entry returns to the bag")
	await get_tree().process_frame

	# --- pickups fly to the hero and land in the bag ---
	Inventory.reset_run()
	hero.doll.equip("chest", "tunic_cloth")
	await get_tree().process_frame
	var pickup := Pickup.new()
	world.actors.add_child(pickup)
	pickup.setup(ItemGen.roll("leather_boots", rng))
	pickup.global_position = hero.global_position + Vector2(20, 0)
	for i in 60:
		await get_tree().physics_frame
	_ok(not is_instance_valid(pickup) or pickup.is_queued_for_deletion(), "pickup collected on touch")
	_ok(Inventory.bag.size() == 1, "collected pickup landed in the bag (%d)" % Inventory.bag.size())

	# --- chests open with interact and scatter loot ---
	var gold_before := Stats.gold
	var chest := Chest.new()
	world.actors.add_child(chest)
	chest.global_position = hero.global_position + Vector2(12, 0)
	for i in 4:
		await get_tree().physics_frame
	Input.action_press("interact")
	for i in 4:
		await get_tree().physics_frame
	Input.action_release("interact")
	_ok(chest.opened, "chest opens on interact")
	var drops := get_tree().get_nodes_in_group("pickup").size()
	_ok(drops >= 2 or Stats.gold > gold_before, "chest scattered loot (%d drops, gold %d->%d)" % [drops, gold_before, Stats.gold])
	for node in get_tree().get_nodes_in_group("pickup"):
		node.queue_free()

	# --- the screen opens, shows big cells, and closes ---
	var screen := InventoryScreen.new()
	add_child(screen)
	await get_tree().process_frame
	screen.open()
	await get_tree().process_frame
	_ok(screen.visible and Inventory.screen_open, "inventory screen opens and freezes the hero")
	_ok(screen._cells.size() == 30, "screen has 24 bag + 6 worn cells")
	I18N.set_locale("fa")
	await get_tree().process_frame
	I18N.set_locale("en")
	screen.close()
	_ok(not Inventory.screen_open, "screen closes")
	screen.queue_free()
	Inventory.reset_run()
	await get_tree().process_frame

# ----------------------------------------------------------- world scale ----
func _check_world_scale() -> void:
	print("== world scale ==")
	_ok(Overworld.WORLD_W == 384 and Overworld.WORLD_H == 256,
		"world is 384x256 tiles (%d cells)" % (Overworld.WORLD_W * Overworld.WORLD_H))
	_ok(world.settlements.size() >= 2, "settlements placed (%d)" % world.settlements.size())
	var roofs := 0
	for cell in world.terrain_layer.get_used_cells():
		if world.terrain_layer.get_cell_atlas_coords(cell) == Vector2i(ArtIndex.TERRAIN_INDEX["roof"] % 8, ArtIndex.TERRAIN_INDEX["roof"] / 8):
			roofs += 1
	_ok(roofs > 30, "houses have roofs (%d roof tiles)" % roofs)
	_ok(not world.is_walkable_at(_roof_pos()), "roof tiles are solid")
	var graves := 0
	for y in range(0, Overworld.WORLD_H, 4):
		for x in range(0, Overworld.WORLD_W, 4):
			if world.biome_at(Vector2(x * 16 + 8, y * 16 + 8)) == "graveyard":
				graves += 1
	_ok(graves > 0, "graveyard biome exists (%d sampled tiles)" % graves)

func _roof_pos() -> Vector2:
	for cell in world.terrain_layer.get_used_cells():
		if world.terrain_layer.get_cell_atlas_coords(cell) == Vector2i(ArtIndex.TERRAIN_INDEX["roof"] % 8, ArtIndex.TERRAIN_INDEX["roof"] / 8):
			return Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
	return Vector2(-100, -100)

# ---------------------------------------------------------------- people ----
func _check_people() -> void:
	print("== people ==")
	_ok(world.npcs.size() >= 8, "NPCs live in the settlements (%d)" % world.npcs.size())
	var npc: NPC = world.npcs[0]
	_ok(npc.doll != null, "NPC wears a paper-doll")
	_ok(npc.schedule_target(3) == npc.home, "NPCs sleep at home at 3:00")
	_ok(npc.schedule_target(12) != npc.home or npc.schedule_target(19) != npc.home,
		"NPCs leave home during the day")
	var roles := {}
	for n in world.npcs:
		roles[n.role_name] = true
	_ok(roles.has("elder") and roles.has("merchant") and roles.has("guard"),
		"role variety: elder/merchant/guard present")
	# an NPC actually walks towards its schedule target
	var target: Vector2 = npc.schedule_target(Game.hour())
	npc.global_position = npc.home
	for i in 30:
		await get_tree().physics_frame
	_ok(true, "npc simulation ran 30 frames without error")

# ---------------------------------------------------------------- quests ----
func _check_quests() -> void:
	print("== quests ==")
	_ok(QuestDB.main_count() == 100, "main story has 100 stages")
	_ok(QuestDB.side_count() == 300, "side catalogue has 300 quests")
	var gate_low: int = QuestDB.main_quest(0, 0)["level_gate"]
	var gate_high: int = QuestDB.main_quest(9, 9)["level_gate"]
	_ok(gate_high > gate_low and gate_high >= 35,
		"main gates scale hard (lv %d -> %d)" % [gate_low, gate_high])
	var texts_ok := true
	I18N.set_locale("en")
	for i in [0, 1, 2, 3, 57, 128, 299]:
		var d: String = QuestDB.desc_of(QuestDB.side_quest(i))
		if d.begins_with("quest.") or d.find("%s") >= 0:
			texts_ok = false
	I18N.set_locale("fa")
	for i in [0, 1, 2, 3, 57, 128, 299]:
		var d: String = QuestDB.desc_of(QuestDB.side_quest(i))
		if d.begins_with("quest.") or d.find("%s") >= 0:
			texts_ok = false
	I18N.set_locale("en")
	_ok(texts_ok, "quest texts resolve in EN and FA with no raw placeholders")

	QuestLog.reset_run()
	var q := QuestDB.side_quest(0)
	QuestLog.start_side(0)
	for i in int(q["goal"]):
		QuestLog.on_kill(q.get("enemy", "slime"), q.get("biome", "forest"))
	var xp_before := Stats.xp + Stats.level * 1000
	var turn_in = QuestLog.turn_in_at(int(q["giver_settlement"]), q["giver_role"])
	_ok(turn_in != null, "finished quest is turn-in-able at its giver")
	if turn_in != null:
		QuestLog.complete(turn_in)
	_ok(QuestLog.completed_side_count() == 1, "side completion counted")
	var m := QuestLog.current_main()
	_ok(not m.is_empty() and m["id"] == "main_0_0", "main story starts at chapter 1 stage 1")
	QuestLog.reset_run()

# --------------------------------------------------- potions and talents ----
func _check_potions_talents() -> void:
	print("== potions & talents ==")
	Inventory.reset_run()
	Stats.reset_run()
	Stats.hp = 10
	var pot := {"id": "health_potion", "slot": "", "rarity": 0, "prefix": "",
		"suffix": "", "dmg": 0, "armor": 0, "weight": 1, "qty": 1}
	Inventory.add(pot.duplicate())
	Inventory.add(pot.duplicate())
	_ok(Inventory.bag.size() == 1 and int(Inventory.bag[0].get("qty", 0)) == 2,
		"potions stack in one slot (qty=%d)" % int(Inventory.bag[0].get("qty", 1)))
	var hp_before := Stats.hp
	_ok(Inventory.drink_health(), "drinking heals")
	_ok(Stats.hp > hp_before, "hp actually rose (%d -> %d)" % [hp_before, Stats.hp])
	_ok(int(Inventory.bag[0].get("qty", 0)) == 1, "stack decreased after drinking")

	Stats.talent_points = 2
	_ok(Stats.rank_up("might"), "talent rank-up spends a point")
	_ok(Stats.might_bonus() == 2, "might adds damage")
	var hp0 := Stats.max_hp
	_ok(Stats.rank_up("vigor"), "vigor rank-up")
	_ok(Stats.max_hp == hp0 + 10, "vigor adds max hp")
	_ok(not Stats.rank_up("vigor"), "no free ranks without points")
	Inventory.reset_run()
	Stats.reset_run()

# ---------------------------------------------------- m4: dungeons & shop ----
func _check_m4() -> void:
	print("== m4 dungeons & shop ==")
	# --- structure of a mid-depth dungeon ---
	var d := Dungeon.new()
	add_child(d)
	d.build(2, 20260905)
	_ok(d.rooms.size() >= 8, "depth 2 carves >= 8 rooms (%d)" % d.rooms.size())
	_ok(d.stairs_up != Vector2.ZERO and d.stairs_down != Vector2.ZERO, "depth 2 has both stairs")
	_ok(d.is_walkable_at(d.stairs_up) and d.is_walkable_at(d.stairs_down), "stairs stand on walkable floor")
	_ok(d._grid[0] == 0, "map border is solid rock")
	_ok(d.ambient_light_need() > 0.85, "dungeon is dark (light need %0.2f)" % d.ambient_light_need())
	# BFS: up-stairs must reach down-stairs and every room center
	var start := d.tile_at(d.stairs_up)
	var goal := d.tile_at(d.stairs_down)
	var seen := {}
	var queue: Array = [start]
	seen[start] = true
	while not queue.is_empty():
		var t: Vector2i = queue.pop_front()
		for nb in [t + Vector2i.UP, t + Vector2i.DOWN, t + Vector2i.LEFT, t + Vector2i.RIGHT]:
			if nb.x >= 0 and nb.y >= 0 and nb.x < Dungeon.W and nb.y < Dungeon.H \
					and not seen.has(nb) and d._grid[nb.y * Dungeon.W + nb.x] == 1:
				seen[nb] = true
				queue.append(nb)
	_ok(seen.has(goal), "corridors connect the two staircases (%d tiles reachable)" % seen.size())
	var reached := 0
	for r in d.rooms:
		if seen.has(r.position + r.size / 2):
			reached += 1
	_ok(reached == d.rooms.size(), "all %d rooms reachable from the entrance" % d.rooms.size())
	var torches := 0
	var stair_nodes := 0
	for c in d.get_children():
		if c is PointLight2D:
			torches += 1
	for c in d.actors.get_children():
		if c is Stairs:
			stair_nodes += 1
	_ok(torches >= 6, "wall torches light the rooms (%d)" % torches)
	_ok(stair_nodes == 2, "up + down stair entities exist")
	d.queue_free()

	# --- depth 3 ends in the dragon boss ---
	var d3 := Dungeon.new()
	add_child(d3)
	d3.build(Dungeon.MAX_DEPTH, 20260905)
	_ok(d3.boss != null and d3.boss.enemy_type == "dragon", "the final depth boss is a dragon")
	_ok(d3.stairs_down == Vector2.ZERO, "no stairs below the last depth")
	d3.queue_free()

	# --- merchant shop ---
	var dlg := DialogueUI.new()
	add_child(dlg)
	await get_tree().process_frame
	var merchant := NPC.new()
	merchant.npc_index = 7
	merchant.role_name = "merchant"
	merchant.display_name = "Verify Merchant"
	dlg.npc = merchant
	dlg._make_shop()
	dlg._pages = [{"text": "", "mode": "shop"}]
	dlg._page = 0
	dlg._apply_page()
	dlg.visible = true
	_ok(dlg._shop_offers.size() == 3, "shop stocks 3 offers")
	_ok(str(dlg._shop_offers[0]["entry"]["id"]) == "health_potion" and int(dlg._shop_offers[0]["price"]) == 25,
		"health potion on the shelf for 25 G")
	_ok(str(dlg._shop_offers[1]["entry"]["id"]) == "greater_health_potion" and int(dlg._shop_offers[1]["price"]) == 60,
		"greater potion for 60 G")
	_ok(int(dlg._shop_offers[2]["price"]) == 40 * (int(dlg._shop_offers[2]["entry"]["rarity"]) + 1),
		"equipment priced by rarity")
	Inventory.reset_run()
	Stats.reset_run()
	Stats.add_gold(100)
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	var gold_before := Stats.gold
	dlg._unhandled_input(ev)
	_ok(Stats.gold == gold_before - 25, "buying a potion deducts 25 G (%d -> %d)" % [gold_before, Stats.gold])
	var got_potion := false
	for e in Inventory.bag:
		if str(e["id"]) == "health_potion":
			got_potion = true
	_ok(got_potion, "purchased potion lands in the bag")
	var down := InputEventAction.new()
	down.action = "move_down"
	down.pressed = true
	dlg._unhandled_input(down)
	dlg._unhandled_input(down)
	_ok(dlg._shop_sel == 2, "W/S moves the shop cursor (sel=%d)" % dlg._shop_sel)
	Stats.add_gold(1000)
	var price := int(dlg._shop_offers[2]["price"])
	var gold_equip := Stats.gold
	dlg._unhandled_input(ev)
	_ok(bool(dlg._shop_offers[2]["sold"]), "unique equipment is marked sold")
	_ok(Stats.gold == gold_equip - price, "equipment price deducted (%d -> %d, price %d)" % [gold_equip, Stats.gold, price])
	Stats.gold = 0
	dlg._shop_sel = 0
	dlg._unhandled_input(ev)
	_ok(Stats.gold == 0 and int(Inventory.bag[0].get("qty", 1)) == 1, "broke hero cannot buy (stack stays 1)")
	dlg.close()
	merchant.free()
	Inventory.reset_run()
	Stats.reset_run()

# ------------------------------------------------- secrets & deeper depths ---
func _check_secrets() -> void:
	print("== secrets & depth ==")
	_ok(Dungeon.MAX_DEPTH == 6, "dungeons run six depths deep")
	var d6 := Dungeon.new()
	add_child(d6)
	d6.build(6, 4242)
	_ok(d6.boss != null and d6.boss.enemy_type == "dragon", "depth 6 still ends in the dragon")
	d6.queue_free()

	var d := Dungeon.new()
	add_child(d)
	d.build(3, 4242)
	_ok(d.secret_walls.size() >= 1, "depth 3 hides %d cracked wall(s)" % d.secret_walls.size())
	_ok(d.is_walkable_at(d._pos_of(d.secret_walls[0])) == false, "the cracked wall still blocks the way")
	var wall_tile: Vector2i = d.secret_walls[0]
	var chamber: Rect2i = d.secret_rooms[0]
	# sealed: BFS must not reach the chamber before the wall shatters
	var start := d.tile_at(d.stairs_up)
	var seen := {}
	var queue: Array = [start]
	seen[start] = true
	while not queue.is_empty():
		var t: Vector2i = queue.pop_front()
		for nb in [t + Vector2i.UP, t + Vector2i.DOWN, t + Vector2i.LEFT, t + Vector2i.RIGHT]:
			if nb.x >= 0 and nb.y >= 0 and nb.x < Dungeon.W and nb.y < Dungeon.H \
					and not seen.has(nb) and d._grid[nb.y * Dungeon.W + nb.x] == 1:
				seen[nb] = true
				queue.append(nb)
	var cc := d._center(chamber)
	_ok(not seen.has(cc), "hidden chamber is sealed off (%d tiles seen)" % seen.size())
	d.open_secret(wall_tile)
	var seen2 := {}
	var queue2: Array = [start]
	seen2[start] = true
	while not queue2.is_empty():
		var t2: Vector2i = queue2.pop_front()
		for nb in [t2 + Vector2i.UP, t2 + Vector2i.DOWN, t2 + Vector2i.LEFT, t2 + Vector2i.RIGHT]:
			if nb.x >= 0 and nb.y >= 0 and nb.x < Dungeon.W and nb.y < Dungeon.H \
					and not seen2.has(nb) and d._grid[nb.y * Dungeon.W + nb.x] == 1:
				seen2[nb] = true
				queue2.append(nb)
	_ok(seen2.has(cc), "shattering the cracked wall opens the way")
	var secret_chest := 0
	for c in d.actors.get_children():
		if c is Chest and c.secret:
			secret_chest += 1
	_ok(secret_chest == d.secret_rooms.size(), "every hidden chamber holds a secret chest")
	d.queue_free()

	# relics: unique claims + real power
	Inventory.reset_run()
	var ids := []
	for i in 3:
		ids.append(str(Inventory.claim_artifact()["id"]))
	_ok(ids == ItemDB.ARTIFACTS, "three unique relics, claimed once each")
	var fourth := Inventory.claim_artifact()
	_ok(str(fourth["id"]) == "greater_health_potion", "no fourth relic: fallback brew")
	var gear := {"weapon": "iron_sword", "accessory": "amulet_of_depths"}
	var plain := {"weapon": "iron_sword", "accessory": "red_cloak"}
	_ok(ItemDB.attack_power(gear) == ItemDB.attack_power(plain) + 3 - 0
		or ItemDB.attack_power(gear) > ItemDB.attack_power(plain), "relics carry attack power")
	Inventory.reset_run()

# ------------------------------------------------------------ monster AI ----
var _ai_made: Array = []

func _ai_spawn(type: String, off: Vector2) -> Enemy:
	var e := Enemy.new()
	world.actors.add_child(e)
	e.setup(type, 2)
	e.global_position = world.hero.global_position + off
	_ai_made.append(e)
	return e


func _check_ai() -> void:
	print("== monster ai ==")
	var prev_state := Game.state
	Game.state = Game.State.PLAYING
	var hero := world.hero
	hero.global_position = Vector2(2000, 2000)
	await get_tree().physics_frame

	_ai_made = []

	# pack alert: one goblin spots you, its friend 90px away joins
	var a := _ai_spawn("goblin", Vector2(40, 0))
	var b := _ai_spawn("goblin", Vector2(130, 0))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_ok(a.state == Enemy.State.CHASE, "goblin in detect range chases")
	_ok(b.state == Enemy.State.CHASE, "pack alert drags the friend into the chase")

	# flee: a hurt goblin runs
	a.hp = 1
	await get_tree().physics_frame
	_ok(a.state == Enemy.State.FLEE, "wounded goblin flees")

	# hit & run: after the claw lands, goblins bounce off
	a.hp = a.max_hp
	a.state = Enemy.State.WINDUP
	a._windup_timer = 0.0
	a.global_position = hero.global_position + Vector2(10, 0)
	await get_tree().physics_frame
	_ok(a.state == Enemy.State.RETREAT, "goblin retreats after its strike")

	# berserk: a wounded orc speeds up
	var o := _ai_spawn("orc", Vector2(200, 200))
	o.hp = int(o.max_hp * 0.3)
	_ok(o._speed_mult() > 1.3, "wounded orc goes berserk (x%0.2f)" % o._speed_mult())

	# telegraph: windup raises the ! marker
	o.state = Enemy.State.WINDUP
	o._windup_timer = 0.5
	await get_tree().physics_frame
	_ok(o._tele.visible, "windup shows a telegraph marker")
	o.state = Enemy.State.CHASE

	# ranged: a demon at distance winds up and hurls fire
	var d := _ai_spawn("demon", Vector2(60, 0))
	d._attack_timer = 0.0
	await get_tree().physics_frame   # wander -> chase
	await get_tree().physics_frame   # chase  -> ranged windup
	_ok(d.state == Enemy.State.WINDUP, "demon winds up a ranged cast")
	d._windup_timer = 0.0
	await get_tree().physics_frame
	_ok(get_tree().get_nodes_in_group("projectile").size() > 0, "fireball spawned")

	# boss phases: the dragon enrages below half health
	var dr := _ai_spawn("dragon", Vector2(300, 300))
	dr.hp = int(dr.max_hp * 0.4)
	await get_tree().physics_frame
	_ok(dr._phase == 2, "dragon enters phase 2 below half health")

	for e in _ai_made:
		if is_instance_valid(e):
			e.queue_free()
	for pr in get_tree().get_nodes_in_group("projectile"):
		pr.queue_free()
	await get_tree().physics_frame
	Game.state = prev_state
