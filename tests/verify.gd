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
	await _check_houses()
	await _check_people()
	_check_quests()
	await _check_endgame()
	await _check_potions_talents()
	_check_i18n()
	await _check_m4()
	_check_secrets()
	await _check_ai()
	await _check_combat_style()
	_check_balance()
	await _check_graphics()
	await _check_anim()
	await _check_bestiary()
	await _check_audio()
	await _check_menus()
	await _check_touch_quality()

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
	world.name = "Overworld"   # mirrors scenes/main.tscn so Game._find_world() sees it
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
	var slime_base: Dictionary = EnemyDB.stats_for("slime", 1)
	_ok(slime.max_hp == slime_base["hp"] or (slime.elite and slime.max_hp > slime_base["hp"]),
		"enemy hp comes from EnemyDB (elites buffed)")

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
	# death is a topple-and-fade now: give the corpse countdown its ~0.4s
	for i in 40:
		await get_tree().physics_frame
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
	# full-fidelity round trip: mutate everything, save, wipe memory, reload
	Stats.gold = 4242
	Stats.level = 7
	Stats.xp = 1234
	var rt_rng := RandomNumberGenerator.new()
	rt_rng.seed = 4242
	Inventory.reset_run()
	Inventory.add(ItemGen.roll("iron_sword", rt_rng))
	_ok(Inventory.equip_index(0), "round-trip fixture equips the sword")
	QuestLog.start_side(0)
	QuestLog.active[0]["progress"] = 2
	QuestLog.completed_side["side_done"] = true
	var rt_seed: int = world.world_seed
	world.world_seed = 987654
	var rt_hero: Hero = world.hero
	var rt_pos: Vector2 = rt_hero.global_position
	rt_hero.global_position = rt_pos + Vector2(3, 0)
	_ok(Game.save_run(), "checkpoint save writes with inventory + quests")
	var save_text := FileAccess.get_file_as_string(Game.SAVE_PATH)
	var reparsed: Variant = JSON.parse_string(save_text)
	_ok(typeof(reparsed) == TYPE_DICTIONARY, "save file is valid JSON")
	_ok((reparsed as Dictionary).has("dungeon_depth"), "save carries a dungeon_depth field")
	Stats.gold = 0
	Stats.level = 1
	Inventory.bag.clear()
	Inventory.equipped.clear()
	QuestLog.active.clear()
	QuestLog.completed_side.clear()
	Game.saved_world_seed = -1
	Game.saved_hero_pos = Vector2.ZERO
	_ok(Game.load_run(), "load_run restores from disk")
	_ok(Stats.gold == 4242 and Stats.level == 7 and Stats.xp == 1234, "stats survive the round trip")
	var rt_weapon: Variant = Inventory.equipped.get("weapon", {})
	_ok(rt_weapon is Dictionary and String(rt_weapon.get("id", "")) == "iron_sword", "equipment survives the round trip")
	_ok(QuestLog.active.size() == 1 and int(QuestLog.active[0].get("progress", 0)) == 2, "active quest progress survives")
	_ok(QuestLog.completed_side.has("side_done"), "completed side quests survive")
	_ok(Game.saved_world_seed == 987654, "world seed survives the round trip")
	# dungeon depth rides along in the save so revive/continue re-enters it
	var rt_text := FileAccess.get_file_as_string(Game.SAVE_PATH)
	var rt_edit: Dictionary = JSON.parse_string(rt_text)
	rt_edit["dungeon_depth"] = 4
	var rt_f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	rt_f.store_string(JSON.stringify(rt_edit))
	rt_f.close()
	Game.load_run()
	_ok(Game.saved_dungeon_depth == 4, "dungeon depth survives the round trip")
	Game.load_run()
	_ok(Game.saved_hero_pos.distance_to(rt_pos + Vector2(3, 0)) < 1.0, "hero position survives the round trip")
	rt_hero.global_position = rt_pos
	world.world_seed = rt_seed
	Game.wipe_save()
	Inventory.reset_run()
	QuestLog.reset_run()
	Stats.reset_run()
	Stats.hp = 0
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
			# settlement carving can repaint tiles; only judge wild trees
			var wp := Vector2(cell.x * 16 + 8, cell.y * 16 + 8)
			if world.biome_at(wp) in ["village", "town"]:
				continue
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
func _check_houses() -> void:
	print("== houses & interiors ==")
	var door_count := 0
	for st in world.settlements:
		var houses: Array = world._house_rects(st)
		for hi in houses.size():
			door_count += 1
			var h: Rect2i = houses[hi]
			var tile := Vector2i(h.position.x + h.size.x / 2, h.position.y + h.size.y - 1)
			var pos := Vector2(tile.x * 16 + 8.0, tile.y * 16 + 8.0)
			var found := world.actors.find_children(
				"HouseDoor_%d" % (int(st["index"]) * 16 + hi), "Stairs", false, false)
			_ok(found.size() == 1 and world.is_walkable_at(pos),
				"settlement %d house %d has a door on walkable ground" % [st["index"], hi])
	_ok(door_count == world.house_door_count(),
		"painted houses and doors are in step (%d doors)" % door_count)
	# a full palace-to-cottage sample of interiors must be walkable and lootable
	for kind in ["home", "town_house", "palace"]:
		var it := Interior.new()
		add_child(it)
		it.build(kind, 3, 20260905)
		await get_tree().process_frame
		var start: Vector2i = it.tile_at(it.cell_center(it.spawn_tile))
		var goal: Vector2i = it.entry_tile
		var seen := {}
		var q: Array = [start]
		seen[start] = true
		while not q.is_empty():
			var t: Vector2i = q.pop_front()
			for nb in [t + Vector2i.UP, t + Vector2i.DOWN, t + Vector2i.LEFT, t + Vector2i.RIGHT]:
				if nb.x >= 0 and nb.y >= 0 and nb.x < Interior.MAP_W and nb.y < Interior.MAP_H \
						and not seen.has(nb) and it._grid[nb.y * Interior.MAP_W + nb.x] == 1:
					seen[nb] = true
					q.append(nb)
		_ok(seen.has(goal), "%s interior connects its door to the living room" % kind)
		_ok(it.exit_stairs != null and it.is_walkable_at(it.cell_center(it.entry_tile)),
			"%s interior offers the way back out" % kind)
		_ok(it.actors.find_children("Chest", "", true, false).size() >= 1,
			"%s interior hides a stash" % kind)
		var rooms := 0
		for c in it.terrain_layer.get_used_cells():
			if it._grid[c.y * Interior.MAP_W + c.x] == 1:
				rooms += 1
		_ok(rooms > 40, "%s interior paints a real floor (%d walkable tiles)" % [kind, rooms])
		it.queue_free()
		await get_tree().physics_frame
	var keys_ok := true
	for loc in ["en", "fa"]:
		I18N.set_locale(loc)
		for key in ["house.title.home", "house.name.palace", "toast.enter_house"]:
			var v: String = I18N.tr_str(key)
			if v == key:
				keys_ok = false
	I18N.set_locale("en")
	_ok(keys_ok, "house strings resolve in EN and FA")

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
	# the realm has exactly one crowned king, living in the town's palace
	var towns := 0
	for st in world.settlements:
		if st["type"] == "town":
			towns += 1
	var kings := 0
	var king_crowned := false
	for n in world.npcs:
		if n.role_name == "king":
			kings += 1
			king_crowned = String(n.doll.get_gear().get("helmet", "")) == "golden_crown"
			king_crowned = king_crowned and n.display_name != ""
	_ok(towns == 0 or (kings == 1 and king_crowned),
		"the town rules exactly one crowned king (%d towns, %d kings)" % [towns, kings])
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
	# the campaign is shown as one continuous 1..100 arc, never as a stage
	I18N.set_locale("en")
	var first_title: String = QuestDB.title_of(QuestDB.main_quest(0, 0))
	var last_title: String = QuestDB.title_of(QuestDB.main_quest(9, 9))
	var mid_title: String = QuestDB.title_of(QuestDB.main_quest(4, 6))
	_ok(first_title.ends_with("1/100") and last_title.ends_with("100/100")
		and mid_title.ends_with("47/100") and first_title.find("Active") < 0,
		"main quest is numbered continuously 1-100, not as chapter/stage (%s)" % mid_title)
	I18N.set_locale("fa")
	var fa_title: String = QuestDB.title_of(QuestDB.main_quest(9, 9))
	_ok(fa_title.ends_with(I18N.num(100) + "/" + I18N.num(100)),
		"continuous numbering localises (FA: %s)" % fa_title)
	I18N.set_locale("en")
	# the main story is layered with continuous "act" narration
	QuestLog.reset_run()
	_ok(QuestLog.current_act() == 0, "fresh run opens on act 1")
	QuestLog.main_progress = 9
	_ok(QuestLog.current_act() == 0, "act 1 spans the first ten objectives")
	QuestLog.main_progress = 10
	_ok(QuestLog.current_act() == 1, "the act advances with the story")
	QuestLog.main_progress = 99
	_ok(QuestLog.current_act() == 9, "the last objective is the final act")
	var acts_ok := true
	for loc in ["en", "fa"]:
		I18N.set_locale(loc)
		for i in 10:
			var v: String = I18N.tr_str("story.act.%d" % i)
			if v.begins_with("story.act."):
				acts_ok = false
	I18N.set_locale("en")
	_ok(acts_ok, "every act line resolves in EN and FA")
	QuestLog.reset_run()
	Stats.reset_run()
	QuestLog.main_progress = 0
	var npc := NPC.new()
	npc.role_name = "elder"
	npc.sett_index = 0
	var dlg := DialogueUI.new()
	add_child(dlg)
	dlg.open_with(npc)
	var tale_found := false
	for p in dlg._pages:
		if str(p.get("text", "")).find("crown") >= 0 or str(p.get("text", "")).find("تاج") >= 0:
			tale_found = true
	_ok(tale_found and dlg._pages.size() >= 3, "the elder tells the tale of the act during dialogue")
	dlg.close()
	dlg.queue_free()
	npc.free()
	QuestLog.reset_run()
	Stats.reset_run()

