extends Node
class_name GameManager

@export var switch_1: CollisionObject3D
@export var switch_2: CollisionObject3D
@export var switch_3: CollisionObject3D

@export var indicator_1: MeshInstance3D
@export var indicator_2: MeshInstance3D
@export var indicator_3: MeshInstance3D

@export var access_panel: CollisionObject3D
@export var panel_indicator: MeshInstance3D

@export var exit_door_pivot: Node3D

@export var piece_1: CollisionObject3D
@export var piece_2: CollisionObject3D
@export var piece_3: CollisionObject3D

# Correct sequence is: Switch1 (0) -> Switch3 (2) -> Switch2 (1)
var correct_sequence := [0, 2, 1]
var current_sequence := []
var switch_states := [false, false, false]

# Discrete angles tracked logically and visual angles tracked cumulatively
# to prevent floating-point desynchronization and 360° reverse tween spin
var piece_visual_angles: Array[float] = [0.0, 180.0, 60.0]
var piece_tweens := [null, null, null]

var red_material: StandardMaterial3D
var green_material: StandardMaterial3D

var is_unlocked := false
var is_door_open := false
var is_triangle_puzzle_revealed := false
var is_resetting := false

func log_debug(message: String) -> void:
	var path := "res://gamemanager_debug.log"
	var file = FileAccess.open(path, FileAccess.READ_WRITE)
	if not file:
		file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(str(Time.get_time_string_from_system()) + " [GameManager]: " + message)
		file.close()

func _ready() -> void:
	log_debug("Ready started")
	
	# Dynamically resolve nodes if exports are null
	if not switch_1: switch_1 = get_node_or_null("../ControlConsole/Switch1")
	if not switch_2: switch_2 = get_node_or_null("../ControlConsole/Switch2")
	if not switch_3: switch_3 = get_node_or_null("../ControlConsole/Switch3")
	
	if not indicator_1: indicator_1 = get_node_or_null("../ControlConsole/Indicator1")
	if not indicator_2: indicator_2 = get_node_or_null("../ControlConsole/Indicator2")
	if not indicator_3: indicator_3 = get_node_or_null("../ControlConsole/Indicator3")
	
	if not access_panel: access_panel = get_node_or_null("../AccessPanel")
	if not panel_indicator: panel_indicator = get_node_or_null("../AccessPanel/PanelIndicator")
	if not exit_door_pivot: exit_door_pivot = get_node_or_null("../ExitDoorPivot")
	
	if not piece_1: piece_1 = get_node_or_null("../PuzzleTable/Piece1")
	if not piece_2: piece_2 = get_node_or_null("../PuzzleTable/Piece2")
	if not piece_3: piece_3 = get_node_or_null("../PuzzleTable/Piece3")
	
	log_debug("Resolved nodes:")
	log_debug("switch_1: " + str(switch_1))
	log_debug("switch_2: " + str(switch_2))
	log_debug("switch_3: " + str(switch_3))
	log_debug("indicator_1: " + str(indicator_1))
	log_debug("indicator_2: " + str(indicator_2))
	log_debug("indicator_3: " + str(indicator_3))
	log_debug("access_panel: " + str(access_panel))
	log_debug("panel_indicator: " + str(panel_indicator))
	log_debug("exit_door_pivot: " + str(exit_door_pivot))
	log_debug("piece_1: " + str(piece_1))
	log_debug("piece_2: " + str(piece_2))
	log_debug("piece_3: " + str(piece_3))
	
	# Create materials
	red_material = StandardMaterial3D.new()
	red_material.albedo_color = Color(1.0, 0.1, 0.1)
	red_material.emission_enabled = true
	red_material.emission = Color(1.0, 0.1, 0.1)
	red_material.emission_energy_multiplier = 3.0

	green_material = StandardMaterial3D.new()
	green_material.albedo_color = Color(0.1, 1.0, 0.1)
	green_material.emission_enabled = true
	green_material.emission = Color(0.1, 1.0, 0.1)
	green_material.emission_energy_multiplier = 3.0

	# Set initial indicator states
	reset_indicators()
	
	# Set access panel initial state
	if access_panel:
		access_panel.set("is_interactive", false)
		access_panel.set("prompt_message", "Locked")
	if panel_indicator:
		panel_indicator.set_surface_override_material(0, red_material)

	# Scramble and hide triangle pieces with collision disabled
	if piece_1:
		piece_1.rotation_degrees.y = piece_visual_angles[0]
		piece_1.set("visible", false)
		piece_1.set("is_interactive", false)
		_set_piece_collision(piece_1, false)
	if piece_2:
		piece_2.rotation_degrees.y = piece_visual_angles[1]
		piece_2.set("visible", false)
		piece_2.set("is_interactive", false)
		_set_piece_collision(piece_2, false)
	if piece_3:
		piece_3.rotation_degrees.y = piece_visual_angles[2]
		piece_3.set("visible", false)
		piece_3.set("is_interactive", false)
		_set_piece_collision(piece_3, false)

	# Connect signals dynamically
	if switch_1:
		var err = switch_1.connect("interacted", _on_switch_interacted.bind(0))
		log_debug("Connected switch_1: " + str(err))
	if switch_2:
		var err = switch_2.connect("interacted", _on_switch_interacted.bind(1))
		log_debug("Connected switch_2: " + str(err))
	if switch_3:
		var err = switch_3.connect("interacted", _on_switch_interacted.bind(2))
		log_debug("Connected switch_3: " + str(err))
	
	if access_panel:
		var err = access_panel.connect("interacted", _on_access_panel_interacted)
		log_debug("Connected access_panel: " + str(err))

	if piece_1:
		var err = piece_1.connect("interacted", _on_piece_interacted.bind(0))
		log_debug("Connected piece_1: " + str(err))
	if piece_2:
		var err = piece_2.connect("interacted", _on_piece_interacted.bind(1))
		log_debug("Connected piece_2: " + str(err))
	if piece_3:
		var err = piece_3.connect("interacted", _on_piece_interacted.bind(2))
		log_debug("Connected piece_3: " + str(err))

