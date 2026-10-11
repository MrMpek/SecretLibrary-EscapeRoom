## Κεντρικός διαχειριστής της ροής του παιχνιδιού και των γρίφων (GameManager).
## Συντονίζει τους δύο διαδοχικούς γρίφους του Escape Room:
## 1. Τον γρίφο της βιβλιοθήκης (ακολουθία διακοπτών/βιβλίων).
## 2. Τον γρίφο του τραπεζιού (περιστροφή κομματιών για σχηματισμό κλειστού ισόπλευρου τριγώνου).
## Ελέγχει επίσης το τελικό ξεκλείδωμα του θυρεού και το άνοιγμα της πύλης εξόδου.
class_name GameManager
extends Node

## Πρώτος διακόπτης (βιβλίο) της βιβλιοθήκης.
@export var switch_1: CollisionObject3D

## Δεύτερος διακόπτης (βιβλίο) της βιβλιοθήκης.
@export var switch_2: CollisionObject3D

## Τρίτος διακόπτης (βιβλίο) της βιβλιοθήκης.
@export var switch_3: CollisionObject3D

## Φωτεινός δείκτης κατάστασης πρώτου διακόπτη.
@export var indicator_1: MeshInstance3D

## Φωτεινός δείκτης κατάστασης δεύτερου διακόπτη.
@export var indicator_2: MeshInstance3D

## Φωτεινός δείκτης κατάστασης τρίτου διακόπτη.
@export var indicator_3: MeshInstance3D

## Μυστικός θυρεός/διακόπτης ανοίγματος της πόρτας εξόδου.
@export var access_panel: CollisionObject3D

## Κεντρικός φωτεινός κρύσταλλος/δείκτης του πίνακα εξόδου.
@export var panel_indicator: MeshInstance3D

## Κόμβος αναφοράς για την περιστροφή και το άνοιγμα της πόρτας εξόδου.
@export var exit_door_pivot: Node3D

## Πρώτο κομμάτι του γεωμετρικού παζλ (οριζόντια βάση).
@export var piece_1: CollisionObject3D

## Δεύτερο κομμάτι του γεωμετρικού παζλ (αριστερή πλευρά).
@export var piece_2: CollisionObject3D

## Τρίτο κομμάτι του γεωμετρικού παζλ (δεξιά πλευρά).
@export var piece_3: CollisionObject3D

## Η σωστή ακολουθία ενεργοποίησης: Βιβλίο 1 (0) -> Βιβλίο 3 (2) -> Βιβλίο 2 (1).
var correct_sequence: Array[int] = [0, 2, 1]

## Η ακολουθία που έχει πατηθεί από τον παίκτη μέχρι στιγμής.
var current_sequence: Array[int] = []

## Κατάσταση κλίσης/τραβήγματος κάθε διακόπτη (true = τραβηγμένο, false = αρχική θέση).
var switch_states: Array[bool] = [false, false, false]

## Αθροιστικές οπτικές γωνίες κομματιών για ομαλή περιστροφή μέσω Tweening (+60° πάντοτε εμπρός).
## Αρχικοποίηση σε μη λυμένη κατάσταση: [0°, 180°, 60°].
var piece_visual_angles: Array[float] = [0.0, 180.0, 60.0]

## Αναφορές στα ενεργά Tweens περιστροφής κάθε κομματιού για ασφαλή ανακύκλωση.
var piece_tweens: Array = [null, null, null]

## Κοινό υλικό κόκκινου φωτεινού δείκτη (κλειδωμένη κατάσταση).
var red_material: StandardMaterial3D

## Κοινό υλικό πράσινου φωτεινού δείκτη (ξεκλειδωμένη κατάσταση).
var green_material: StandardMaterial3D

## Σημαία που δηλώνει αν οι γρίφοι έχουν λυθεί και ο θυρεός έχει ξεκλειδώσει.
var is_unlocked: bool = false

## Σημαία που δηλώνει αν η πόρτα εξόδου είναι ανοιχτή.
var is_door_open: bool = false

## Σημαία που δηλώνει αν ο 2ος γρίφος (τρίγωνο) έχει εμφανιστεί στο τραπέζι.
var is_triangle_puzzle_revealed: bool = false

## Σημαία αποτροπής ταυτόχρονων ενεργειών κατά την επαναφορά λάθος ακολουθίας.
var is_resetting: bool = false

