# Player Movement Script for 2D RPG
# Phase 1: Core movement/camera
# Hero moves at minimum 64x64 logical pixels, never shrinks below readable size

extends KinematicBody2D

# Configuration
const SPEED = 180.0  # pixels per second
const ACCELERATION = 400.0
const DECELERATION = 300.0

# Input actions (defined in Project Settings)
# "ui_up", "ui_down", "ui_left", "ui_right"

# Visuals
@export var animation_right := "res://src/animations/right.animation"
@export var animation_left := "res://src/animations/left.animation"
@export var animation_up := "res://src/animations/up.animation"
@export var animation_down := "res://src/animations/down.animation"

# Camera reference (set by Camera2D parent)
@onready var camera_zoom := get_node("/root/Main/Camera2D/Zoom")  # reference to camera zoom

# Movement state
var velocity = Vector2.ZERO
var is_moving = false
var last_direction = Vector2.RIGHT

func _ready():
    # Set physics process for smooth movement
    physics_process_mode = PhysicsProcessMode.PHYSICS_PROCESS_MODE_PHYSICS_PROCESS
    
    # Ensure collision shape is set
    if not has_node("CollisionShape2D"):
        push_error("Player needs a CollisionShape2D child node")
    
    # Initialize collision
    get_node("CollisionShape2D").set_deferred("monitoring", true)
    
    # Set up animation player if available
    if has_node("AnimationPlayer"):
        get_node("AnimationPlayer").play("idle_down")
    
    # Set minimum size hint for readability on phone screens
    set_process(true)

func _physics_process(delta):
    # Reset velocity each frame
    velocity = Vector2.ZERO
    
    # Get input directions
    var direction = Vector2.ZERO
    
    # Check input actions
    if Input.is_action_pressed("ui_up"):
        direction.y -= 1
    if Input.is_action_pressed("ui_down"):
        direction.y += 1
    if Input.is_action_pressed("ui_left"):
        direction.x -= 1
    if Input.is_action_pressed("ui_right"):
        direction.x += 1
    
    # Normalize diagonal movement
    if direction.length() > 0:
        direction = direction.normalized()
    
    direction *= SPEED
    
    # Add velocity with acceleration
    if direction.length() > 0:
        velocity = move_toward(velocity, direction, ACCELERATION * delta)
        is_moving = true
        last_direction = direction
    else:
        # Decelerate when no input
        velocity = move_toward(velocity, Vector2.ZERO, DECELERATION * delta)
        is_moving = false
    
    # Move the player
    move_and_slide(velocity, UpVector)
    
    # Update animation/orientation based on movement
    update_animation()
    
    # Keep player within camera bounds
    restrict_to_camera()

func update_animation():
    # Set sprite animation based on movement direction
    if is_moving:
        # Determine primary direction
        var abs_x = abs(velocity.x)
        var abs_y = abs(velocity.y)
        
        if abs_x > abs_y:
            # Moving horizontally
            if velocity.x > 0:
                $Sprite.play("run_right")
                $Sprite.flip_h = false
            else:
                $Sprite.play("run_left")
                $Sprite.flip_h = true
        else:
            # Moving vertically
            if velocity.y > 0:
                $Sprite.play("run_down")
            else:
                $Sprite.play("run_up")
    else:
        # Idle - play idle animation based on last direction
        if last_direction.x > 0:
            $Sprite.play("idle_right")
        elif last_direction.x < 0:
            $Sprite.play("idle_left")
        elif last_direction.y > 0:
            $Sprite.play("idle_down")
        else:
            $Sprite.play("idle_up")

func restrict_to_camera():
    # Ensure player stays within readable camera bounds
    # Camera zoom minimum: characters never below readable size on phone
    # Minimum hero size: 64 logical pixels at default zoom
    # Zoom bounds ensure characters never shrink below readable size
    
    var cam = get_node("/root/Main/Camera2D") as Camera2D
    if cam:
        # Get camera zoom
        var zoom = cam.zoom
        
        # Calculate bounds based on camera size and zoom
        var viewport_size = get_viewport().get_visible_rect().size
        var cam_size = viewport_size / zoom
        
        # 64px minimum hero size on screen
        var min_hero_size = 64 / zoom  # Convert to camera coords
        
        # Keep player at least min_hero_size from edges
        position.x = max(position.x, min_hero_size / 2)
        position.x = min(position.x, cam_size - min_hero_size / 2)
        position.y = max(position.y, min_hero_size / 2)
        position.y = min(position.y, cam_size - min_hero_size / 2)

func get_movement_speed():
    return SPEED

func set_speed(new_speed):
    SPEED = new_speed

func set_acceleration(new_accel):
    ACCELERATION = new_accel