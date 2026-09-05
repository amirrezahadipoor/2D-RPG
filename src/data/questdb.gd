# The quest catalogue: 100 main-story stages (10 chapters x 10) and 300 side
# quests, all generated deterministically from seeds so every run shares one
# canon and tests can assert exact counts.
class_name QuestDB

const CHAPTERS := 10
const STAGES := 10
const SIDE_COUNT := 300

const MAIN_KINDS := ["talk", "kill", "collect", "clear", "kill",
	"collect", "clear", "kill", "clear", "boss"]
const SIDE_KINDS := ["kill", "collect", "clear", "deliver"]
const SIDE_BIOMES := ["forest", "desert", "snow", "swamp", "graveyard"]
const DELIVER_ROLES := ["merchant", "elder", "guard"]
const GIVER_ROLES := ["villager", "elder", "merchant", "guard"]

static func main_count() -> int:
	return CHAPTERS * STAGES

static func side_count() -> int:
	return SIDE_COUNT

# ------------------------------------------------------------ main story ----
static func main_quest(chapter: int, stage: int) -> Dictionary:
	var kind: String = MAIN_KINDS[stage]
	var q := {
		"id": "main_%d_%d" % [chapter, stage],
		"main": true,
		"chapter": chapter,
		"stage": stage,
		"kind": kind,
		"level_gate": 1 + chapter * 4 + stage / 2,
		"progress": 0,
	}
	var rng := RandomNumberGenerator.new()
	rng.seed = chapter * 131 + stage * 17
	match kind:
		"talk":
			q["role"] = DELIVER_ROLES[stage % 3]
			q["settlement"] = chapter % 4
			q["goal"] = 1
		"kill":
			q["biome"] = SIDE_BIOMES[(chapter + stage) % 5]
			q["enemy"] = _biome_enemy(q["biome"], rng)
			q["goal"] = 3 + chapter + stage / 2
		"collect":
			q["item"] = ItemGen.random_id(rng)
			q["goal"] = 1 + stage / 3
		"clear":
			q["biome"] = "graveyard"
			q["goal"] = 2 + chapter
		"boss":
			q["enemy"] = "dragon" if chapter >= 7 else ("demon" if chapter >= 4 else "orc")
			# bosses are dungeon creatures (orcs/demons spawn on the deep
			# floors, the dragon guards the last one); the caves biome is what
			# on_kill() checks, so killing a random forest orc cannot complete
			# a boss stage
			q["biome"] = "caves"
			q["goal"] = 1
	q["xp"] = 30 * (chapter + 1) * (2 + stage / 2)
	q["gold"] = 15 * (chapter + 1)
	return q

# -------------------------------------------------------------- side --------
static func side_quest(index: int) -> Dictionary:
	var tier := index / 60
	var kind: String = SIDE_KINDS[index % 4]
	var rng := RandomNumberGenerator.new()
	rng.seed = index * 2654435761
	var q := {
		"id": "side_%d" % index,
		"main": false,
		"tier": tier,
		"kind": kind,
		"giver_settlement": (index * 7) % 4,
		"giver_role": GIVER_ROLES[index % 4],
		"level_gate": 1 + tier * 5,
	}
	match kind:
		"kill":
			q["biome"] = SIDE_BIOMES[(index / 4) % 5]
			q["enemy"] = _biome_enemy(q["biome"], rng)
			q["goal"] = 2 + tier * 2 + index % 3
		"collect":
			q["item"] = ItemGen.random_id(rng)
			q["goal"] = 1 + tier
		"clear":
			q["biome"] = "graveyard"
			q["goal"] = 2 + tier * 2
		"deliver":
			q["settlement"] = (index / 4) % 4
			q["role"] = DELIVER_ROLES[index % 3]
			q["goal"] = 1
	q["xp"] = 18 * (tier + 1) * (2 + index % 3)
	q["gold"] = 8 * (tier + 1) * (1 + index % 2)
	return q

static func _biome_enemy(biome: String, rng: RandomNumberGenerator) -> String:
	var table: Array = EnemyDB.BIOME_SPAWNS.get(biome, EnemyDB.BIOME_SPAWNS["forest"])
	if table.is_empty():
		return "slime"
	return table[rng.randi_range(0, table.size() - 1)]

# -------------------------------------------------------------- texts -------
static func title_of(q: Dictionary) -> String:
	if q["main"]:
		# The story is ONE continuous arc of 100 objectives. Chapters/stages are
		# internal bookkeeping (10x10 grid) and are never surfaced to the player,
		# so the journal shows a plain "Main story N/100" step, not a stage.
		var index := int(q["chapter"]) * STAGES + int(q["stage"])
		return "%s %s/%s" % [I18N.tr_str("journal.main"),
			I18N.num(index + 1), I18N.num(main_count())]
	return "%s %s" % [I18N.tr_str("journal.side"), I18N.num(int(q.get("tier", 0)) + 1)]

static func desc_of(q: Dictionary) -> String:
	var key := ""
	var args := []
	if q["main"]:
		match q["kind"]:
			"talk":
				key = "quest.main.talk"
				args = [I18N.tr_str("npc.role." + q["role"]), I18N.tr_str("sett.name.%d" % q["settlement"])]
			"kill":
				key = "quest.main.kill"
				args = [I18N.num(q["goal"]), I18N.tr_str("enemy." + q["enemy"]), I18N.tr_str("biome." + q["biome"])]
			"collect":
				key = "quest.main.collect"
				args = [I18N.num(q["goal"]), I18N.tr_str("item." + q["item"])]
			"clear":
				key = "quest.main.clear"
				args = [I18N.num(q["goal"]), I18N.tr_str("biome.graveyard")]
			"boss":
				key = "quest.main.boss"
				args = [I18N.tr_str("enemy." + q["enemy"])]
	else:
		match q["kind"]:
			"kill":
				key = "quest.kill"
				args = [I18N.num(q["goal"]), I18N.tr_str("enemy." + q["enemy"]), I18N.tr_str("biome." + q["biome"])]
			"collect":
				key = "quest.collect"
				args = [I18N.num(q["goal"]), I18N.tr_str("item." + q["item"])]
			"clear":
				key = "quest.clear"
				args = [I18N.num(q["goal"])]
			"deliver":
				key = "quest.deliver"
				args = [I18N.tr_str("npc.role." + q["role"]), I18N.tr_str("sett.name.%d" % q["settlement"])]
	return I18N.tr_str(key) % args
