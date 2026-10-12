## Ελεγκτής παίκτη πρώτου προσώπου (First-Person Controller).
## Διαχειρίζεται την κίνηση στον τρισδιάστατο χώρο, την κάμερα, το σύστημα σκόπευσης
## (RayCast3D) και την αλληλεπίδραση με τα στοιχεία του Escape Room.
class_name Player
extends CharacterBody3D

## Ταχύτητα μετακίνησης του παίκτη σε μέτρα ανά δευτερόλεπτο (m/s).
@export var speed: float = 4.0

## Επιτάχυνση της βαρύτητας που ασκείται στον παίκτη (m/s²).
@export var gravity: float = 9.8

## Ευαισθησία περιστροφής της κάμερας από την κίνηση του ποντικιού.
@export var mouse_sensitivity: float = 0.15

## Τρέχουσα κατακόρυφη γωνία κλίσης της κάμερας (pitch) σε μοίρες.
var camera_pitch: float = 0.0

## Ακτίνα εντοπισμού αλληλεπιδράσιμων αντικειμένων μπροστά από την κάμερα.
var raycast: RayCast3D

## Ετικέτα UI για την εμφάνιση προτροπών αλληλεπίδρασης (π.χ. "[E] Pull Book").
var prompt_label: Label

## Πίνακας τερματισμού/νίκης που εμφανίζεται όταν ο παίκτης διαφύγει επιτυχώς.
var victory_screen: Control

## Ετικέτα εντοπισμού σφαλμάτων (Debug UI) για εμφάνιση πληροφοριών στόχευσης.
var debug_label: Label

## Ετικέτα στοχάστρου (Crosshair) στο κέντρο της οθόνης (εναλλαγή '+' και '✋').
var crosshair_label: Label

## Κόμβος αναφοράς για το τρισδιάστατο μοντέλο χεριού πρώτου προσώπου.
var hand_pivot: Node3D

## Ενεργό animation ομαλής κίνησης (Tween) για το χέρι του παίκτη.
var hand_tween: Tween

## Σημαία που δηλώνει αν ο παίκτης έχει ήδη ολοκληρώσει την απόδραση.
var has_escaped: bool = false

## Αρχικοποίηση του παίκτη, των Input Actions, του RayCast και των στοιχείων διεπαφής (UI).
func _ready() -> void:
	if OS.is_debug_build():
		print("[Player] Αρχικοποίηση παίκτη...")

	_setup_input_actions()

	# Κλείδωμα και απόκρυψη του κέρσορα ποντικιού για έλεγχο πρώτου προσώπου
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Δημιουργία και παραμετροποίηση του RayCast3D με άνετη εμβέλεια 3.0 μέτρων
	raycast = RayCast3D.new()
	raycast.enabled = true
	raycast.target_position = Vector3(0.0, 0.0, -3.0)
	raycast.collision_mask = 1 # Βασικό επίπεδο φυσικής (Default Layer)
	raycast.collide_with_areas = true
	raycast.collide_with_bodies = true

	var camera := get_node_or_null("Camera3D")
	if camera:
		camera.add_child(raycast)

	hand_pivot = get_node_or_null("Camera3D/HandPivot")

	# Δυναμική ανίχνευση και σύνδεση των κόμβων διεπαφής χρήστη (UI)
	prompt_label = get_node_or_null("../UI/InteractionPrompt")
	victory_screen = get_node_or_null("../UI/VictoryScreen")
	debug_label = get_node_or_null("../UI/DebugLabel")
	crosshair_label = get_node_or_null("../UI/Crosshair")

	if victory_screen:
		victory_screen.visible = false

	# Το DebugLabel είναι ορατό μόνο σε δοκιμαστικές εκδόσεις (debug builds)
	if debug_label:
		debug_label.visible = OS.is_debug_build()

## Βοηθητική μέθοδος καταχώρισης πλήκτρου πληκτρολογίου σε Input Action.
func _add_key_action(action: StringName, keycode: Key) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)

## Βοηθητική μέθοδος καταχώρισης κουμπιού ποντικιού σε Input Action.
func _add_mouse_action(action: StringName, button: MouseButton) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)

## Δυναμική καταχώριση των Input Actions στο InputMap αν δεν έχουν ήδη οριστεί στο project.
func _setup_input_actions() -> void:
	if not InputMap.has_action(&"move_forward"):
		InputMap.add_action(&"move_forward")
		_add_key_action(&"move_forward", KEY_W)
		_add_key_action(&"move_forward", KEY_UP)

	if not InputMap.has_action(&"move_back"):
		InputMap.add_action(&"move_back")
		_add_key_action(&"move_back", KEY_S)
		_add_key_action(&"move_back", KEY_DOWN)

	if not InputMap.has_action(&"move_left"):
		InputMap.add_action(&"move_left")
		_add_key_action(&"move_left", KEY_A)
		_add_key_action(&"move_left", KEY_LEFT)

	if not InputMap.has_action(&"move_right"):
		InputMap.add_action(&"move_right")
		_add_key_action(&"move_right", KEY_D)
		_add_key_action(&"move_right", KEY_RIGHT)

	if not InputMap.has_action(&"interact"):
		InputMap.add_action(&"interact")
		_add_key_action(&"interact", KEY_E)
		_add_mouse_action(&"interact", MOUSE_BUTTON_LEFT)

## Επεξεργασία συμβάντων εισόδου για την ομαλή περιστροφή της κάμερας χωρίς gimbal lock.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Οριζόντια περιστροφή του σώματος του παίκτη (Yaw)
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))

		# Κατακόρυφη κλίση της κάμερας (Pitch) με περιορισμό στις [-80°, 80°]
		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(camera_pitch, -80.0, 80.0)

		var camera := get_node_or_null("Camera3D")
		if camera:
			camera.rotation = Vector3(deg_to_rad(camera_pitch), 0.0, 0.0)