## Αρχικοποίηση υλικών δεικτών, δυναμική σύνδεση σημάτων και απόκρυψη κομματιών 2ου γρίφου.
func _ready() -> void:
	if OS.is_debug_build():
		print("[GameManager] Αρχικοποίηση GameManager...")

	# Δυναμική επίλυση κόμβων αν δεν έχουν οριστεί ρητά στον επιθεωρητή
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

	# Δημιουργία κοινών εκπεμπόντων υλικών (StandardMaterial3D) για βελτιστοποίηση draw calls
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

	# Αρχικοποίηση των φωτεινών δεικτών σε κόκκινη ένδειξη
	reset_indicators()

	# Αρχική κλειδωμένη κατάσταση του θυρεού εξόδου
	if access_panel:
		access_panel.set("is_interactive", false)
		access_panel.set("prompt_message", "Locked")
	if panel_indicator:
		panel_indicator.set_surface_override_material(0, red_material)

	# Απόκρυψη και απενεργοποίηση συγκρούσεων των κομματιών του τριγώνου μέχρι να λυθεί ο 1ος γρίφος
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

	# Σύνδεση σημάτων αλληλεπίδρασης
	if switch_1: switch_1.connect("interacted", _on_switch_interacted.bind(0))
	if switch_2: switch_2.connect("interacted", _on_switch_interacted.bind(1))
	if switch_3: switch_3.connect("interacted", _on_switch_interacted.bind(2))

	if access_panel: access_panel.connect("interacted", _on_access_panel_interacted)

	if piece_1: piece_1.connect("interacted", _on_piece_interacted.bind(0))
	if piece_2: piece_2.connect("interacted", _on_piece_interacted.bind(1))
	if piece_3: piece_3.connect("interacted", _on_piece_interacted.bind(2))

## Επαναφορά των φωτεινών δεικτών της βιβλιοθήκης σε κόκκινο χρώμα.
func reset_indicators() -> void:
	if indicator_1: indicator_1.set_surface_override_material(0, red_material)
	if indicator_2: indicator_2.set_surface_override_material(0, red_material)
	if indicator_3: indicator_3.set_surface_override_material(0, red_material)

## Διαχείριση αλληλεπίδρασης με διακόπτη/βιβλίο της βιβλιοθήκης.
func _on_switch_interacted(_player: Node, switch_index: int) -> void:
	if is_triangle_puzzle_revealed or is_unlocked or is_resetting:
		return

	# Εναλλαγή κατάστασης διακόπτη
	switch_states[switch_index] = !switch_states[switch_index]

	# Οπτική κίνηση κλίσης του βιβλίου
	var target_rotation: float = 25.0 if switch_states[switch_index] else -25.0
	var switch_node: Node3D = null
	if switch_index == 0: switch_node = switch_1
	elif switch_index == 1: switch_node = switch_2
	elif switch_index == 2: switch_node = switch_3

	if switch_node:
		var tween := create_tween()
		tween.tween_property(switch_node, "rotation_degrees:x", target_rotation, 0.2).set_trans(Tween.TRANS_SINE)

	# Προσθήκη στην τρέχουσα σειρά επιλογών
	current_sequence.append(switch_index)

	# Έλεγχος αν η ακολουθία που δόθηκε συμφωνεί με τη σωστή
	var step_count: int = current_sequence.size()
	var is_correct_so_far: bool = true
	for i in range(step_count):
		if current_sequence[i] != correct_sequence[i]:
			is_correct_so_far = false
			break

	if is_correct_so_far:
		# Ενημέρωση αντίστοιχου φωτεινού δείκτη σε πράσινο χρώμα
		if switch_index == 0 and indicator_1:
			indicator_1.set_surface_override_material(0, green_material)
		elif switch_index == 2 and indicator_3:
			indicator_3.set_surface_override_material(0, green_material)
		elif switch_index == 1 and indicator_2:
			indicator_2.set_surface_override_material(0, green_material)

		# Αν συμπληρώθηκε ολόκληρη η ακολουθία, εμφάνιση του 2ου γρίφου
		if step_count == correct_sequence.size():
			if OS.is_debug_build():
				print("[GameManager] Ο γρίφος της βιβλιοθήκης λύθηκε! Εμφάνιση παζλ τριγώνου...")
			reveal_triangle_puzzle()
	else:
		if OS.is_debug_build():
			print("[GameManager] Λάθος ακολουθία βιβλίων. Επαναφορά γρίφου...")
		reset_puzzle()

## Επαναφορά του 1ου γρίφου σε περίπτωση λανθασμένης επιλογής (αναβόσβημα δεικτών).
func reset_puzzle() -> void:
	is_resetting = true
	current_sequence.clear()

	# Αναβόσβημα των δεικτών με κόκκινο χρώμα για ένδειξη αποτυχίας
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

	# Επαναφορά θέσης των βιβλίων στην αρχική τους κλίση
	switch_states = [false, false, false]
	for switch_node in [switch_1, switch_2, switch_3]:
		if switch_node:
			var tween := create_tween()
			tween.tween_property(switch_node, "rotation_degrees:x", -25.0, 0.3).set_trans(Tween.TRANS_SINE)

	is_resetting = false