func reset_indicators() -> void:
	if indicator_1: indicator_1.set_surface_override_material(0, red_material)
	if indicator_2: indicator_2.set_surface_override_material(0, red_material)
	if indicator_3: indicator_3.set_surface_override_material(0, red_material)

func _on_switch_interacted(player: Node, switch_index: int) -> void:
	log_debug("Switch interacted: " + str(switch_index))
	if is_triangle_puzzle_revealed or is_unlocked or is_resetting:
		return

	# Toggle switch state
	switch_states[switch_index] = !switch_states[switch_index]
	
	# Rotate switch to reflect state
	var target_rotation := 25.0 if switch_states[switch_index] else -25.0
	var switch_node = null
	if switch_index == 0: switch_node = switch_1
	elif switch_index == 1: switch_node = switch_2
	elif switch_index == 2: switch_node = switch_3
	
	if switch_node:
		var tween := create_tween()
		tween.tween_property(switch_node, "rotation_degrees:x", target_rotation, 0.2).set_trans(Tween.TRANS_SINE)

	# Add to current sequence
	current_sequence.append(switch_index)
	
	# Check if the sequence entered so far is correct
	var step_count := current_sequence.size()
	var is_correct_so_far := true
	for i in range(step_count):
		if current_sequence[i] != correct_sequence[i]:
			is_correct_so_far = false
			break
			
	if is_correct_so_far:
		log_debug("Sequence correct so far: " + str(current_sequence))
		# Update corresponding indicator
		if switch_index == 0 and indicator_1:
			indicator_1.set_surface_override_material(0, green_material)
		elif switch_index == 2 and indicator_3:
			indicator_3.set_surface_override_material(0, green_material)
		elif switch_index == 1 and indicator_2:
			indicator_2.set_surface_override_material(0, green_material)
			
		if step_count == correct_sequence.size():
			log_debug("Book sequence fully solved! Revealing triangle puzzle...")
			reveal_triangle_puzzle()
	else:
		log_debug("Sequence incorrect, resetting: " + str(current_sequence))
		reset_puzzle()

func reset_puzzle() -> void:
	is_resetting = true
	current_sequence.clear()
	
	# Flash red indicators
	for i in range(3):
		if indicator_1: indicator_1.set_surface_override_material(0, red_material)
		if indicator_2: indicator_2.set_surface_override_material(0, red_material)
		if indicator_3: indicator_3.set_surface_override_material(0, red_material)
		await get_tree().create_timer(0.15).timeout
		if indicator_1: indicator_1.set_surface_override_material(0, null)
		if indicator_2: indicator_2.set_surface_override_material(0, null)
		if indicator_3: indicator_3.set_surface_override_material(0, null)
		await get_tree().create_timer(0.15).timeout
		
	reset_indicators()
	
	# Reset switch rotations
	switch_states = [false, false, false]
	for switch_node in [switch_1, switch_2, switch_3]:
		if switch_node:
			var tween := create_tween()
			tween.tween_property(switch_node, "rotation_degrees:x", -25.0, 0.3).set_trans(Tween.TRANS_SINE)
			
	is_resetting = false