## Διαχείριση μη επεξεργασμένων συμβάντων (κλικ επανάκτησης ποντικιού, ESC και αλληλεπίδραση).
func _unhandled_input(event: InputEvent) -> void:
	# Κλικ στο παράθυρο για επανάκτηση του ποντικιού αν είχε ελευθερωθεί
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
			return

	# Πάτημα ESC ή ui_cancel για απελευθέρωση/κλείδωμα του κέρσορα
	if event.is_action_pressed(&"ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return

	# Ενεργοποίηση αλληλεπίδρασης μέσω του action "interact" (πλήκτρο E ή αριστερό κλικ)
	if event.is_action_pressed(&"interact") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_trigger_interaction()
		get_viewport().set_input_as_handled()

## Εκτέλεση της κίνησης αλληλεπίδρασης (animation χεριού και κλήση interact() στον στόχο).
func _trigger_interaction() -> void:
	# Ομαλό procedural animation κίνησης του χεριού προς τα εμπρός
	if hand_pivot:
		if hand_tween and hand_tween.is_valid():
			hand_tween.kill()
		hand_tween = create_tween()
		hand_tween.tween_property(hand_pivot, "position:z", -0.7, 0.1).set_trans(Tween.TRANS_SINE)
		hand_tween.tween_property(hand_pivot, "position:x", 0.12, 0.1).set_trans(Tween.TRANS_SINE)
		hand_tween.tween_property(hand_pivot, "position:z", -0.45, 0.15).set_trans(Tween.TRANS_SINE).set_delay(0.08)
		hand_tween.tween_property(hand_pivot, "position:x", 0.2, 0.15).set_trans(Tween.TRANS_SINE).set_delay(0.08)

	var target := _get_interactable_target()
	if target and target.has_method("interact"):
		if OS.is_debug_build():
			print("[Player] Αλληλεπίδραση με: ", target.name)
		target.interact(self)

## Εντοπίζει αν το RayCast3D στοχεύει έγκυρο αλληλεπιδράσιμο αντικείμενο (ή τον γονέα του).
func _get_interactable_target() -> Node:
	if not raycast or not raycast.is_colliding():
		return null

	var collider: Object = raycast.get_collider()
	if not collider:
		return null

	if collider.has_method("interact") and collider.get("is_interactive") != false:
		return collider as Node

	# Έλεγχος γονικού κόμβου σε περίπτωση σύνθετων σχημάτων σύγκρουσης
	var parent: Node = (collider as Node).get_parent() if collider is Node else null
	if parent and parent.has_method("interact") and parent.get("is_interactive") != false:
		return parent

	return null

## Επεξεργασία φυσικής: βαρύτητα, κίνηση παίκτη και δυναμική ενημέρωση του UI/Crosshair.
func _physics_process(delta: float) -> void:
	# Εφαρμογή βαρύτητας όταν ο παίκτης βρίσκεται στον αέρα
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Υπολογισμός διανύσματος κίνησης μέσω Input.get_vector()
	var input_vector := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")

	# Προσανατολισμός της διεύθυνσης κίνησης ως προς την τρέχουσα γωνία του παίκτη
	var direction := Vector3(input_vector.x, 0.0, input_vector.y)
	direction = direction.rotated(Vector3.UP, rotation.y).normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()

	# Ενημέρωση στοιχείων διεπαφής (HUD prompt, crosshair ✋ / +)
	var target := _get_interactable_target()
	if target:
		var prompt_text: String = str(target.get("prompt_message"))
		if prompt_text.is_empty():
			prompt_text = "Interact"

		if prompt_label:
			prompt_label.text = "[E] " + prompt_text
			prompt_label.visible = true

		if crosshair_label:
			crosshair_label.text = "✋"
			crosshair_label.modulate = Color(1.0, 0.85, 0.2, 1.0) # Χρυσό χρώμα εστίασης
			crosshair_label.set("theme_override_font_sizes/font_size", 26)

		if debug_label and debug_label.visible:
			debug_label.text = "Στόχος: " + target.name + " | Ενέργεια: " + prompt_text
	else:
		if prompt_label:
			prompt_label.visible = false

		if crosshair_label:
			crosshair_label.text = "+"
			crosshair_label.modulate = Color(1.0, 1.0, 1.0, 0.85) # Ουδέτερο λευκό
			crosshair_label.set("theme_override_font_sizes/font_size", 20)

		if debug_label and debug_label.visible:
			if raycast and raycast.is_colliding():
				var col = raycast.get_collider()
				debug_label.text = "Βλέπει: " + (col.name if col else "Άγνωστο")
			else:
				debug_label.text = "Βλέπει: Τίποτα"

## Καλείται όταν ο παίκτης εισέλθει στην περιοχή εξόδου (EscapeArea).
## Ελέγχει αν η πόρτα είναι πραγματικά ανοιχτή πριν επικυρώσει την απόδραση.
func escape(_body: Node3D = null) -> void:
	var gm = get_node_or_null("../GameManager")
	if gm and not gm.is_door_open:
		return

	if has_escaped:
		return
	has_escaped = true

	if OS.is_debug_build():
		print("[Player] Επιτυχής απόδραση από το δωμάτιο!")

	# Εμφάνιση οθόνης νίκης και απελευθέρωση του κέρσορα
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if victory_screen:
		victory_screen.visible = true

	# Αναμονή 3 δευτερολέπτων για εμφάνιση των συγχαρητηρίων και καθαρός τερματισμός
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()
