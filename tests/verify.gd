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
	_check_i18n()

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
	for name in ["I18N", "Game", "Stats", "Juice"]:
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
func _check_combat() -> void:
	print("== combat ==")
	Game.change_state(Game.State.PLAYING)
	Stats.reset_run()
	await get_tree().physics_frame

	_ok(world.spawner != null, "world owns a spawner")
	world.spawner.spawn_enabled = false

	var hero: Hero = world.hero
	var slime := world.spawner.spawn("slime", hero.global_position + Vector2(40, 0), 1)
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
