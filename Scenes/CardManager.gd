extends Node2D

const COLLISION_MASK_CARD = 1

var screen_size
var card_being_dragged
var card_being_reordered_in_hand: Node2D = null  # Track hand reordering
var player_hand: Hand  # Reference to the player's hand
var prev_mouse_pos := Vector2.ZERO
var max_tilt_deg := 30.0
var tilt_smooth := 10.0
var hover_max_offset := 120.0
var max_scale_tilt := 0.3
var move_smooth := 50.0
var grab_scale_factor := 1.5
var corner_radius_pixels := 15
var corner_edge_softness := 1.0
var hand_reorder_threshold := 150.0  # pixels to stay near hand before entering reorder mode

func _ready() -> void:
	screen_size = get_viewport_rect().size
	# Find and reference the player's hand in the scene
	player_hand = get_parent().get_node_or_null("Hand") as Hand

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Check if hand reordering card is being dragged too far away
	if card_being_reordered_in_hand:
		var mouse_pos = get_global_mouse_position()
		if player_hand.is_card_dragged_away_from_hand(mouse_pos):
			# Convert to board drag
			player_hand.abort_reorder()
			card_being_reordered_in_hand = null
			# Now apply board drag effects
			card_being_dragged.set_meta("base_scale", card_being_dragged.scale * grab_scale_factor)
			card_being_dragged.z_index = 100
	
	# Handle board drag
	if card_being_dragged and not card_being_reordered_in_hand:
		var mouse_pos = get_global_mouse_position()
		# card center always lines up with mouse cursor
		var desired_pos = mouse_pos
		# smooth movement toward the mouse
		card_being_dragged.global_position = card_being_dragged.global_position.lerp(desired_pos, clamp(move_smooth * delta, 0, 1))

		# calculate mouse velocity for tilt direction
		var mouse_velocity = mouse_pos - prev_mouse_pos
		var velocity_magnitude = mouse_velocity.length()
		var intensity = clamp(velocity_magnitude / hover_max_offset, 0.0, 1.0)
		var dir = 0.0
		if velocity_magnitude > 0.1:
			dir = clamp(mouse_velocity.x / hover_max_offset, -1.0, 1.0)
		prev_mouse_pos = mouse_pos

		var target_rotation = -dir * deg_to_rad(max_tilt_deg) * intensity
		card_being_dragged.rotation = lerp_angle(card_being_dragged.rotation, target_rotation, clamp(tilt_smooth * delta, 0, 1))

		# apply a uniform scale so the card keeps its aspect ratio
		var base_scale = card_being_dragged.get_meta("base_scale") if card_being_dragged.has_meta("base_scale") else card_being_dragged.scale
		var scale_boost = 1.0 + abs(dir) * max_scale_tilt * intensity
		var target_scale = base_scale * scale_boost
		card_being_dragged.scale = card_being_dragged.scale.lerp(target_scale, clamp(tilt_smooth * delta, 0, 1))

		var shadow = card_being_dragged.get_node_or_null("ShadowImage")
		if shadow:
			shadow.visible = true
			shadow.global_position = card_being_dragged.global_position + Vector2(80 + velocity_magnitude * 0.03, 120 + velocity_magnitude * 0.04)
			shadow.scale = card_being_dragged.scale * 0.96
			shadow.rotation = card_being_dragged.rotation * 0.7
			var shadow_alpha = clamp(0.12 + intensity * 0.08, 0.0, 0.22)
			shadow.modulate = Color(0, 0, 0, shadow_alpha)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var card = raycast_check_for_card()
			if card:
				card_being_dragged = card
				prev_mouse_pos = get_global_mouse_position()
				
				# Check if card is in hand
				if player_hand and card.get_parent() == player_hand:
					card_being_reordered_in_hand = card
					player_hand.start_reorder(card)
					# Don't apply board drag effects
					return
				
				# Board drag setup
				# store original state so we can restore on release
				card.set_meta("orig_scale", card.scale)
				# make grabbed card slightly larger (base scale while grabbed)
				card.set_meta("base_scale", card.scale * grab_scale_factor)
				card.scale = card.get_meta("base_scale")
				card.set_meta("orig_rotation", card.rotation)
				card.set_meta("orig_z", card.z_index)
				card.z_index = 100
		else:
			# Handle release
			if card_being_reordered_in_hand:
				# Only finish reorder if still in hand mode
				player_hand.finish_reorder()
				card_being_reordered_in_hand = null
				card_being_dragged = null
				prev_mouse_pos = Vector2.ZERO
			elif card_being_dragged:
				# restore original transform when released (board drag)
				if card_being_dragged.has_meta("orig_scale"):
					card_being_dragged.scale = card_being_dragged.get_meta("orig_scale")
				if card_being_dragged.has_meta("orig_rotation"):
					card_being_dragged.rotation = card_being_dragged.get_meta("orig_rotation")
				if card_being_dragged.has_meta("orig_z"):
					card_being_dragged.z_index = card_being_dragged.get_meta("orig_z")
				var shadow = card_being_dragged.get_node_or_null("ShadowImage")
				if shadow:
					shadow.visible = false
				prev_mouse_pos = Vector2.ZERO
				card_being_dragged = null
