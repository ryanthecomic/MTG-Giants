extends Node2D

class_name Hand

var cards: Array = []
var card_spacing := 150.0  # space between cards in hand
var hand_scroll_offset := 0.0
var hand_y_offset := 20  # distance from bottom of viewport
var hand_arc_angle_step := 0.064
var hand_arc_radius_factor := 0.52
var hand_base_scale := 0.75  # cards in hand are slightly smaller
var hand_base_y_offset := 0.0  # base offset before hover
var hand_sag_step := 12.0  # how much cards drop as they move away from center
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

func _process(_delta: float) -> void:
	update_hand_layout()
	update_hover_detection()
	update_reorder_insertion()

func uses_circular_layout() -> bool:
	return cards.size() > 11

func get_hand_scroll_limit() -> float:
	if cards.size() <= 11:
		return 0.0

	return max(0.0, float(cards.size() - 11))

func clamp_hand_scroll_offset() -> void:
	var max_scroll = get_hand_scroll_limit()
	hand_scroll_offset = clamp(hand_scroll_offset, -max_scroll, max_scroll)

func scroll_hand(amount: float) -> void:
	hand_scroll_offset += amount
	clamp_hand_scroll_offset()

func is_point_near_hand(pos: Vector2) -> bool:
	return get_card_at_position(pos) != null

func get_card_target_position(target_index: int, viewport_size: Vector2) -> Vector2:
	var hand_y = viewport_size.y + hand_y_offset

	var target_x: float = 0.0
	var target_y: float = 0.0

	if not uses_circular_layout():
		var spacing = card_spacing
		var total_width = cards.size() * spacing
		var start_x = viewport_size.x / 2.0 - total_width / 2.0 + spacing / 2.0
		var center_index = float(cards.size() - 1) / 2.0
		target_x = start_x + target_index * spacing
		target_y = hand_y + min(abs(float(target_index) - center_index) * hand_sag_step, hand_sag_max)
	else:
		var center_index_circ = float(cards.size() - 1) / 2.0 + hand_scroll_offset
		var relative_index = float(target_index) - center_index_circ
		var radius = max(viewport_size.x * hand_arc_radius_factor, 360.0)
		var angle = relative_index * hand_arc_angle_step
		target_x = viewport_size.x / 2.0 + sin(angle) * radius
		target_y = hand_y + (1.0 - cos(angle)) * radius * 0.85

	return Vector2(target_x, target_y)

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
	if cards.is_empty():
		return null

	var viewport_size = get_viewport_rect().size
	var hit_radius = 130.0
	
	for i in range(cards.size()):
		var card = cards[i]
		var card_position = get_card_target_position(i, viewport_size)
		if pos.distance_to(card_position) <= hit_radius:
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
	
	# Find which slot the card is over
	var closest_index = reorder_original_index
	var closest_distance = 999999.0
	
	for i in range(cards.size()):
		var slot_position = get_card_target_position(i, viewport_size)
		var distance = mouse_pos.distance_to(slot_position)
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
	clamp_hand_scroll_offset()

	for i in range(cards.size()):
		var card = cards[i]
		
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

		var target_position = get_card_target_position(target_index, viewport_size)
		
		# Apply hover lift
		if card == hovered_card and card != card_being_reordered:
			target_position.y = viewport_size.y + hand_y_offset - hover_lift_amount - 50
		
		# Smooth movement to target position
		card.global_position = card.global_position.lerp(target_position, 0.15)

		# Slight fan effect based on position (no tilt when hovering)
		var target_rotation = 0.0
		if card != hovered_card:
			if uses_circular_layout():
				var angle = (float(target_index) - (float(cards.size() - 1) / 2.0 + hand_scroll_offset)) * hand_arc_angle_step
				target_rotation = angle * 0.42
			else:
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
