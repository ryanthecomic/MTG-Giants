extends Node

class_name GameState

signal match_initialized
signal game_state_changed
signal player_zone_changed(player_index: int, zone_name: String)
signal card_drawn(player_index: int, card_id: String)
signal library_shuffled(player_index: int)
signal life_changed(player_index: int, life_total: int)
signal turn_started(active_player_index: int, turn_number: int)
signal turn_ended(active_player_index: int, turn_number: int)
signal phase_changed(active_player_index: int, phase_name: String)
signal priority_changed(player_index: int)
signal stack_changed(stack_size: int)
signal action_logged(message: String)

enum TurnPhase {
	UNTAP,
	UPKEEP,
	DRAW,
	MAIN_1,
	COMBAT_BEGIN,
	DECLARE_ATTACKERS,
	DECLARE_BLOCKERS,
	COMBAT_DAMAGE,
	MAIN_2,
	END_STEP,
	CLEANUP,
}

@export var starting_life_total: int = 20
@export var max_players: int = 4
@export var local_player_index: int = 0
@export var local_player_name: String = "Player 1"
@export var starting_deck_ids: Array[String] = [
	"CR03",
	"RR01",
	"RR02",
	"RB01",
	"RM01",
	"CU06",
	"CW06",
	"CG06",
	"CR01",
	"MU01",
	"CR03",
	"RR01",
	"RB01",
	"RM01",
	"RR07",
	"CG33",
]

@onready var card_manager: CardManager = get_parent().get_node_or_null("CardManager") as CardManager

var players: Array[PlayerState] = []
var active_player_index: int = 0
var turn_order: Array[int] = []
var turn_number: int = 0
var current_phase: TurnPhase = TurnPhase.UNTAP
var priority_player_index: int = -1
var priority_pass_count: int = 0
var stack_items: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_bootstrap_local_match")

func _bootstrap_local_match() -> void:
	if players.is_empty():
		start_local_match(starting_deck_ids)

func start_local_match(deck_ids: Array[String]) -> void:
	players.clear()
	turn_order.clear()
	stack_items.clear()
	turn_number = 1
	current_phase = TurnPhase.UNTAP
	priority_pass_count = 0

	var local_player := PlayerState.new()
	local_player.initialize_from_deck(deck_ids, starting_life_total, local_player_name, local_player_index)
	players.append(local_player)
	turn_order.append(local_player_index)
	active_player_index = local_player_index
	priority_player_index = local_player_index

	emit_signal("match_initialized")
	emit_signal("turn_started", active_player_index, turn_number)
	emit_signal("phase_changed", active_player_index, get_current_phase_name())
	emit_signal("priority_changed", priority_player_index)
	emit_signal("stack_changed", stack_items.size())
	emit_signal("game_state_changed")
	emit_signal("player_zone_changed", local_player_index, "library")
	emit_signal("player_zone_changed", local_player_index, "hand")

func has_player(player_index: int) -> bool:
	return get_player_state(player_index) != null

func get_player_state(player_index: int) -> PlayerState:
	for player in players:
		if player.player_id == player_index:
			return player
	return null

func get_library_cards(player_index: int = local_player_index) -> Array[String]:
	var player := get_player_state(player_index)
	if player == null:
		return []
	return player.get_library_cards()

func get_hand_cards(player_index: int = local_player_index) -> Array[String]:
	var player := get_player_state(player_index)
	if player == null:
		return []
	return player.get_hand_cards()

func draw_card(player_index: int = local_player_index) -> String:
	var player := get_player_state(player_index)
	if player == null:
		return ""

	var card_id := player.draw_card()
	if card_id.is_empty():
		return ""

	player.hand.add_card(card_id)
	emit_signal("card_drawn", player_index, card_id)
	emit_signal("player_zone_changed", player_index, "library")
	emit_signal("player_zone_changed", player_index, "hand")
	emit_signal("game_state_changed")

	if player_index == local_player_index and card_manager and card_manager.has_method("draw_card_to_hand"):
		card_manager.draw_card_to_hand(card_id)

	return card_id

func get_current_phase_name() -> String:
	match current_phase:
		TurnPhase.UNTAP:
			return "Untap"
		TurnPhase.UPKEEP:
			return "Upkeep"
		TurnPhase.DRAW:
			return "Draw"
		TurnPhase.MAIN_1:
			return "Main 1"
		TurnPhase.COMBAT_BEGIN:
			return "Combat Begin"
		TurnPhase.DECLARE_ATTACKERS:
			return "Declare Attackers"
		TurnPhase.DECLARE_BLOCKERS:
			return "Declare Blockers"
		TurnPhase.COMBAT_DAMAGE:
			return "Combat Damage"
		TurnPhase.MAIN_2:
			return "Main 2"
		TurnPhase.END_STEP:
			return "End Step"
		TurnPhase.CLEANUP:
			return "Cleanup"
		_:
			return "Unknown"

func get_active_player_state() -> PlayerState:
	return get_player_state(active_player_index)

func get_priority_player_state() -> PlayerState:
	return get_player_state(priority_player_index)