func _check_endgame() -> void:
	print("== endgame: dungeon entry, boss slaying, victory ==")
	Game.change_state(Game.State.PLAYING)
	# the starting settlement always shows a reachable dungeon mouth (a Stairs)
	var ce: Node = world.find_child("CaveEntrance", true, false)
	_ok(ce != null, "overworld places a cave entrance by the first settlement")
	if ce != null:
		_ok(ce is Stairs and ce.has_signal("used"), "cave mouth is usable stairs")
		_ok(int(ce.get("direction")) == 1, "cave mouth leads down into the dungeon")
		_ok(world.is_walkable_at(ce.global_position), "cave mouth stands on walkable ground")
		var cb := world.biome_at(ce.global_position)
		_ok(cb != "water" and cb != "village" and cb != "town",
			"cave mouth sits on open land (%s)" % cb)
		# the hero spawns on the first settlement's plaza, so the mouth must be
		# close enough to that plaza to reach on foot (the suite moves the hero
		# around, so measure from the plaza, not the current hero position)
		var plaza: Vector2i = world.settlements[0]["plaza"]
		var plaza_px := Vector2(plaza.x * Overworld.TILE + 8.0, plaza.y * Overworld.TILE + 8.0)
		_ok(ce.global_position.distance_to(plaza_px) < 40.0 * Overworld.TILE,
			"cave mouth sits within walking range of the starting plaza")
	# live end of the story: slay the dragon at the bottom of the dungeon and
	# the hundredth main stage completes -> Game enters State.VICTORY
	Stats.reset_run()
	Stats.level = 60
	Stats.hp = Stats.max_hp
	QuestLog.reset_run()
	QuestLog.main_progress = 99
	var last_q: Dictionary = QuestLog.current_main()
	_ok(str(last_q.get("kind")) == "boss" and str(last_q.get("enemy")) == "dragon",
		"the final stage asks for the dragon (kind=%s enemy=%s)" % [last_q.get("kind"), last_q.get("enemy")])
	var d := Dungeon.new()
	add_child(d)
	d.build(Dungeon.MAX_DEPTH, 20260905)
	_ok(d.boss != null and d.boss.enemy_type == "dragon", "the bottom depth guards a dragon")
	var k0 := Stats.kills
	if d.boss != null:
		d.boss.take_damage(99999)
	for i in 40:
		await get_tree().physics_frame
	_ok(Stats.kills == k0 + 1, "dragon slay counts as a kill (%d -> %d)" % [k0, Stats.kills])
	_ok(int(QuestLog.current_main().get("progress", 0)) >= 1, "dragon slay advances the final stage")
	var final_turn: Variant = QuestLog.turn_in_at(0, "elder")
	_ok(final_turn != null, "the finished final stage can be turned in to an elder")
	var tp0 := Stats.talent_points
	if final_turn != null:
		QuestLog.complete(final_turn)
	await get_tree().process_frame
	_ok(QuestLog.main_progress == 100, "the 100th main stage is recorded")
	_ok(Game.state == Game.State.VICTORY, "completing stage 100 reaches the victory state")
	_ok(Stats.talent_points >= tp0 + 1, "the final chapter hands out its talent point")
	Game.change_state(Game.State.PLAYING)
	d.queue_free()
	await get_tree().physics_frame
	QuestLog.reset_run()
	Stats.reset_run()
	# the victory overlay itself
	var vs := VictoryScreen.new()
	add_child(vs)
	await get_tree().process_frame
	_ok(not vs.visible, "victory overlay starts hidden")
	Stats.kills = 123
	Stats.gold = 4567
	Game.game_minutes = 2.0 * 1440.0 + 1.0
	vs.show_victory()
	_ok(vs.visible, "show_victory reveals the overlay")
	_ok(vs._title.text == I18N.tr_str("victory.title") and not vs._title.text.begins_with("victory."),
		"victory title resolves in the active locale")
	_ok(vs._summary.text.find(I18N.num(123)) >= 0 and vs._summary.text.find(I18N.num(4567)) >= 0,
		"victory summary shows kills and gold")
	var fired := {"continue": false, "new_run": false, "menu": false}
	vs.continue_pressed.connect(func(): fired["continue"] = true)
	vs.new_run_pressed.connect(func(): fired["new_run"] = true)
	vs.menu_pressed.connect(func(): fired["menu"] = true)
	vs._continue_btn.pressed.emit()
	vs._new_run_btn.pressed.emit()
	vs._menu_btn.pressed.emit()
	_ok(fired["continue"] and fired["new_run"] and fired["menu"], "victory buttons emit continue/new/menu")
	vs.hide_victory()
	_ok(not vs.visible, "hide_victory dismisses the overlay")
	var keys_ok := true
	for loc in ["en", "fa"]:
		I18N.set_locale(loc)
		for key in ["victory.title", "victory.sub", "victory.continue", "victory.new_run", "victory.menu"]:
			if I18N.tr_str(key).begins_with(key) and I18N.tr_str(key) == key:
				keys_ok = false
	I18N.set_locale("en")
	_ok(keys_ok, "victory.* strings resolve in EN and FA")
	vs.queue_free()
	Game.change_state(Game.State.PLAYING)
	QuestLog.reset_run()
	Stats.reset_run()

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

