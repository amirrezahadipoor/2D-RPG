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
	var hero: Hero = _hero()
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

	print("[screenshot] done")
	get_tree().quit(0)

func _hero() -> Hero:
	for child in get_tree().root.get_children():
		var h: Node = child.get_node_or_null("Overworld/Hero")
		if h is Hero:
			return h
	return null

func _grab(label: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path := OUT_DIR + label + ".png"
	img.save_png(path)
	print("[screenshot] " + path + "  " + str(img.get_size()))
