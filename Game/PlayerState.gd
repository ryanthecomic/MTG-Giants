extends Resource

class_name PlayerState

@export var player_id: int = 0
@export var display_name: String = "Player"
@export var life_total: int = 20
@export var commander_damage: Dictionary = {}

var library: ZoneState = ZoneState.new()
var hand: ZoneState = ZoneState.new()
var graveyard: ZoneState = ZoneState.new()
var exile: ZoneState = ZoneState.new()
var command_zone: ZoneState = ZoneState.new()
var battlefield: ZoneState = ZoneState.new()
var stack_zone: ZoneState = ZoneState.new()

func _init() -> void:
	_setup_zone_types()

func _setup_zone_types() -> void:
	library.zone_type = ZoneState.ZoneType.LIBRARY
	hand.zone_type = ZoneState.ZoneType.HAND
	graveyard.zone_type = ZoneState.ZoneType.GRAVEYARD
	exile.zone_type = ZoneState.ZoneType.EXILE
	command_zone.zone_type = ZoneState.ZoneType.COMMAND
	battlefield.zone_type = ZoneState.ZoneType.BATTLEFIELD
	stack_zone.zone_type = ZoneState.ZoneType.STACK

func initialize_from_deck(deck_ids: Array[String], starting_life_total: int, new_display_name: String, new_player_id: int) -> void:
	player_id = new_player_id
	display_name = new_display_name
	life_total = starting_life_total
	library.cards = deck_ids.duplicate()
	hand.cards.clear()
	graveyard.cards.clear()
	exile.cards.clear()
	command_zone.cards.clear()
	battlefield.cards.clear()
	stack_zone.cards.clear()

func draw_card() -> String:
	return library.draw_top()

func shuffle_library() -> void:
	library.shuffle()

func get_library_cards() -> Array[String]:
	return library.duplicate_cards()

func get_hand_cards() -> Array[String]:
	return hand.duplicate_cards()
