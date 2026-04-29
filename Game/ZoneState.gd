extends Resource

class_name ZoneState

enum ZoneType {
	LIBRARY,
	HAND,
	GRAVEYARD,
	EXILE,
	COMMAND,
	BATTLEFIELD,
	STACK,
}

@export var zone_type: ZoneType = ZoneType.LIBRARY
@export var cards: Array[String] = []

func is_empty() -> bool:
	return cards.is_empty()

func add_card(card_id: String) -> void:
	cards.append(card_id)

func draw_top() -> String:
	if cards.is_empty():
		return ""

	return cards.pop_back()

func shuffle() -> void:
	cards.shuffle()

func duplicate_cards() -> Array[String]:
	return cards.duplicate()
