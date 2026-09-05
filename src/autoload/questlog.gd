# Quest state machine: what is active, what progressed, what can be turned in
# where. Hooks come from the spawner (kills), pickups (collects) and dialogue
# (talk/deliver).
extends Node

signal changed
signal toast(key: String)

var active: Array = []                 # side quest instances with progress
var completed_side: Dictionary = {}    # id -> true
var declined: Dictionary = {}          # id -> level declined at (re-offered after a level-up)
var main_progress: int = 0             # completed main stages, 0..100

# The ONE live instance of the current main stage. QuestDB.main_quest() builds
# a fresh dict per call, so progress written to it used to vanish instantly:
# the whole campaign was uncompletable. This cache is what hooks mutate and
# what gets serialized; it is rebuilt whenever main_progress advances.
var main_active: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func serialize() -> Dictionary:
	return {"active": active.duplicate(true),
		"completed_side": completed_side.duplicate(true),
		"declined": declined.duplicate(true),
		"main_progress": main_progress,
		"main_active": main_active.duplicate(true)}

func deserialize(data: Dictionary) -> void:
	active = (data.get("active", []) as Array).duplicate(true)
	completed_side = (data.get("completed_side", {}) as Dictionary).duplicate(true)
	declined = (data.get("declined", {}) as Dictionary).duplicate(true)
	main_progress = int(data.get("main_progress", 0))
	main_active = (data.get("main_active", {}) as Dictionary).duplicate(true)
	# never trust a cached stage from a different save/version
	if not main_active.is_empty() and int(main_active.get("_index", -1)) != main_progress:
		main_active.clear()
	changed.emit()

func reset_run() -> void:
	active.clear()
	completed_side.clear()
	declined.clear()
	main_progress = 0
	main_active.clear()
	changed.emit()

# ------------------------------------------------------------------ main ----
## The live current main stage, rebuilt lazily. Callers may mutate it; those
## writes are the durable progress record (unlike QuestDB.main_quest()).
func current_main() -> Dictionary:
	if main_progress >= QuestDB.main_count():
		if not main_active.is_empty():
			main_active.clear()
		return {}
	if not main_active.is_empty() and int(main_active.get("_index", -1)) == main_progress:
		return main_active
	main_active = QuestDB.main_quest(main_progress / QuestDB.STAGES, main_progress % QuestDB.STAGES)
	main_active["_index"] = main_progress
	if not main_active.has("progress"):
		main_active["progress"] = 0
	return main_active

func main_gate_ok() -> bool:
	var q := current_main()
	return not q.is_empty() and Stats.level >= int(q["level_gate"])

## Which story act (0..9) the run is in. Acts are flavour arcs layered on top
## of the internal 10x10 grid; the grid itself is never shown to the player.
func current_act() -> int:
	return clampi(main_progress / QuestDB.STAGES, 0, QuestDB.STAGES - 1)

# ------------------------------------------------------------------ side ----
## Index of the next side quest this NPC can offer, or -1.
func offer_at(npc_settlement: int, npc_role: String) -> int:
	for i in QuestDB.side_count():
		var q := QuestDB.side_quest(i)
		if int(q["giver_settlement"]) != npc_settlement or q["giver_role"] != npc_role:
			continue
		if completed_side.has(q["id"]):
			continue
		# declined quests come back once the hero has levelled up since
		if declined.has(q["id"]) and Stats.level <= int(declined[q["id"]]):
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
	declined[QuestDB.side_quest(index)["id"]] = Stats.level
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
		elif m["kind"] == "boss" and biome == "caves" and m.get("enemy", "") == enemy_type:
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
	if m.is_empty() or not main_gate_ok():
		return null
	if int(m.get("progress", 0)) < int(m["goal"]):
		return null
	# kill/collect/clear/boss stages are reported to the elder of a settlement.
	# "talk" stages are turned in to the very NPC the stage names (same role
	# and settlement), so merchant/guard talk stages are completable too.
	if m["kind"] == "talk":
		if npc_role == "elder" \
				or (npc_role == m.get("role", "") and int(m.get("settlement", -1)) == npc_settlement):
			return m
		return null
	return m if npc_role == "elder" else null

func complete(quest: Dictionary) -> void:
	# The quest passed in is usually a LIVE cache entry (current_main() or an
	# active instance), and clearing main_active below would empty it in place.
	# Snapshot every field we still need BEFORE mutating any bookkeeping.
	var is_main: bool = quest["main"]
	var q_id: String = quest.get("id", "")
	var q_stage: int = int(quest.get("stage", -1))
	var q_giver: String = quest.get("giver_role", "")
	Stats.add_xp(int(quest["xp"]))
	Stats.add_gold(int(quest["gold"]))
	if is_main:
		main_progress += 1
		main_active.clear()   # next current_main() rebuilds the following stage
		if q_stage == QuestDB.STAGES - 1:
			Stats.talent_points += 1
			Stats.talent_changed.emit(Stats.talent_points)
		# the hundredth completed stage is the end of the story
		if main_progress >= QuestDB.main_count():
			Game.change_state(Game.State.VICTORY)
	else:
		completed_side[q_id] = true
		for i in active.size():
			if active[i]["id"] == q_id:
				active.remove_at(i)
				break
		# villagers thank you with a brew - deterministic, no gold-parity lottery
		if q_giver == "villager":
			Inventory.add({"id": "health_potion", "slot": "", "rarity": 0,
				"prefix": "", "suffix": "", "dmg": 0, "armor": 0, "weight": 1, "qty": 1})
	toast.emit("quest.done")
	changed.emit()

func completed_main_count() -> int:
	return main_progress

func completed_side_count() -> int:
	return completed_side.size()