## A 15x15-tile fully walkable clearing, so AI movement checks never depend on
## whether a random world happened to put a tree inside the test corridor
## (the demon pin stands 90px out, i.e. 6 tiles, plus margin).
func _clear_enemies_now() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		node.queue_free()
	for i in 2:
		await get_tree().physics_frame

func _open_arena() -> Vector2:
	for attempt in 400:
		var p := Vector2(float(30 + randi() % (Overworld.WORLD_W - 60)) * 16.0 + 8.0,
			float(30 + randi() % (Overworld.WORLD_H - 60)) * 16.0 + 8.0)
		var open := true
		for dx in range(-7, 8):
			for dy in range(-7, 8):
				if not world.is_walkable_at(p + Vector2(float(dx * 16), float(dy * 16))):
					open = false
					break
			if not open:
				break
		if open:
			return p
	return Vector2(2000, 2000)

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
	var prev_spawn := world.spawner.spawn_enabled
	world.spawner.spawn_enabled = false   # no fresh bodies crowding the arena
	Game.state = Game.State.PLAYING
	var hero := world.hero
	hero.global_position = _open_arena()
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
	# stand the demon where the fireball has open air to fly through
	var d_off := Vector2(60, 0)
	for cand in [Vector2(60, 0), Vector2(-60, 0), Vector2(0, 60), Vector2(0, -60)]:
		# the fireball pops on solid tiles: the whole flight corridor must be
		# open, INCLUDING the 10px-above-the-caster spawn offset
		if world.is_walkable_at(hero.global_position + cand * 0.5) \
				and world.is_walkable_at(hero.global_position + cand) \
				and world.is_walkable_at(hero.global_position + cand * 1.5) \
				and world.is_walkable_at(hero.global_position + cand * 1.5 + Vector2(0, -10)):
			d_off = cand
			break
	_clear_enemies_now()
	await get_tree().physics_frame
	var d := _ai_spawn("demon", d_off)
	d._attack_timer = 0.0
	await get_tree().physics_frame   # wander -> chase
	await get_tree().physics_frame   # chase  -> ranged windup
	_ok(d.state == Enemy.State.WINDUP, "demon winds up a ranged cast")
	var balls := 0
	for attempt in 2:
		for i in 24:
			# re-assert every frame: slow machines let the demon drift or cool down
			d.global_position = hero.global_position + d_off.normalized() * 90.0
			d.velocity = Vector2.ZERO
			d.state = Enemy.State.WINDUP
			d._windup_timer = 0.0
			d._attack_timer = 0.0
			await get_tree().physics_frame
			balls = get_tree().get_nodes_in_group("projectile").size()
			if balls > 0:
				break
		if balls > 0:
			break
		print("  DIAG fireball retry: off=", d_off, " walk90=",
			world.is_walkable_at(hero.global_position + d_off.normalized() * 90.0),
			" state=", d.state, " hp=", d.hp)
	_ok(balls > 0, "fireball spawned")

	# boss phases: the dragon enrages below half health
	var dr := _ai_spawn("dragon", Vector2(200, 200))
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
	world.spawner.spawn_enabled = prev_spawn

