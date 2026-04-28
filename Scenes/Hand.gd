extends Node2D

class_name Hand

var cards: Array = []
var card_spacing := 120.0  # space between cards in hand
var hand_y_offset := 20  # distance from bottom of viewport
var hand_base_scale := 0.6  # cards in hand are slightly smaller

func _ready() -> void:
	update_hand_layout()

func _process(_delta: float) -> void:
	update_hand_layout()

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
		var target_x = start_x + i * card_spacing
		var target_y = hand_y

		# Smooth movement to target position
		card.global_position = card.global_position.lerp(Vector2(target_x, target_y), 0.1)

		# Optional: slight fan effect based on card position in hand
		var fan_angle = (float(i) - float(cards.size() - 1) / 2.0) * 0.05
		card.rotation = lerp(card.rotation, fan_angle, 0.1)

		# Keep hand cards at a consistent scale
		card.scale = lerp(card.scale, Vector2.ONE * hand_base_scale, 0.1)

		# Keep hand cards below board cards in z-order
		card.z_index = i
