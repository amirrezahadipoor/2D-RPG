# Intro Scene Controller - Connects intro cutscene to game flow
# Phase 11 Polish - bridges intro with game systems

extends Control

var intro_cutscene: Control = null
var is_playing: bool = false

func _ready() -> void:
	visible = false

func play_intro() -> void:
	if is_playing:
		return
	
	is_playing = true
	visible = true
	
	# Create intro cutscene
	intro_cutscene = preload("res://src/polish/intro_cutscene.gd").new()
	intro_cutscene.name = "IntroCutscene"
	add_child(intro_cutscene)
	
	intro_cutscene.cutscene_finished.connect(_on_intro_finished)
	intro_cutscene.cutscene_skipped.connect(_on_intro_finished)
	
	intro_cutscene.play()

func _on_intro_finished() -> void:
	is_playing = false
	visible = false
	
	# Remove cutscene
	if intro_cutscene:
		intro_cutscene.queue_free()
		intro_cutscene = null
	
	# Start game
	if has_node("/root/GameManager"):
		get_node("/root/GameManager").on_intro_finished()