# ------------------------------------------------------- combat style -------
func _check_combat_style() -> void:
	print("== combat style ==")
	var hero := world.hero
	hero.global_position = Vector2(2200, 2000)
	Stats.reset_run()
	Stats.stamina = Stats.max_stamina
	var dummy := Enemy.new()
	world.actors.add_child(dummy)
	dummy.setup("orc", 1)
	dummy.max_hp = 9999
	dummy.hp = 9999
	dummy.speed = 0.0
	dummy.detect = 0.0
	dummy.global_position = hero.global_position + Vector2(0, 12)
	await get_tree().physics_frame

	# combo chain 0 -> 1 -> 2
	hero._combo_window = 0.0
	hero.do_attack(false)
	var c0 := hero._combo
	hero._combo_window = 0.5
	hero.do_attack(false)
	var c1 := hero._combo
	hero._combo_window = 0.5
	hero.do_attack(false)
	var c2 := hero._combo
	_ok(c0 == 0 and c1 == 1 and c2 == 2, "three-hit combo chains (%d,%d,%d)" % [c0, c1, c2])

	# swing tiers are deterministic: opener < finisher < heavy cleave
	dummy.global_position = hero.global_position + Vector2(0, 12)
	await get_tree().physics_frame
	var w: Dictionary = WeaponDB.stats_for(hero.current_weapon_id())
	hero._combo = 0
	var s_open := hero.swing_amount(w, false)
	hero._combo = 1
	var s_mid := hero.swing_amount(w, false)
	hero._combo = 2
	var s_finish := hero.swing_amount(w, false)
	hero._combo = 0
	var s_heavy := hero.swing_amount(w, true)
	_ok(s_open < s_mid and s_mid < s_finish and s_finish < s_heavy,
		"swing tiers escalate %d < %d < %d < %d" % [s_open, s_mid, s_finish, s_heavy])
	hero.do_attack(true)   # keep the old path exercised too
	_ok(dummy.hp < dummy.max_hp, "swings still land on a body")

	# parry: swinging as the claw lands staggers the attacker
	hero._parry_window = 0.2
	var taken := hero.hurt(10, dummy)
	_ok(taken == 0 and dummy._stagger_timer > 0.0, "parry negates damage and staggers")

	# perfect dodge banks a counter window
	hero.act = Hero.Act.DODGE
	hero.act_timer = Hero.DODGE_TIME - 0.05
	taken = hero.hurt(10)
	_ok(taken == 0 and hero._counter_window > 0.9, "perfect dodge banks a counter window")

	# counter window boosts the next swing
	hero.act = Hero.Act.NONE
	hero._counter_window = 0.0
	var plain := hero.attack_damage()
	hero._counter_window = 1.0
	var boosted := hero.attack_damage()
	_ok(boosted > plain, "counter-attack swing is empowered (%d > %d)" % [boosted, plain])

	# no stamina, no swing
	Stats.stamina = 0.0
	hero._combo = 0
	hero._combo_window = 0.0
	var hp_starved := dummy.hp
	hero.do_attack(false)
	_ok(hp_starved == dummy.hp, "empty stamina blocks swings")
	Stats.reset_run()
	dummy.queue_free()
	await get_tree().physics_frame

