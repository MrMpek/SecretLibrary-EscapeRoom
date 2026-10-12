## Βασική κλάση αλληλεπιδράσιμων αντικειμένων (Interactable).
## Κληρονομεί από CollisionObject3D και επιτρέπει στον παίκτη να εντοπίζει
## και να αλληλεπιδρά με αντικείμενα μέσω raycasting (διακόπτες, κομμάτια παζλ, πύλη κ.λπ.).
class_name Interactable
extends CollisionObject3D

## Το μήνυμα προτροπής (HUD prompt) που εμφανίζεται στην οθόνη του παίκτη κατά τη σκόπευση.
@export var prompt_message: String = "Interact"

## Καθορίζει αν το αντικείμενο είναι ενεργό για αλληλεπίδραση στην παρούσα φάση του παιχνιδιού.
@export var is_interactive: bool = true

## Σήμα που εκπέμπεται κατά την επιτυχή αλληλεπίδραση, μεταβιβάζοντας τον κόμβο του παίκτη.
signal interacted(player: Node)

## Εκτελείται όταν ο παίκτης πατήσει το πλήκτρο αλληλεπίδρασης έχοντας στοχεύσει το αντικείμενο.
## Ελέγχει αν το αντικείμενο είναι ενεργό και εκπέμπει το αντίστοιχο σήμα [signal interacted].
func interact(player: Node) -> void:
	if is_interactive:
		if OS.is_debug_build():
			print("[Interactable] Αλληλεπίδραση με αντικείμενο: ", name)
		interacted.emit(player)
	else:
		if OS.is_debug_build():
			print("[Interactable] Το αντικείμενο ", name, " είναι ανενεργό (is_interactive = false).")
