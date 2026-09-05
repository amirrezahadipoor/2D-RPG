# Quest state machine: what is active, what progressed, what can be turned in
# where. Hooks come from the spawner (kills), pickups (collects) and dialogue
# (talk/deliver).
extends Node

signal changed
signal toast(key: String)

var active: Array = []                 # side quest instances with progress
var completed_side: Dictionary = {}    # id -> true
var declined: Dictionary = {}          # id -> true (re-offerable later)
var main_progress: int = 0             # completed main stages, 0..100

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func serialize() -> Dictionary:
	return {"active": active.duplicate(true),
		"completed_side": completed_side.duplicate(true),
		"declined": declined.duplicate(true),
		"main_progress": main_progress}

func deserialize(data: Dictionary) -> void:
	active = (data.get("active", []) as Array).duplicate(true)
	completed_side = (data.get("completed_side", {}) as Dictionary).duplicate(true)
	declined = (data.get("declined", {}) as Dictionary).duplicate(true)
	main_progress = int(data.get("main_progress", 0))
	changed.emit()

func reset_run() -> void:
	active.clear()
	completed_side.clear()
	declined.clear()
	main_progress = 0
	changed.emit()

# ------------------------------------------------------------------ main ----
func current_main() -> Dictionary:
	if main_progress >= QuestDB.main_count():
		return {}
	return QuestDB.main_quest(main_progress / QuestDB.STAGES, main_progress % QuestDB.STAGES)

func main_gate_ok() -> bool:
	var q := current_main()
	return not q.is_empty() and Stats.level >= int(q["level_gate"])

# ------------------------------------------------------------------ side ----
## Index of the next side quest this NPC can offer, or -1.
func offer_at(npc_settlement: int, npc_role: String) -> int:
	for i in QuestDB.side_count():
		var q := QuestDB.side_quest(i)
		if int(q["giver_settlement"]) != npc_settlement or q["giver_role"] != npc_role:
			continue
		if completed_side.has(q["id"]) or declined.has(q["id"]):
			continue
		if _is_active(q["id"]):
			continue
		if Stats.level < int(q["level_gate"]):
			continue
		return i
	return -1

func start_side(index: int) -> void:
	var q := QuestDB.side_quest(index)
	q["progress"] = 0
	active.append(q)
	declined.erase(q["id"])
	changed.emit()

func decline_side(index: int) -> void:
	declined[QuestDB.side_quest(index)["id"]] = true
	changed.emit()

func _is_active(qid: String) -> bool:
	for q in active:
		if q["id"] == qid:
			return true
	return false

# ----------------------------------------------------------------- hooks ----
func on_kill(enemy_type: String, biome: String) -> void:
	var dirty := false
	for q in active:
		if q["kind"] == "kill" and q["enemy"] == enemy_type and q["biome"] == biome:
			q["progress"] = mini(int(q["progress"]) + 1, int(q["goal"]))
			dirty = true
		elif q["kind"] == "clear" and biome == "graveyard":
			q["progress"] = mini(int(q["progress"]) + 1, int(q["goal"]))
			dirty = true
	var m := current_main()
	if not m.is_empty() and main_gate_ok():
		if m["kind"] == "kill" and m.get("enemy", "") == enemy_type and m.get("biome", "") == biome:
			m["progress"] = mini(int(m.get("progress", 0)) + 1, int(m["goal"]))
			dirty = true
		elif m["kind"] == "clear" and biome == "graveyard":
			m["progress"] = mini(int(m.get("progress", 0)) + 1, int(m["goal"]))
			dirty = true
		elif m["kind"] == "boss" and m.get("enemy", "") == enemy_type:
			m["progress"] = mini(int(m.get("progress", 0)) + 1, int(m["goal"]))
			dirty = true
	if dirty:
		changed.emit()

func on_collect(item_id: String) -> void:
	var dirty := false
	for q in active:
		if q["kind"] == "collect" and q["item"] == item_id:
			q["progress"] = mini(int(q["progress"]) + 1, int(q["goal"]))
			dirty = true
	var m := current_main()
	if not m.is_empty() and m["kind"] == "collect" and m.get("item", "") == item_id and main_gate_ok():
		m["progress"] = mini(int(m.get("progress", 0)) + 1, int(m["goal"]))
		dirty = true
	if dirty:
		changed.emit()

## Talking to someone: delivery targets and main-story "talk" stages.
func on_talk(npc_settlement: int, npc_role: String) -> void:
	var dirty := false
	for q in active:
		if q["kind"] == "deliver" and int(q["settlement"]) == npc_settlement and q["role"] == npc_role:
			q["progress"] = int(q["goal"])
			dirty = true
	var m := current_main()
	if not m.is_empty() and m["kind"] == "talk" and main_gate_ok():
		if int(m["settlement"]) == npc_settlement and m["role"] == npc_role:
			m["progress"] = int(m["goal"])
			dirty = true
	if dirty:
		changed.emit()

# --------------------------------------------------------------- turn-in ----
## The quest instance this NPC can finish right now, or null.
func turn_in_at(npc_settlement: int, npc_role: String):
	for q in active:
		if int(q["progress"]) >= int(q["goal"]):
			if int(q["giver_settlement"]) == npc_settlement and q["giver_role"] == npc_role:
				return q
	var m := current_main()
	if not m.is_empty() and npc_role == "elder" and main_gate_ok():
		if int(m.get("progress", 0)) >= int(m["goal"]):
			return m
	return null

func complete(quest: Dictionary) -> void:
	Stats.add_xp(int(quest["xp"]))
	Stats.add_gold(int(quest["gold"]))
	if quest["main"]:
		main_progress += 1
		if int(quest["stage"]) == QuestDB.STAGES - 1:
			Stats.talent_points += 1
			Stats.talent_changed.emit(Stats.talent_points)
	else:
		completed_side[quest["id"]] = true
		for i in active.size():
			if active[i]["id"] == quest["id"]:
				active.remove_at(i)
				break
		# side rewards sometimes include a potion
		if int(quest["gold"]) % 2 == 0:
			Inventory.add({"id": "health_potion", "slot": "", "rarity": 0,
				"prefix": "", "suffix": "", "dmg": 0, "armor": 0, "weight": 1, "qty": 1})
	toast.emit("quest.done")
	changed.emit()

func completed_main_count() -> int:
	return main_progress

func completed_side_count() -> int:
	return completed_side.size()