func get_stack_size() -> int:
	return stack_items.size()

func get_stack_snapshot() -> Array[Dictionary]:
	return stack_items.duplicate(true)

func can_act(player_index: int) -> bool:
	return player_index == priority_player_index

func begin_turn() -> void:
	current_phase = TurnPhase.UNTAP
	priority_pass_count = 0
	priority_player_index = active_player_index
	emit_signal("turn_started", active_player_index, turn_number)
	emit_signal("phase_changed", active_player_index, get_current_phase_name())
	emit_signal("priority_changed", priority_player_index)
	emit_signal("game_state_changed")

func advance_phase() -> void:
	if current_phase == TurnPhase.CLEANUP:
		end_turn()
		return

	current_phase = TurnPhase.values()[current_phase + 1]
	priority_pass_count = 0
	priority_player_index = active_player_index
	emit_signal("phase_changed", active_player_index, get_current_phase_name())
	emit_signal("priority_changed", priority_player_index)
	emit_signal("game_state_changed")

func end_turn() -> void:
	emit_signal("turn_ended", active_player_index, turn_number)
	priority_pass_count = 0
	stack_items.clear()
	emit_signal("stack_changed", stack_items.size())
	advance_active_player()
	turn_number += 1
	current_phase = TurnPhase.UNTAP
	priority_player_index = active_player_index
	emit_signal("turn_started", active_player_index, turn_number)
	emit_signal("phase_changed", active_player_index, get_current_phase_name())
	emit_signal("priority_changed", priority_player_index)
	emit_signal("game_state_changed")

func advance_active_player() -> void:
	if turn_order.is_empty():
		return

	var current_order_index := turn_order.find(active_player_index)
	if current_order_index == -1:
		active_player_index = turn_order[0]
		return

	current_order_index = (current_order_index + 1) % turn_order.size()
	active_player_index = turn_order[current_order_index]

func pass_priority(player_index: int) -> bool:
	if not can_act(player_index):
		return false

	if turn_order.is_empty():
		return false

	priority_pass_count += 1
	if priority_pass_count >= turn_order.size():
		priority_pass_count = 0
		if stack_items.is_empty():
			advance_phase()
		else:
			resolve_top_of_stack()
			priority_player_index = active_player_index
			emit_signal("priority_changed", priority_player_index)
			emit_signal("game_state_changed")
		return true

	var next_priority_index := turn_order.find(priority_player_index)
	if next_priority_index == -1:
		next_priority_index = 0
	else:
		next_priority_index = (next_priority_index + 1) % turn_order.size()
	priority_player_index = turn_order[next_priority_index]
	emit_signal("priority_changed", priority_player_index)
	emit_signal("game_state_changed")
	return true

func clear_priority_passes() -> void:
	priority_pass_count = 0

func add_stack_item(source_player_index: int, item_type: String, card_id: String = "", description: String = "") -> void:
	var entry := {
		"source_player_index": source_player_index,
		"item_type": item_type,
		"card_id": card_id,
		"description": description,
	}
	stack_items.append(entry)
	clear_priority_passes()
	priority_player_index = active_player_index
	emit_signal("stack_changed", stack_items.size())
	emit_signal("priority_changed", priority_player_index)
	emit_signal("action_logged", get_stack_entry_label(entry))
	emit_signal("game_state_changed")

func resolve_top_of_stack() -> Dictionary:
	if stack_items.is_empty():
		return {}

	var entry: Dictionary = stack_items.pop_back()
	emit_signal("stack_changed", stack_items.size())
	emit_signal("action_logged", "Resolve: %s" % get_stack_entry_label(entry))
	emit_signal("game_state_changed")
	return entry

func get_stack_entry_label(entry: Dictionary) -> String:
	var description := String(entry.get("description", ""))
	if not description.is_empty():
		return description

	var item_type := String(entry.get("item_type", "Action"))
	var card_id := String(entry.get("card_id", ""))
	if not card_id.is_empty():
		return "%s (%s)" % [item_type, card_id]
	return item_type

func shuffle_library(player_index: int = local_player_index) -> void:
	var player := get_player_state(player_index)
	if player == null:
		return

	player.shuffle_library()
	emit_signal("library_shuffled", player_index)
	emit_signal("player_zone_changed", player_index, "library")
	emit_signal("game_state_changed")

func set_player_life(player_index: int, new_life_total: int) -> void:
	var player := get_player_state(player_index)
	if player == null:
		return

	player.life_total = new_life_total
	emit_signal("life_changed", player_index, new_life_total)
	emit_signal("game_state_changed")

func change_player_life(player_index: int, life_delta: int) -> void:
	var player := get_player_state(player_index)
	if player == null:
		return

	set_player_life(player_index, player.life_total + life_delta)

func get_state_summary() -> Dictionary:
	return {
		"turn_number": turn_number,
		"active_player_index": active_player_index,
		"priority_player_index": priority_player_index,
		"phase": get_current_phase_name(),
		"stack_size": stack_items.size(),
		"priority_pass_count": priority_pass_count,
	}
