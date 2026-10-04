extends CharacterBody3D

@export var speed := 4.0
@export var gravity := 9.8
@export var mouse_sensitivity := 0.15

var camera_pitch := 0.0
var raycast: RayCast3D
var prompt_label: Label
var victory_screen: Control
var debug_label: Label
var crosshair_label: Label
var hand_pivot: Node3D

func log_debug(message: String) -> void:
	var path := "res://player_debug.log"
	var file = FileAccess.open(path, FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(str(Time.get_time_string_from_system()) + " [Player]: " + message)
		file.close()

func _ready() -> void:
	log_debug("Ready started")
	# Capture mouse
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Create RayCast3D for interaction with extended comfortable reach (3.0m)
	raycast = RayCast3D.new()
	raycast.enabled = true
	raycast.target_position = Vector3(0, 0, -3.0)
	raycast.collision_mask = 1 # Default physics layer
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true
	
	var camera = get_node_or_null("Camera3D")
	if camera:
		camera.add_child(raycast)
		
	hand_pivot = get_node_or_null("Camera3D/HandPivot")
		
	# Find UI elements dynamically
	prompt_label = get_node_or_null("../UI/InteractionPrompt")
	victory_screen = get_node_or_null("../UI/VictoryScreen")
	debug_label = get_node_or_null("../UI/DebugLabel")
	crosshair_label = get_node_or_null("../UI/Crosshair")
	
	if victory_screen:
		victory_screen.visible = false

func _input(event: InputEvent) -> void:
	# Robust, crash-proof FPS mouse look without Euler gimbal lock / flip
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, -80.0, 80.0)
		
		var camera = get_node_or_null("Camera3D")
		if camera:
			camera.rotation = Vector3(deg_to_rad(camera_pitch), 0.0, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	# Click inside the window to capture the mouse again
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			log_debug("Capturing mouse cursor")
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return
			
	# Press ESC to release/capture mouse cursor
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			log_debug("Releasing mouse cursor")
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			log_debug("Capturing mouse cursor")
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	# Interact with E (handling layout-independent physical keycode for Greek layouts) or Left Mouse Click
	var is_interact_key = false
	if event is InputEventKey and event.pressed:
		is_interact_key = (event.keycode == KEY_E or event.physical_keycode == KEY_E)
		if is_interact_key:
			log_debug("E key pressed (keycode: " + str(event.keycode) + ", physical: " + str(event.physical_keycode) + ")")
			
	var is_mouse_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if is_mouse_click:
		log_debug("Left mouse click interaction")
	
	if is_interact_key or is_mouse_click:
		_trigger_interaction()

func _trigger_interaction() -> void:
	# Play first-person hand reach animation
	if hand_pivot:
		var tween := create_tween()
		tween.tween_property(hand_pivot, "position:z", -0.7, 0.1).set_trans(Tween.TRANS_SINE)
		tween.tween_property(hand_pivot, "position:x", 0.12, 0.1).set_trans(Tween.TRANS_SINE)
		tween.tween_property(hand_pivot, "position:z", -0.45, 0.15).set_trans(Tween.TRANS_SINE).set_delay(0.08)
		tween.tween_property(hand_pivot, "position:x", 0.2, 0.15).set_trans(Tween.TRANS_SINE).set_delay(0.08)

	var target = _get_interactable_target()
	if target and target.has_method("interact"):
		log_debug("Calling interact() on " + target.name)
		target.interact(self)
	else:
		log_debug("No valid interactable targeted on press")

func _get_interactable_target() -> Node:
	if not raycast or not raycast.is_colliding():
		return null
		
	var collider = raycast.get_collider()
	if not collider:
		return null
		
	if collider.has_method("interact") and collider.get("is_interactive") != false:
		return collider
		
	# Check parent if collider is a child mesh or sub-shape
	var parent = collider.get_parent()
	if parent and parent.has_method("interact") and parent.get("is_interactive") != false:
		return parent
		
	return null

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Foolproof input detection for WASD and Arrow Keys
	var input_direction := Vector2.ZERO
	
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_direction.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_direction.x += 1.0
		
	# Normalize to prevent diagonal speed boost
	if input_direction.length() > 0:
		input_direction = input_direction.normalized()

	# Calculate movement direction relative to player rotation
	var direction := Vector3(input_direction.x, 0, input_direction.y)
	direction = direction.rotated(Vector3.UP, rotation.y).normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()
	
	# Update Interaction UI and Crosshair
	var target = _get_interactable_target()
	if target:
		var prompt_text = str(target.get("prompt_message"))
		if prompt_text.is_empty():
			prompt_text = "Interact"
			
		if prompt_label:
			prompt_label.text = "[E] " + prompt_text
			prompt_label.visible = true
			
		if crosshair_label:
			crosshair_label.text = "✋"
			crosshair_label.modulate = Color(1.0, 0.85, 0.2, 1.0) # Bright golden focus color
			crosshair_label.set("theme_override_font_sizes/font_size", 26)
			
		if debug_label:
			debug_label.text = "Target: " + target.name + " | Action: " + prompt_text
	else:
		if prompt_label:
			prompt_label.visible = false
			
		if crosshair_label:
			crosshair_label.text = "+"
			crosshair_label.modulate = Color(1.0, 1.0, 1.0, 0.85) # Neutral white
			crosshair_label.set("theme_override_font_sizes/font_size", 20)
			
		if debug_label:
			if raycast and raycast.is_colliding():
				var col = raycast.get_collider()
				debug_label.text = "Looking at: " + (col.name if col else "Unknown")
			else:
				debug_label.text = "Looking at: Nothing"

func escape(body: Node3D = null) -> void:
	log_debug("Escaped!")
	# Release mouse and show victory screen
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if victory_screen:
		victory_screen.visible = true
	
	# Wait 3 seconds and terminate/quit the game cleanly
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
