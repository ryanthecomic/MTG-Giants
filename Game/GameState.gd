extends Node

class_name GameState

signal match_initialized
signal game_state_changed
signal player_zone_changed(player_index, zone_name)
signal card_drawn(player_index, card_id)
signal library_shuffled(player_index)
signal life_changed(player_index, life_total)
signal turn_started(active_player_index, turn_number)
signal turn_ended(active_player_index, turn_number)
signal phase_changed(active_player_index, phase_name)
signal priority_changed(player_index)
signal stack_changed(stack_size)
signal action_logged(message)

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
var action_history: Array[Dictionary] = []

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

func get_battlefield_cards(player_index: int) -> Array[String]:
	var player := get_player_state(player_index)
	if player == null:
		return []
	return player.battlefield.duplicate_cards()

func play_card_to_battlefield(player_index: int, card_id: String) -> bool:
	# Move a card from hand to battlefield
	var player := get_player_state(player_index)
	if player == null:
		return false
	
	var ok = player.move_card_to_battlefield(card_id)
	if ok:
		action_history.append({"type":"play","player":player_index,"card_id":card_id})
		emit_signal("action_logged", "Played: %s" % card_id)
		emit_signal("player_zone_changed", player_index, "hand")
		emit_signal("player_zone_changed", player_index, "battlefield")
		emit_signal("game_state_changed")
	return ok

func toggle_tap_on_battlefield(player_index: int, card_id: String) -> bool:
	# Toggle tap state of card on battlefield
	var player := get_player_state(player_index)
	if player == null:
		return false
	
	var ok = player.toggle_tap_card(card_id)
	if ok:
		var tapped = player.is_card_tapped(card_id)
		action_history.append({"type":"tap_toggle","player":player_index,"card_id":card_id,"tapped":tapped})
		emit_signal("action_logged", "%s: %s" % ["Tap" if tapped else "Untap", card_id])
		emit_signal("player_zone_changed", player_index, "battlefield")
		emit_signal("game_state_changed")
	return ok

func remove_card_from_battlefield(player_index: int, card_id: String) -> bool:
	# Remove card from battlefield
	var player := get_player_state(player_index)
	if player == null:
		return false
	
	var ok = player.remove_card_from_battlefield(card_id)
	if ok:
		action_history.append({"type":"remove_from_battlefield","player":player_index,"card_id":card_id})
		emit_signal("action_logged", "Removed: %s" % card_id)
		emit_signal("player_zone_changed", player_index, "battlefield")
		emit_signal("game_state_changed")
	return ok

func is_card_tapped_on_battlefield(player_index: int, card_id: String) -> bool:
	var player := get_player_state(player_index)
	if player == null:
		return false
	return player.is_card_tapped(card_id)

func draw_card(player_index: int = local_player_index) -> String:
	var player := get_player_state(player_index)
	if player == null:
		return ""

	var card_id := player.draw_card()
	if card_id.is_empty():
		return ""

	player.hand.add_card(card_id)
	# Log action for undo
	action_history.append({"type":"draw","player":player_index,"card_id":card_id})
	emit_signal("action_logged", "Draw: %s" % card_id)
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
	# record stack add for undo
	action_history.append({"type":"stack_add","entry":entry})
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
	# Log resolve so it can be undone
	action_history.append({"type":"stack_resolve","entry":entry})
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

	# record previous order for undo
	var prev := player.library.duplicate_cards()
	player.shuffle_library()
	action_history.append({"type":"shuffle","player":player_index,"prev_order":prev})
	emit_signal("action_logged", "Shuffle")
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

	# Log life change so it can be undone
	action_history.append({"type":"life","player":player_index,"delta":life_delta})
	set_player_life(player_index, player.life_total + life_delta)
	emit_signal("action_logged", "Life %+d for P%d" % [life_delta, player_index])

func get_state_summary() -> Dictionary:
	return {
		"turn_number": turn_number,
		"active_player_index": active_player_index,
		"priority_player_index": priority_player_index,
		"phase": get_current_phase_name(),
		"stack_size": stack_items.size(),
		"priority_pass_count": priority_pass_count,
	}

