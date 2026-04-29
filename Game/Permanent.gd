extends Resource

class_name Permanent

# A Permanent represents a card on the battlefield with game state
@export var card_id: String = ""
@export var tapped: bool = false
@export var counters: Dictionary = {}  # counter_type -> count
@export var zone_state: String = "BATTLEFIELD"  # BATTLEFIELD, GRAVEYARD, EXILE, etc.

func _init(p_card_id: String = "") -> void:
	card_id = p_card_id
	tapped = false
	counters = {}
	zone_state = "BATTLEFIELD"

func tap() -> void:
	tapped = true

func untap() -> void:
	tapped = false

func toggle_tap() -> void:
	tapped = not tapped

func add_counter(counter_type: String, count: int = 1) -> void:
	if not counters.has(counter_type):
		counters[counter_type] = 0
	counters[counter_type] += count

func remove_counter(counter_type: String, count: int = 1) -> bool:
	if not counters.has(counter_type) or counters[counter_type] < count:
		return false
	counters[counter_type] -= count
	if counters[counter_type] <= 0:
		counters.erase(counter_type)
	return true

func duplicate_permanent() -> Permanent:
	var copy = Permanent.new(card_id)
	copy.tapped = tapped
	copy.counters = counters.duplicate()
	copy.zone_state = zone_state
	return copy

func to_dict() -> Dictionary:
	return {
		"card_id": card_id,
		"tapped": tapped,
		"counters": counters.duplicate(),
		"zone_state": zone_state
	}