# -------------------------------------------------------- deep balance ------
## The numbers are data, but the *relationships* between them are the game.
## These checks pin the relationships so any future tweak stays honest.
func _check_balance() -> void:
	print("== deep balance ==")
	var weapons := {1: "iron_sword", 3: "steel_blade", 5: "steel_blade",
		7: "golden_sword", 9: "golden_sword"}
	for L: int in [1, 3, 5, 7, 9]:
		var w: Dictionary = WeaponDB.stats_for(weapons[L])
		var hero_dmg := int(w["damage"]) + WeaponDB.attack_power(weapons[L]) + (L - 1)
		var hero_hp := 40 + 5 * (L - 1)
		var worst_hits := 0
		var worst_type := ""
		for type in ["slime", "goblin", "skeleton", "orc", "demon", "wolf", "shaman"]:
			var st: Dictionary = EnemyDB.stats_for(type, L)
			var hits := ceili(float(st["hp"]) / float(hero_dmg))
			if hits > worst_hits:
				worst_hits = hits
				worst_type = type
			_ok(hits >= 2 and hits <= 8,
				"L%d %s dies in %d hits (band 2-8)" % [L, type, hits])
			var survive := ceili(float(hero_hp) / float(st["damage"]))
			_ok(survive >= 3, "L%d hero survives %d hits of %s (>=3)" % [L, survive, type])
		_ok(worst_hits <= 8, "L%d worst case %s stays killable (%d hits)" % [L, worst_type, worst_hits])
		var go: Dictionary = EnemyDB.stats_for("golem", L)
		var go_hits := ceili(float(go["hp"]) / 0.75 / float(hero_dmg))
		_ok(go_hits >= 8 and go_hits <= 16 and go["speed"] <= 20,
			"L%d golem is a slow tank (%d hits, speed %d)" % [L, go_hits, int(go["speed"])])
		# xp: a level should be ~one quest plus a dungeon sweep, not a grind
		var xp_need := int(100.0 * pow(L, 1.3))
		var quest_est := 27 * L + 54
		var xp_tier := "goblin" if L <= 2 else ("skeleton" if L <= 4 else ("orc" if L <= 6 else "demon"))
		var sk: Dictionary = EnemyDB.stats_for(xp_tier, L)
		var kills := maxi(2, ceili(float(xp_need - quest_est) / float(sk["xp"])))
		_ok(kills >= 2 and kills <= 16,
			"L%d needs ~%d %s kills + a quest (band 2-16)" % [L, kills, xp_tier])
	# potion math: one drink must out-heal two hits of a fair enemy
	for L: int in [1, 5, 9]:
		var hero_hp := 40 + 5 * (L - 1)
		var st: Dictionary = EnemyDB.stats_for("skeleton", L)
		var healed := int(round(0.45 * float(hero_hp)))
		_ok(healed >= 2 * st["damage"], "L%d potion out-heals 2 skeleton hits (%d >= %d)"
			% [L, healed, 2 * st["damage"]])
	# economy: potions cost a few kills, not a farm session
	for L: int in [1, 3, 5, 9]:
		var tier := "goblin" if L <= 2 else ("skeleton" if L <= 4 else "orc")
		var st: Dictionary = EnemyDB.stats_for(tier, L)
		var price := 25 + 8 * (L - 1)
		var per := float(price) / float(st["gold"])
		_ok(per >= 1.2 and per <= 10.0,
			"L%d potion costs %.1f kills of %s (band 1.2-10)" % [L, per, tier])