## Ενεργοποιεί ή απενεργοποιεί τα CollisionShape3D ενός κομματιού.
func _set_piece_collision(piece_node: Node, enabled: bool) -> void:
	if not piece_node: return
	for child in piece_node.get_children():
		if child is CollisionShape3D:
			child.disabled = !enabled

## Εμφανίζει τα κομμάτια του 2ου γρίφου στο τραπέζι και ενεργοποιεί τις συγκρούσεις τους.
func reveal_triangle_puzzle() -> void:
	is_triangle_puzzle_revealed = true
	for piece in [piece_1, piece_2, piece_3]:
		if piece:
			piece.set("visible", true)
			piece.set("is_interactive", true)
			piece.set("prompt_message", "Rotate Piece")
			_set_piece_collision(piece, true)

## Διαχείριση αλληλεπίδρασης περιστροφής κομματιού του 2ου γρίφου.
func _on_piece_interacted(_player: Node, piece_index: int) -> void:
	if is_unlocked:
		return

	var piece: Node3D = null
	if piece_index == 0: piece = piece_1
	elif piece_index == 1: piece = piece_2
	elif piece_index == 2: piece = piece_3

	if not piece:
		return

	# Προσθήκη +60° στην αθροιστική οπτική γωνία για σταθερή φορά περιστροφής
	piece_visual_angles[piece_index] += 60.0
	var target_rotation: float = piece_visual_angles[piece_index]

	# Ασφαλής ακύρωση προηγούμενου ενεργού Tween για αποφυγή συγκρούσεων
	if piece_tweens[piece_index] and piece_tweens[piece_index].is_valid():
		piece_tweens[piece_index].kill()

	var tween := create_tween()
	piece_tweens[piece_index] = tween
	tween.tween_property(piece, "rotation_degrees:y", target_rotation, 0.22).set_trans(Tween.TRANS_SINE)
	await tween.finished

	check_triangle_puzzle()

## Ελέγχει αν τα 3 κομμάτια έχουν τον κατάλληλο προσανατολισμό ώστε να σχηματίζουν κλειστό τρίγωνο.
func check_triangle_puzzle() -> void:
	if not piece_1 or not piece_2 or not piece_3:
		return

	# Κανονικοποίηση των γωνιών στο διάστημα [0°, 360°)
	var angle1 := int(round(fposmod(piece_visual_angles[0], 360.0)))
	var angle2 := int(round(fposmod(piece_visual_angles[1], 360.0)))
	var angle3 := int(round(fposmod(piece_visual_angles[2], 360.0)))

	# Κομμάτι 1 (οριζόντια βάση): απαιτείται γωνία 0° ή 180° (mod 180 == 0)
	# Κομμάτι 2 (αριστερή πλευρά): απαιτείται γωνία 60° ή 240° (mod 180 == 60)
	# Κομμάτι 3 (δεξιά πλευρά): απαιτείται γωνία 120° ή 300° (mod 180 == 120)
	var is_p1_valid := (angle1 % 180 == 0)
	var is_p2_valid := (angle2 % 180 == 60)
	var is_p3_valid := (angle3 % 180 == 120)

	if is_p1_valid and is_p2_valid and is_p3_valid:
		if OS.is_debug_build():
			print("[GameManager] Το γεωμετρικό παζλ λύθηκε επιτυχώς! Ξεκλείδωμα θυρεού εξόδου...")
		unlock_escape_door()

## Ξεκλειδώνει τον μυστικό θυρεό εξόδου και ενημερώνει τον φωτεινό κρύσταλλο σε πράσινο.
func unlock_escape_door() -> void:
	is_unlocked = true
	if panel_indicator:
		panel_indicator.set_surface_override_material(0, green_material)
	if access_panel:
		access_panel.set("is_interactive", true)
		access_panel.set("prompt_message", "Turn Secret Crest")

## Διαχείριση αλληλεπίδρασης με τον ξεκλειδωμένο θυρεό για το άνοιγμα της πόρτας εξόδου.
func _on_access_panel_interacted(_player: Node) -> void:
	if is_unlocked and not is_door_open:
		is_door_open = true
		if access_panel:
			access_panel.set("is_interactive", false)
			access_panel.set("prompt_message", "Door Opening...")

		# Ομαλό άνοιγμα της πύλης με περιστροφή 90° γύρω από τον κατακόρυφο άξονα Y
		if exit_door_pivot:
			var tween := create_tween()
			tween.tween_property(exit_door_pivot, "rotation_degrees:y", 90.0, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			await tween.finished
			if access_panel:
				access_panel.set("prompt_message", "Escaped")
