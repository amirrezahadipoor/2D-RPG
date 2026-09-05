# Paper-doll renderer.
#
# The whole point: equipped items are NOT baked into one sprite. Each slot is
# its own Sprite2D layer sharing one animation grid, so swapping a helmet or a
# sword visibly changes the character in-game, in every direction and frame.
#
# Layer stack (back -> front). The cloak sits BEHIND the body so from the
# front only its edges show; armour plates sit ON TOP of the base body.
#
#   accessory -> body -> legs -> boots -> chest -> helmet -> weapon
#
# Every sheet uses the same grid (see tools/gen_assets.py + ArtIndex):
#   cell 24x32, 8 columns x 4 rows, rows = down/up/left/right.
# Because the grids match, one frame index drives every layer in sync.
class_name PaperDoll
extends Node2D

const STACK := ["accessory", "body", "legs", "boots", "chest", "helmet", "weapon"]

## Feet anchor inside the 24x32 cell. Sprite offsets put this pixel exactly on
## the node's position, so the doll's origin is the character's ground point.
const FEET_OFFSET := Vector2(-12, -30)

var _layers: Dictionary = {}
var _row: int = 0
var _col: int = 0
var _gear: Dictionary = {}

func _ready() -> void:
	for slot_name in STACK:
		var spr := Sprite2D.new()
		spr.name = "Layer_" + slot_name
		spr.centered = false
		spr.offset = FEET_OFFSET
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.region_enabled = true
		add_child(spr)
		_layers[slot_name] = spr
	set_body()
	_apply_region()

# ---------------------------------------------------------------- gear ------
func set_body() -> void:
	_layers["body"].texture = load("res://assets/sprites/hero/body.png")

func equip(slot: String, item_id: String) -> void:
	if slot not in STACK or slot == "body":
		push_warning("[PaperDoll] unknown slot: " + slot)
		return
	_gear[slot] = item_id
	var spr: Sprite2D = _layers[slot]
	if item_id.is_empty():
		spr.texture = null
		return
	var path := "res://assets/sprites/equipment/%s/%s.png" % [slot, item_id]
	if not ResourceLoader.exists(path):
		push_warning("[PaperDoll] missing sprite: " + path)
		spr.texture = null
		return
	spr.texture = load(path)
	_apply_region()

func unequip(slot: String) -> void:
	equip(slot, "")

func get_gear() -> Dictionary:
	return _gear.duplicate()

# ------------------------------------------------------------ animation -----
## dir_name: "down" | "up" | "left" | "right"
## state:    "idle" | "walk" | "attack"
func play(dir_name: String, state: String, frame: int) -> void:
	var row: int = ArtIndex.DIRS.find(dir_name)
	if row < 0:
		row = 0
	var columns: Array = ArtIndex.FRAMES.get(state, ArtIndex.FRAMES["idle"])
	var col: int = columns[frame % columns.size()]
	if row == _row and col == _col:
		return
	_row = row
	_col = col
	_apply_region()

func _apply_region() -> void:
	var rect := Rect2(
		_col * ArtIndex.CELL.x,
		_row * ArtIndex.CELL.y,
		ArtIndex.CELL.x,
		ArtIndex.CELL.y
	)
	for slot_name in STACK:
		var spr: Sprite2D = _layers[slot_name]
		if spr.texture == null:
			continue
		spr.region_rect = rect