func undo_last_action() -> bool:
	if action_history.is_empty():
		emit_signal("action_logged", "No actions to undo")
		return false

	var entry: Dictionary = action_history.pop_back()
	var t: String = String(entry.get("type", ""))
	if t == "draw":
		var player_index: int = int(entry.get("player", 0))
		var p: PlayerState = get_player_state(player_index)
		if p:
			var card_id: String = String(entry.get("card_id", ""))
			# remove card from hand if present and put back on top of library
			for i in range(p.hand.cards.size() - 1, -1, -1):
				var idx: int = i
				if p.hand.cards[idx] == card_id:
					p.hand.cards.remove_at(idx)
					break
			p.library.cards.append(card_id)
			emit_signal("action_logged", "Undo Draw: %s" % card_id)
			emit_signal("player_zone_changed", player_index, "library")
			emit_signal("player_zone_changed", player_index, "hand")
			emit_signal("game_state_changed")
			return true
		# draw branch fell through (player missing)
		return false
	elif t == "shuffle":
		var player_index2: int = int(entry.get("player", 0))
		var p2: PlayerState = get_player_state(player_index2)
		if p2 and entry.has("prev_order"):
			p2.library.cards = entry["prev_order"].duplicate()
			emit_signal("action_logged", "Undo Shuffle")
			emit_signal("player_zone_changed", player_index2, "library")
			emit_signal("game_state_changed")
			return true
		# shuffle branch could not be undone (no prev_order or no player)
		return false
	elif t == "life":
		var player_index3: int = int(entry.get("player", 0))
		var p3: PlayerState = get_player_state(player_index3)
		if p3:
			set_player_life(player_index3, p3.life_total - int(entry.get("delta", 0)))
			emit_signal("action_logged", "Undo Life %+d" % int(entry.get("delta", 0)))
			return true
		# life branch could not be undone (player missing)
		return false
	elif t == "stack_add":
		if not stack_items.is_empty():
			var last: Dictionary = stack_items[stack_items.size() - 1]
			if last == entry["entry"]:
				stack_items.pop_back()
				emit_signal("action_logged", "Undo Stack Add")
				emit_signal("stack_changed", stack_items.size())
				return true
			return false
		# stack_add branch could not be undone (stack empty)
		return false
	elif t == "stack_resolve":
		stack_items.append(entry["entry"])
		emit_signal("action_logged", "Undo Resolve")
		emit_signal("stack_changed", stack_items.size())
		emit_signal("game_state_changed")
		return true
	elif t == "play":
		var player_index4: int = int(entry.get("player", 0))
		var p4: PlayerState = get_player_state(player_index4)
		if p4:
			var card_id: String = String(entry.get("card_id", ""))
			p4.remove_card_from_battlefield(card_id)
			p4.hand.add_card(card_id)
			emit_signal("action_logged", "Undo Play: %s" % card_id)
			emit_signal("player_zone_changed", player_index4, "battlefield")
			emit_signal("player_zone_changed", player_index4, "hand")
			emit_signal("game_state_changed")
			return true
		return false
	elif t == "tap_toggle":
		var player_index5: int = int(entry.get("player", 0))
		var p5: PlayerState = get_player_state(player_index5)
		if p5:
			var card_id: String = String(entry.get("card_id", ""))
			p5.toggle_tap_card(card_id)
			emit_signal("action_logged", "Undo Tap Toggle: %s" % card_id)
			emit_signal("player_zone_changed", player_index5, "battlefield")
			emit_signal("game_state_changed")
			return true
		return false
	elif t == "remove_from_battlefield":
		var player_index6: int = int(entry.get("player", 0))
		var p6: PlayerState = get_player_state(player_index6)
		if p6:
			var card_id: String = String(entry.get("card_id", ""))
			# Put card back on battlefield (untapped)
			p6.battlefield.add_card(card_id)
			p6.battlefield_tapped[card_id] = false
			emit_signal("action_logged", "Undo Remove: %s" % card_id)
			emit_signal("player_zone_changed", player_index6, "battlefield")
			emit_signal("game_state_changed")
			return true
		return false
	else:
		emit_signal("action_logged", "Unknown action to undo")
		return false
