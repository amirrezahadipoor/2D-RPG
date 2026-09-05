extends Node
## Dev tool: renders the procedural audio to user://preview/*.wav for listening.
func _ready() -> void:
	var dir := DirAccess.make_dir_recursive_absolute("user://preview")
	print("dir=", dir)
	for n in ["swing", "hit", "crit", "coin", "potion", "levelup", "death", "fireball", "craft", "buy"]:
		var wav: AudioStreamWAV = Sfx._sfx(n)
		wav.save_to_wav("user://preview/sfx_%s.wav" % n)
	for key in ["field", "forest", "village", "graveyard", "dungeon"]:
		var m: AudioStreamWAV = Sfx._music(key)
		m.save_to_wav("user://preview/music_%s.wav" % key)
	print("PREVIEW DONE")
	get_tree().quit()