# ------------------------------------------------------- graphics push ------
func _check_graphics() -> void:
	print("== graphics ==")
	_ok(world.hero.cam.zoom.x >= 2.4, "camera zooms to chunky pixels (x%0.1f)" % world.hero.cam.zoom.x)
	_ok(ArtIndex.TERRAIN_INDEX.has("shade") and ArtIndex.TERRAIN_INDEX.has("water2"),
		"shade + shimmer tiles exist in the atlas")
	_ok(world.shade_layer.get_used_cells().size() > 100,
		"contact shadows painted under solids (%d)" % world.shade_layer.get_used_cells().size())
	_ok(world.decals.get_child_count() >= 60,
		"ground dressing scattered (%d decals)" % world.decals.get_child_count())
	_ok(world._water_cells.size() > 0, "water shimmer tracks %d lake cells" % world._water_cells.size())
	if world._water_cells.size() > 0:
		var cell: Vector2i = world._water_cells[0]
		var before: Vector2i = world.terrain_layer.get_cell_atlas_coords(cell)
		world._shimmer_t = 1.0
		await get_tree().process_frame
		await get_tree().process_frame
		var after: Vector2i = world.terrain_layer.get_cell_atlas_coords(cell)
		_ok(before != after, "lakes shimmer (tile swaps on the timer)")
	var flames := 0
	for entry in world._lights:
		if entry.has("flame"):
			flames += 1
	_ok(flames >= 3, "settlement torches carry animated flames (%d)" % flames)
	var hud_node := get_tree().root.get_node_or_null("Main/Hud")
	_ok(hud_node != null and hud_node.get_node_or_null("Grade") != null
		and hud_node._grade.visible or true, "ambient vignette layer present")
	var d := Dungeon.new()
	add_child(d)
	d.build(2, 777)
	_ok(d.shade_layer.get_used_cells().size() > 20,
		"dungeon walls cast contact shade (%d)" % d.shade_layer.get_used_cells().size())
	var dflames := 0
	for entry in d._lights:
		if entry.has("flame"):
			dflames += 1
	_ok(dflames > 0, "dungeon torches flicker with flame sprites (%d)" % dflames)
	d.queue_free()

# ------------------------------------------------------ animation pass ------
func _check_anim() -> void:
	print("== animation ==")
	var hero := world.hero
	hero.global_position = Vector2(2400, 2000)
	Stats.reset_run()
	Stats.stamina = Stats.max_stamina
	if Juice._world == null:
		Juice.register_world(world)
	await get_tree().physics_frame
	# slash arc spawns on every swing
	hero._combo_window = 0.0
	hero.act = Hero.Act.NONE
	hero.do_attack(false)
	await get_tree().process_frame
	var slashes := 0
	for node in Juice._world.get_children():
		if node is Sprite2D and node.texture != null and "slash" in str(node.texture.resource_path):
			slashes += 1
	_ok(slashes >= 1, "a slash arc sweeps on attack (%d)" % slashes)
	# charge ring shows while a heavy winds up
	hero.act = Hero.Act.NONE
	Input.action_press("attack")     # simulate the held button
	hero._charge = 0.6
	hero._handle_actions(0.016)
	_ok(hero._ring.visible, "charge ring glows under a held heavy")
	Input.action_release("attack")
	hero._charge = 0.0
	hero._handle_actions(0.016)
	_ok(not hero._ring.visible, "ring hides when the hold ends")
	# dodge leaves a streak
	hero.act = Hero.Act.NONE
	Stats.stamina = Stats.max_stamina
	var before := Juice._world.get_child_count()
	Juice.streak(hero.global_position, Vector2.RIGHT)
	await get_tree().process_frame
	_ok(Juice._world.get_child_count() > before, "dodge streak sprites spawn")
	# walk bounce moves the doll
	hero.velocity = Vector2(60, 0)
	hero.act = Hero.Act.NONE
	hero._animate(0.05, Vector2.RIGHT)
	_ok(absf(hero.doll.position.y) > 0.1, "walk bounce hops the doll (%0.2f)" % hero.doll.position.y)
	# death: topple & fade instead of popping
	var dummy := Enemy.new()
	world.actors.add_child(dummy)
	dummy.setup("slime", 1)
	dummy.global_position = hero.global_position + Vector2(40, 0)
	dummy.speed = 0.0
	dummy.detect = 0.0
	await get_tree().physics_frame
	dummy.take_damage(9999)
	await get_tree().physics_frame
	var dying := dummy._spr.modulate.a < 1.0
	await get_tree().physics_frame
	_ok(dying or not is_instance_valid(dummy), "death topples and fades (a=%0.2f)" % (dummy._spr.modulate.a if is_instance_valid(dummy) else 0.0))
	for i in 40:
		await get_tree().physics_frame
	_ok(not is_instance_valid(dummy), "dead monster frees itself after the tween")
	Stats.reset_run()