# Called when the node enters the scene tree for the first time.

func raycast_check_for_card():
	var space_state = get_viewport().world_2d.direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		return result[0].collider.get_parent()
	return null

func draw_card(id: String, pos: Vector2 = Vector2(400, 200)) -> Node2D:
	# Load and instantiate the card scene
	var card_scene = load("res://Scenes/card.tscn")
	var card = card_scene.instantiate()
	
	# Add to the scene tree first
	add_child(card)
	
	# Then load the card image and set position
	var card_image = card.get_node_or_null("CardImage")
	var shadow_image = card.get_node_or_null("ShadowImage")
	if card_image:
		var texture = get_card_texture(id)
		if texture:
			card_image.texture = texture
			if shadow_image:
				shadow_image.texture = texture
				shadow_image.visible = false
	card.global_position = pos
	var shadow = card.get_node_or_null("ShadowImage")
	if shadow:
		shadow.visible = false
	
	return card

func draw_card_to_hand(id: String) -> Node2D:
	"""Draw a card directly to the player's hand"""
	if player_hand == null:
		push_error("Player hand not found!")
		return null
	
	# Create the card
	var card = draw_card(id, Vector2.ZERO)  # Position will be handled by hand layout
	
	# Move it to the hand's management
	player_hand.add_card(card)
	
	return card

func get_card_texture(id: String) -> Texture2D:
	var card_arts_path = "res://Card Arts/Playtest Card Arts/"
	var dir = DirAccess.open(card_arts_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.begins_with(id) and file_name.ends_with(".png"):
				var texture = load(card_arts_path + file_name)
				return prepare_card_texture(texture)
			file_name = dir.get_next()
	return null

func prepare_card_texture(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null

	var image = texture.get_image()
	if image == null:
		return texture

	image.convert(Image.FORMAT_RGBA8)
	var width = image.get_width()
	var height = image.get_height()
	var radius = min(float(corner_radius_pixels), min(float(width), float(height)) * 0.25)
	radius = max(radius, 0.0)

	for y in range(height):
		for x in range(width):
			var alpha_multiplier = get_rounded_corner_alpha(x, y, width, height, radius, corner_edge_softness)
			if alpha_multiplier < 1.0:
				var pixel = image.get_pixel(x, y)
				pixel.a *= alpha_multiplier
				image.set_pixel(x, y, pixel)

	return ImageTexture.create_from_image(image)

func get_rounded_corner_alpha(x: int, y: int, width: int, height: int, radius: float, softness: float) -> float:
	if radius <= 0.0:
		return 1.0

	var inner_left = radius
	var inner_top = radius
	var inner_right = float(width - 1) - radius
	var inner_bottom = float(height - 1) - radius

	if float(x) >= inner_left and float(x) <= inner_right:
		if float(y) >= inner_top and float(y) <= inner_bottom:
			return 1.0

	var corner_center = Vector2()
	if x < radius and y < radius:
		corner_center = Vector2(radius, radius)
	elif x >= width - radius and y < radius:
		corner_center = Vector2(float(width - 1) - radius, radius)
	elif x < radius and y >= height - radius:
		corner_center = Vector2(radius, float(height - 1) - radius)
	elif x >= width - radius and y >= height - radius:
		corner_center = Vector2(float(width - 1) - radius, float(height - 1) - radius)
	else:
		return 1.0

	var distance = corner_center.distance_to(Vector2(x, y))
	if distance <= radius - softness:
		return 1.0
	if distance >= radius:
		return 0.0
	return clamp((radius - distance) / max(softness, 0.001), 0.0, 1.0)
