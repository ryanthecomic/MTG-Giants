extends Node2D

var card_id: String = ""
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
var outline_rect: ColorRect = null
var hand_parent: Node = null
var game_state: GameState = null
var is_over_battlefield: bool = false

func _ready() -> void:
	if card_id != "":
		load_card_image(card_id)
	
	# Get references
	hand_parent = get_parent()
	game_state = get_tree().root.get_child(0).get_node_or_null("GameState") as GameState
	
	# Connect Area2D signals for drag detection
	var area = $Area2D
	if area:
		if not area.input_event.is_connected(Callable(self, "_on_area_input_event")):
			area.input_event.connect(Callable(self, "_on_area_input_event"))
		if not area.mouse_entered.is_connected(Callable(self, "_on_area_mouse_entered")):
			area.mouse_entered.connect(Callable(self, "_on_area_mouse_entered"))
		if not area.mouse_exited.is_connected(Callable(self, "_on_area_mouse_exited")):
			area.mouse_exited.connect(Callable(self, "_on_area_mouse_exited"))

func load_card_image(id: String) -> void:
	card_id = id
	# Construct the path to search for the card image
	var card_arts_path = "res://Card Arts/Playtest Card Arts/"
	
	# Search for a .png file that starts with the card_id
	var dir = DirAccess.open(card_arts_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			# Look for .png files that start with the card_id
			if file_name.begins_with(id) and file_name.ends_with(".png"):
				var full_path = card_arts_path + file_name
				var texture = load(full_path)
				if texture:
					$CardImage.texture = texture
					return
			file_name = dir.get_next()
		print("Warning: Card image not found for ID '%s'" % id)
	else:
		print("Error: Could not access Card Arts folder")

func _on_area_mouse_entered() -> void:
	# Show hover state if not dragging
	if not is_dragging:
		_show_hover_outline()

func _on_area_mouse_exited() -> void:
	# Hide hover state if not dragging
	if not is_dragging:
		_hide_hover_outline()
	is_over_battlefield = false

func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start drag
				is_dragging = true
				original_position = global_position
				drag_offset = get_global_mouse_position() - global_position
				_check_battlefield_collision()  # Initial check
			else:
				# End drag - check if over battlefield
				_check_battlefield_collision()
				is_dragging = false
				_hide_drag_outline()
				
				if is_over_battlefield and game_state:
					# Play card to battlefield
					var player_hand = hand_parent
					if player_hand and player_hand is Hand and player_hand.cards.has(self):
						var ok = game_state.play_card_to_battlefield(0, card_id)  # player_index = 0 (local player)
						if ok:
							player_hand.remove_card(self)
							queue_free()  # Remove card from scene
							print("Card played: %s" % card_id)
						else:
							_return_to_hand()
					else:
						_return_to_hand()
				else:
					_return_to_hand()
	
	elif event is InputEventMouseMotion and is_dragging:
		# Update position during drag
		global_position = get_global_mouse_position() - drag_offset
		_check_battlefield_collision()

func _show_hover_outline() -> void:
	if outline_rect == null:
		outline_rect = ColorRect.new()
		outline_rect.name = "OutlineRect"
		outline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline_rect.z_index = -1
		$CardImage.add_sibling(outline_rect)
	
	# Small white border for hover
	outline_rect.size = $CardImage.texture.get_size() * scale
	outline_rect.color = Color(1, 1, 1, 0.3)

func _show_drag_outline() -> void:
	# This function is now replaced by drop detection
	pass

func _hide_drag_outline() -> void:
	if outline_rect:
		outline_rect.queue_free()
		outline_rect = null

func _hide_hover_outline() -> void:
	if outline_rect:
		outline_rect.modulate = Color(1, 1, 1, 1)
		outline_rect.color = Color(1, 1, 1, 0)

func _show_drop_valid_outline() -> void:
	# Bright orange outline when can drop
	if outline_rect == null:
		outline_rect = ColorRect.new()
		outline_rect.name = "OutlineRect"
		outline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline_rect.z_index = -1
		$CardImage.add_sibling(outline_rect)
	
	outline_rect.size = $CardImage.texture.get_size() * scale
	outline_rect.color = Color(1, 0.65, 0, 1)  # orange
	outline_rect.modulate = Color(2, 1.3, 0, 1)  # bright glow

func _show_drop_invalid_outline() -> void:
	# Dim yellow outline when cannot drop
	if outline_rect == null:
		outline_rect = ColorRect.new()
		outline_rect.name = "OutlineRect"
		outline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		outline_rect.z_index = -1
		$CardImage.add_sibling(outline_rect)
	
	outline_rect.size = $CardImage.texture.get_size() * scale
	outline_rect.color = Color(1, 1, 0, 0.6)  # dim yellow
	outline_rect.modulate = Color(1, 1, 0, 1)

func _check_battlefield_collision() -> void:
	# Check if the mouse is inside the battlefield drop rectangle
	var battlefield = get_tree().root.get_child(0).get_node_or_null("Battlefield") as Battlefield
	if battlefield == null:
		is_over_battlefield = false
		_show_drop_invalid_outline()
		return

	if not battlefield.has_method("is_point_inside_drop_zone"):
		is_over_battlefield = false
		_show_drop_invalid_outline()
		return

	is_over_battlefield = battlefield.is_point_inside_drop_zone(get_global_mouse_position())
	
	# Update outline color based on whether we can drop
	if is_over_battlefield:
		_show_drop_valid_outline()
	else:
		_show_drop_invalid_outline()

func _return_to_hand() -> void:
	# Animate back to original position
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", original_position, 0.3)
