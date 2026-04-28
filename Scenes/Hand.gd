extends Node2D

class_name Hand

var cards: Array = []
var card_spacing := 150.0  # space between cards in hand
var hand_y_offset := 20  # distance from bottom of viewport
var hand_base_scale := 0.6  # cards in hand are slightly smaller
var hand_base_y_offset := 0.0  # base offset before hover
var hand_sag_step := 20.0  # how much cards drop as they move away from center
var hand_sag_max := 120.0  # maximum drop for far-out cards
var hover_lift_amount := 200.0  # how much cards lift on hover (now jumps up significantly)
var hover_scale_boost := 1.15  # scale boost on hover (increased for more prominence)
var reorder_drag_threshold := 10.0  # pixels to move before reordering starts
var card_being_reordered: Node2D = null
var reorder_original_index := -1
var insertion_index := -1
var hovered_card: Node2D = null

func _ready() -> void:
	update_hand_layout()

func _process(delta: float) -> void:
	update_hand_layout()
	update_hover_detection()
	update_reorder_insertion()

func add_card(card: Node2D) -> void:
	if card not in cards:
		cards.append(card)
		# Reparent the card to the hand so it moves with the hand
		if card.get_parent():
			card.get_parent().remove_child(card)
		add_child(card)
		update_hand_layout()

func remove_card(card: Node2D) -> void:
	if card in cards:
		cards.erase(card)
		update_hand_layout()

func get_card_at_position(pos: Vector2) -> Node2D:
	"""Returns the card at the given global position, or null"""
	var viewport_size = get_viewport_rect().size
	var hand_y = viewport_size.y + hand_y_offset
	
	# Check if position is near hand height
	if abs(pos.y - hand_y) > 100:
		return null
	
	var start_x = (viewport_size.x - cards.size() * card_spacing) / 2.0 + card_spacing / 2.0
	
	for i in range(cards.size()):
		var card = cards[i]
		var card_x = start_x + i * card_spacing
		var distance = abs(pos.x - card_x)
		if distance < card_spacing / 2.0:
			return card
	
	return null

func start_reorder(card: Node2D) -> void:
	"""Begin reordering a card"""
	if card in cards:
		card_being_reordered = card
		reorder_original_index = cards.find(card)
		insertion_index = reorder_original_index
		card.set_meta("hand_reordering", true)
		card.set_meta("hand_reorder_y_offset", hand_y_offset)

func is_card_dragged_away_from_hand(card_pos: Vector2) -> bool:
	"""Check if a card has been dragged too far from the hand"""
	var viewport_size = get_viewport_rect().size
	var hand_y = viewport_size.y + hand_y_offset
	var distance_from_hand = abs(card_pos.y - hand_y)
	return distance_from_hand > 200.0  # More than 200 pixels away from hand slot

func abort_reorder() -> void:
	"""Abort reordering if card is dragged too far from hand"""
	if card_being_reordered:
		card_being_reordered.set_meta("hand_reordering", false)
		card_being_reordered = null
		insertion_index = -1

func finish_reorder() -> void:
	"""Finalize the reordering"""
	if card_being_reordered and insertion_index >= 0 and insertion_index != reorder_original_index:
		# Remove from old position
		cards.remove_at(reorder_original_index)
		# Insert at new position
		cards.insert(insertion_index, card_being_reordered)
	
	if card_being_reordered:
		card_being_reordered.set_meta("hand_reordering", false)
	
	card_being_reordered = null
	insertion_index = -1

func update_reorder_insertion() -> void:
	"""Calculate where a reordered card would be inserted"""
	if not card_being_reordered:
		return
	
	var mouse_pos = get_global_mouse_position()
	var viewport_size = get_viewport_rect().size
	var start_x = (viewport_size.x - cards.size() * card_spacing) / 2.0 + card_spacing / 2.0
	
	# Find which slot the card is over
	var closest_index = reorder_original_index
	var closest_distance = 999999.0
	
	for i in range(cards.size()):
		var slot_x = start_x + i * card_spacing
		var distance = abs(mouse_pos.x - slot_x)
		if distance < closest_distance:
			closest_distance = distance
			closest_index = i
	
	insertion_index = closest_index

func update_hover_detection() -> void:
	"""Update which card is being hovered"""
	var mouse_pos = get_global_mouse_position()
	var new_hovered_card = get_card_at_position(mouse_pos)
	
	# Clear old hover if different
	if hovered_card and hovered_card != new_hovered_card:
		hovered_card.set_meta("hand_hovering", false)
	
	hovered_card = new_hovered_card
	if hovered_card:
		hovered_card.set_meta("hand_hovering", true)

func update_hand_layout() -> void:
	if cards.is_empty():
		return

	var viewport_size = get_viewport_rect().size
	var hand_y = viewport_size.y + hand_y_offset

	# Calculate total width of all cards
	var total_width = cards.size() * card_spacing

	# Start position (centered horizontally)
	var start_x = (viewport_size.x - total_width) / 2.0 + card_spacing / 2.0

	for i in range(cards.size()):
		var card = cards[i]
		var center_index = float(cards.size() - 1) / 2.0
		
		# If a card is being reordered, position it at the mouse cursor
		if card == card_being_reordered:
			# Card stays at mouse position during reorder, no lerp needed
			# The CardManager handles its visual effects
			continue
		
		# Calculate target position, accounting for insertion point visualization
		var target_index = i
		if card_being_reordered and insertion_index >= 0:
			# If this card would be pushed aside by the reordered card
			if i >= insertion_index and i != reorder_original_index:
				target_index = i + 1
			elif i > insertion_index and i != reorder_original_index:
				target_index = i
		
		var target_x = start_x + target_index * card_spacing
		var center_distance = abs(float(target_index) - center_index)
		var target_y = hand_y + min(center_distance * hand_sag_step, hand_sag_max)
		
		# Apply hover lift
		if card == hovered_card and card != card_being_reordered:
			target_y -= hover_lift_amount
		
		# Smooth movement to target position
		card.global_position = card.global_position.lerp(Vector2(target_x, target_y), 0.15)

		# Slight fan effect based on position (no tilt when hovering)
		var target_rotation = 0.0
		if card != hovered_card:
			var fan_angle = (float(target_index) - float(cards.size() - 1) / 2.0) * 0.05
			target_rotation = fan_angle
		card.rotation = lerp(card.rotation, target_rotation, 0.12)

		# Handle scale based on hover
		var target_scale = hand_base_scale
		if card == hovered_card and card != card_being_reordered:
			target_scale = hand_base_scale * hover_scale_boost
		
		card.scale = lerp(card.scale, Vector2.ONE * target_scale, 0.12)

		# Z-order: hovered cards and reordered cards on top
		var target_z = i
		if card == hovered_card or card == card_being_reordered:
			target_z = 100
		card.z_index = target_z