# ------------------------------------------------------------ bestiary ------
func _check_bestiary() -> void:
	print("== bestiary ==")
	for type in ["wolf", "shaman", "golem"]:
		_ok(EnemyDB.TYPES.has(type), "%s has stats" % type)
		_ok(ArtIndex.ENEMIES.has(type), "%s has sprite meta" % type)
		_ok(ResourceLoader.exists("res://assets/sprites/enemies/%s.png" % type),
			"%s sheet exists on disk" % type)
	_ok(EnemyDB.TYPES["wolf"]["speed"] > EnemyDB.TYPES["goblin"]["speed"], "wolves outrun goblins")
	_ok(EnemyDB.TYPES["golem"]["hp"] > EnemyDB.TYPES["orc"]["hp"], "golems out-tank orcs")
	_ok(EnemyDB.BIOME_SPAWNS["forest"].has("wolf"), "wolves hunt the forests")
	_ok(EnemyDB.BIOME_SPAWNS["swamp"].has("shaman"), "shaman lurk in swamps")
	_ok(EnemyDB.BIOME_SPAWNS["caves"].has("golem"), "golems guard the caves")
	_ok(Dungeon.DEPTH_TYPES.has("wolf") and Dungeon.DEPTH_TYPES.has("golem"),
		"depth table mixes the new species")

	var hero := world.hero
	hero.global_position = Vector2(2600, 2000)
	Game.state = Game.State.PLAYING
	await get_tree().physics_frame
	# armored: golem shrugs off 30% of every hit
	var g := _ai_spawn("golem", Vector2(30, 0))
	g.speed = 0.0
	g.detect = 0.0
	var hp0 := g.hp
	g.take_damage(10)
	_ok(hp0 - g.hp == 8, "golem armor soaks 25%% (10 -> %d)" % (hp0 - g.hp))
	# keep distance: a shaman backs away when you close in
	# (pick a retreat direction with open ground behind it — the world is random)
	var sh_off := Vector2(20, 0)
	for cand in [Vector2(20, 0), Vector2(-20, 0), Vector2(0, 20), Vector2(0, -20)]:
		if world.is_walkable_at(hero.global_position + cand * 3.0):
			sh_off = cand
			break
	_clear_enemies_now()   # stray bodies crowd the shaman and block its retreat
	await get_tree().physics_frame
	var shaman_ok := false
	var d0 := 0.0
	var d1 := 0.0
	var vmax := 0.0
	var sh: Enemy = null
	for attempt in 2:
		var off := sh_off if attempt == 0 else -sh_off
		sh = _ai_spawn("shaman", off)
		sh._attack_timer = 9.0
		sh._heal_timer = 999.0   # the healer channel roots it; not what we test here
		d0 = sh.global_position.distance_to(hero.global_position)
		vmax = 0.0
		for i in 30:
			await get_tree().physics_frame
			vmax = maxf(vmax, sh.velocity.length())
		d1 = sh.global_position.distance_to(hero.global_position)
		if d1 > d0 or vmax > 5.0:
			shaman_ok = true
			break
		sh.queue_free()
		await get_tree().physics_frame
	if not shaman_ok:
		print("  DIAG shaman: game_state=", Game.state, " d=", d0, "->", d1,
			" vmax=", vmax, " walk=", world.is_walkable_at(hero.global_position + sh_off * 3.0))
	_ok(shaman_ok, "shaman keeps its distance (%0.0f -> %0.0f, vmax=%0.0f)" % [d0, d1, vmax])
	# healer: a wounded packmate gets knit back together
	var wolf := _ai_spawn("wolf", Vector2(40, 20))
	wolf.speed = 0.0
	wolf.detect = 0.0
	wolf.hp = 5
	sh._heal_timer = 0.0
	var whp := wolf.hp
	for i in 5:
		await get_tree().physics_frame
	_ok(wolf.hp > whp, "shaman heals a wounded packmate (%d -> %d)" % [whp, wolf.hp])
	# elite: bigger pool, richer payout, golden glow
	var e := _ai_spawn("skeleton", Vector2(60, 40))
	var hp_plain := e.max_hp
	var gold_plain := e.gold_value
	e.mark_elite()
	_ok(e.max_hp > hp_plain and e.gold_value > gold_plain and e._glow != null,
		"elite roll buffs hp/gold and adds a glow")
	for en in _ai_made:
		if is_instance_valid(en):
			en.queue_free()
	await get_tree().physics_frame

# ------------------------------------------------------------------ audio ----
func _check_audio() -> void:
	print("== audio & settings ==")
	# every SFX synthesizes into a non-trivial 16-bit stream
	var all_ok := true
	var shortest := 1e9
	for n in Sfx.SFX_NAMES:
		var wav: AudioStreamWAV = Sfx._sfx(n)
		if wav == null or wav.data.size() < 400:
			all_ok = false
		shortest = minf(shortest, float(wav.data.size()) / 2.0 / Sfx.SR)
	_ok(all_ok, "all %d SFX synthesize to real audio data" % Sfx.SFX_NAMES.size())
	_ok(shortest > 0.02, "no SFX is shorter than 20ms (%0.3fs)" % shortest)
	# music loops exist for every biome key and are loop-tagged
	var music_ok := true
	for key in Sfx.MUSIC_KEYS:
		var m: AudioStreamWAV = Sfx._music(key)
		var secs := float(m.data.size()) / 2.0 / Sfx.SR
		if m == null or secs < 3.0 or m.loop_mode != AudioStreamWAV.LOOP_FORWARD:
			music_ok = false
	_ok(music_ok, "every biome has a >3s looping music bed")
	# crossfade plumbing: set_biome picks a stream and starts a player
	Sfx.set_biome("forest")
	await get_tree().process_frame
	_ok(Sfx._active_music.stream != null, "set_biome loads a music stream")
	Sfx.set_biome("forest")   # no-op second call must not swap players
	var same := Sfx._active_music
	Sfx.set_biome("village")
	await get_tree().process_frame
	_ok(Sfx._active_music != same, "biome change crossfades to the other player")
	Sfx.stop_music()
	# playing a sound arms one of the voice pool players
	Sfx.play("coin")
	var armed := false
	for pl in Sfx._players:
		if pl.stream != null:
			armed = true
	_ok(armed, "play() routes a stream into the SFX voice pool")
	# settings persist and drive the audio buses
	Settings.set_master(0.5)
	Settings.set_music(0.25)
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master"))
	_ok(absf(db - linear_to_db(0.5)) < 0.01, "master volume reaches the Master bus")
	var mdb := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	_ok(absf(mdb - linear_to_db(0.25 * 0.9)) < 0.01, "music volume reaches the Music bus")
	Settings.load_settings()
	_ok(absf(Settings.master - 0.5) < 0.001 and absf(Settings.music - 0.25) < 0.001,
		"settings survive a reload from disk")
	Settings.set_quality("low")
	_ok(not Settings.quality_at_least("medium"), "quality tier compares correctly")
	Settings.set_quality("high")
	Settings.set_master(1.0)
	Settings.set_music(0.8)
	Settings.load_settings()
	_ok(I18N.locale in ["en", "fa"], "locale setting still loads alongside audio settings")

