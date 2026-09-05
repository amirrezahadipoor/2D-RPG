# A hurled fireball (demon / dragon breath). Travels in a straight line,
# pops on the hero, on walls, or when its fuel runs out.
class_name Projectile
extends Node2D

var direction := Vector2.ZERO
var speed := 95.0
var damage := 5
var life := 2.6

var _spr: Sprite2D
var _core: ColorRect
var _owner_node: Node = null

func setup(dir: Vector2, dmg: int) -> void:
	direction = dir
	damage = dmg
	add_to_group("projectile")
	_spr = Sprite2D.new()
	_spr.texture = load("res://assets/sprites/fx/glow.png")
	_spr.color = Color(1.0, 0.45, 0.15)
	_spr.scale = Vector2(0.45, 0.45)
	add_child(_spr)
	_core = ColorRect.new()
	_core.color = Color(1.0, 0.85, 0.4)
	_core.size = Vector2(3, 3)
	_core.position = Vector2(-1.5, -1.5)
	add_child(_core)

func _process(delta: float) -> void:
	global_position += direction * speed * delta
	life -= delta
	if life <= 0.0:
		_pop(false)
		return
	if _owner_node == null or not is_instance_valid(_owner_node):
		_owner_node = get_parent()
		while _owner_node != null and not _owner_node.has_method("is_walkable_at"):
			_owner_node = _owner_node.get_parent()
	if _owner_node != null and not _owner_node.is_walkable_at(global_position):
		_pop(false)
		return
	var hero := get_tree().get_first_node_in_group("player") as Node2D
	if hero != null and global_position.distance_to(hero.global_position) < 10.0:
		var landed := int(hero.hurt(damage)) if hero.has_method("hurt") else Stats.damage(damage)
		if landed > 0:
			Juice.hurt()
			Juice.shake(2.5)
		_pop(true)

func _pop(hit: bool) -> void:
	if hit:
		Juice.puff(global_position)
	queue_free()
