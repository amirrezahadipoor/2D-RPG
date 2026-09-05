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
	for name in ["I18N", "Game", "Stats"]:
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