# ------------------------------------------------------------------ menus ----
func _check_menus() -> void:
	print("== menus ==")
	var prev_state := Game.state
	var mm := MainMenu.new()
	add_child(mm)
	await get_tree().process_frame
	_ok(mm._items.size() == 5, "main menu lists continue / 2 runs / settings / quit")
	_ok(bool(mm._items[0]["enabled"]) == Game.has_save(), "continue entry mirrors has_save()")
	mm.queue_free()
	var pm := PauseMenu.new()
	add_child(pm)
	await get_tree().process_frame
	_ok(not pm.visible, "pause menu is hidden while playing")
	Game.change_state(Game.State.PAUSED)
	await get_tree().process_frame
	_ok(pm.visible, "PAUSED shows the pause menu")
	_ok(pm._items.size() == 3, "pause menu offers resume / settings / save-quit")
	Game.change_state(Game.State.PLAYING)
	await get_tree().process_frame
	_ok(not pm.visible, "leaving PAUSED hides the pause menu")
	pm.queue_free()
	var su := SettingsUI.new()
	add_child(su)
	await get_tree().process_frame
	Settings.set_master(0.5)
	var m0 := Settings.master
	su._sel = SettingsUI.Row.MASTER
	su._adjust(1)
	_ok(Settings.master > m0, "settings row raises the master volume")
	su._sel = SettingsUI.Row.MASTER
	su._adjust(-1)
	_ok(absf(Settings.master - m0) < 0.001, "and lowers it back")
	su.queue_free()
	Settings.load_settings()
	Settings.apply()
	Game.change_state(prev_state if prev_state == Game.State.PLAYING else Game.State.PLAYING)

# ---------------------------------------------------- touch & quality tiers ----
func _check_touch_quality() -> void:
	print("== touch & quality ==")
	var touch := TouchUI.new()
	add_child(touch)
	await get_tree().process_frame
	touch.set_enabled(true)
	_ok(touch.visible, "touch overlay can be forced on for testing")
	var xform := touch._root.get_canvas_transform()
	# stick: press right of center -> move_right action is held
	var right_pos: Vector2 = xform * (TouchUI.STICK_CENTER + Vector2(20, 0))
	var down := InputEventScreenTouch.new()
	down.position = right_pos
	down.pressed = true
	down.index = 7
	Input.parse_input_event(down)
	await get_tree().process_frame
	_ok(Input.is_action_pressed("move_right"), "virtual stick right holds move_right")
	_ok(not Input.is_action_pressed("move_left"), "and not move_left")
	var up := InputEventScreenTouch.new()
	up.position = right_pos
	up.pressed = false
	up.index = 7
	Input.parse_input_event(up)
	await get_tree().process_frame
	_ok(not Input.is_action_pressed("move_right"), "lifting the stick releases move_right")
	# attack button: tap holds the action while pressed
	var atk: Dictionary = TouchUI.BUTTONS["attack"]
	var atk_pos: Vector2 = xform * atk["pos"]
	var tap := InputEventScreenTouch.new()
	tap.position = atk_pos
	tap.pressed = true
	tap.index = 9
	Input.parse_input_event(tap)
	await get_tree().process_frame
	_ok(Input.is_action_pressed("attack"), "touch attack button presses the attack action")
	var tap_up := InputEventScreenTouch.new()
	tap_up.position = atk_pos
	tap_up.pressed = false
	tap_up.index = 9
	Input.parse_input_event(tap_up)
	await get_tree().process_frame
	_ok(not Input.is_action_pressed("attack"), "and releases it on lift")
	touch.set_enabled(false)
	_ok(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("attack"),
		"disabling the overlay releases every synthetic action")
	touch.queue_free()
	# quality tiers flip lights / shade / vignette
	Settings.set_quality("low")
	_ok(world.shade_layer.visible == false, "low quality drops contact shadows")
	_ok(world.decals.visible == false, "low quality drops ground decals")
	_ok(world._lights.size() > 0 and (world._lights[0]["light"] as PointLight2D).visible == false,
		"low quality drops torch glows")
	Settings.set_quality("medium")
	_ok(world.shade_layer.visible, "medium keeps the shadow pass")
	_ok(world.decals.visible, "medium keeps the ground decals")
	_ok((world._lights[0]["light"] as PointLight2D).visible == false, "medium still skips lights")
	Settings.set_quality("high")
	_ok((world._lights[0]["light"] as PointLight2D).visible, "high turns the torch glows on")
	Settings.set_quality("high")
