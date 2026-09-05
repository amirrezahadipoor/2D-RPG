extends Node
var main: Node
var stage := 0
var t := 0.0
var f := 0

func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	main.name = "Main"
	get_tree().root.add_child.call_deferred(main)

func _process(d: float) -> void:
	if main == null or main.get_node_or_null("Overworld") == null:
		return
	f += 1
	t += d
	if t < 5.0:
		return
	print("PERF stage=", stage, " fps=", snapped(f / t, 0.1))
	f = 0
	t = 0.0
	stage += 1
	match stage:
		1:
			for e in get_tree().get_nodes_in_group("enemy"):
				e.queue_free()
			main.world.spawner.spawn_enabled = false
		2:
			for n in main.world.npcs.duplicate():
				n.queue_free()
		3:
			main.world.ambient.set_process(false)
			main.world.ambient.visible = false
		4:
			main.hud.visible = false
		5:
			main.world.hero.visible = false
			main.world.hero.set_process(false)
			main.world.hero.set_physics_process(false)
		6:
			for layer in [main.world.terrain_layer, main.world.props_layer, main.world.shade_layer]:
				if layer != null:
					layer.visible = false
		7:
			main.world.set_process(false)
			main.world.spawner.set_process(false)
		8:
			for n in [main.hud, main.dialogue, main.inv_screen, main.journal,
					main.talents, main.cutscene, main.events]:
				if n != null:
					n.set_process(false)
					for c in n.get_children():
						c.set_process(false)
		9:
			Juice.set_process(false)
			Game.set_process(false)
		10:
			print("PERF nodes=", get_tree().get_node_count())
			get_tree().quit(0)