func _set_piece_collision(piece_node: Node, enabled: bool) -> void:
	if not piece_node: return
	for child in piece_node.get_children():
		if child is CollisionShape3D:
			child.disabled = !enabled

func reveal_triangle_puzzle() -> void:
	is_triangle_puzzle_revealed = true
	log_debug("Revealing triangle puzzle pieces on the table")
	for piece in [piece_1, piece_2, piece_3]:
		if piece:
			piece.set("visible", true)
			piece.set("is_interactive", true)
			piece.set("prompt_message", "Rotate Piece")
			_set_piece_collision(piece, true)

func _on_piece_interacted(player: Node, piece_index: int) -> void:
	log_debug("Piece interacted: " + str(piece_index))
	if is_unlocked:
		return
		
	var piece = null
	if piece_index == 0: piece = piece_1
	elif piece_index == 1: piece = piece_2
	elif piece_index == 2: piece = piece_3
	
	if not piece:
		return
		
	# Advance cumulative visual angle by exact 60 degrees to prevent reverse spin
	piece_visual_angles[piece_index] += 60.0
	var target_rotation: float = piece_visual_angles[piece_index]
	
	log_debug("Rotating piece " + str(piece_index) + " to visual angle: " + str(target_rotation))
	
	# Safely manage per-piece tween
	if piece_tweens[piece_index] and piece_tweens[piece_index].is_valid():
		piece_tweens[piece_index].kill()
		
	var tween := create_tween()
	piece_tweens[piece_index] = tween
	tween.tween_property(piece, "rotation_degrees:y", target_rotation, 0.22).set_trans(Tween.TRANS_SINE)
	await tween.finished
	
	check_triangle_puzzle()

func check_triangle_puzzle() -> void:
	if not piece_1 or not piece_2 or not piece_3:
		return
		
	var angle1 := int(round(fposmod(piece_visual_angles[0], 360.0)))
	var angle2 := int(round(fposmod(piece_visual_angles[1], 360.0)))
	var angle3 := int(round(fposmod(piece_visual_angles[2], 360.0)))
	
	log_debug("Checking triangle puzzle angles: Piece1=" + str(angle1) + ", Piece2=" + str(angle2) + ", Piece3=" + str(angle3))
	
	# Piece 1 is horizontal base: requires 0° or 180°
	# Piece 2 is left diagonal side: requires 60° or 240°
	# Piece 3 is right diagonal side: requires 120° or 300°
	var is_p1_valid := (angle1 % 180 == 0)
	var is_p2_valid := (angle2 % 180 == 60)
	var is_p3_valid := (angle3 % 180 == 120)
	
	log_debug("Validity: P1=" + str(is_p1_valid) + ", P2=" + str(is_p2_valid) + ", P3=" + str(is_p3_valid))
	
	if is_p1_valid and is_p2_valid and is_p3_valid:
		log_debug("Triangle puzzle solved successfully forming closed equilateral triangle!")
		unlock_escape_door()

func unlock_escape_door() -> void:
	is_unlocked = true
	if panel_indicator:
		panel_indicator.set_surface_override_material(0, green_material)
	if access_panel:
		access_panel.set("is_interactive", true)
		access_panel.set("prompt_message", "Turn Secret Crest")

func _on_access_panel_interacted(player: Node) -> void:
	log_debug("Access panel interacted")
	if is_unlocked and not is_door_open:
		is_door_open = true
		if access_panel:
			access_panel.set("is_interactive", false)
			access_panel.set("prompt_message", "Door Opening...")
		
		# Open the door panel smoothly (rotate the pivot 90 degrees around Y axis)
		if exit_door_pivot:
			var tween := create_tween()
			tween.tween_property(exit_door_pivot, "rotation_degrees:y", 90.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			await tween.finished
			if access_panel:
				access_panel.set("prompt_message", "Escaped")
