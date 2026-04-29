extends Node2D

class_name Battlefield

# Simple tabletop simulator battlefield - renders cards with tap/untap by click
@onready var game_state: GameState = get_parent().get_node_or_null("GameState") as GameState

var card_visuals: Dictionary = {}  # card_id -> Node2D
var player_index: int = 0
var grid_cols: int = 8
var card_size: Vector2 = Vector2(64, 90)
var spacing: Vector2 = Vector2(80, 110)
var drop_zone: Area2D = null
var drop_zone_size: Vector2 = Vector2.ZERO
var drop_zone_rect: Rect2 = Rect2()
var hand_offset_from_bottom: int = 20
var drop_zone_distance_above_hand: int = 200

func _ready() -> void:
	name = "Battlefield"
	z_index = 10
	
	# Calculate position: 200px above hand
	var viewport_size = get_viewport().get_visible_rect().size
	var hand_y = viewport_size.y - hand_offset_from_bottom
	var battlefield_y = hand_y - drop_zone_distance_above_hand
	position = Vector2(0, hand_y*(-1) + 700)
	
	# Create drop zone for drag-and-drop detection
	_create_drop_zone()
	
	if game_state:
		if not game_state.player_zone_changed.is_connected(_on_player_zone_changed):
			game_state.player_zone_changed.connect(_on_player_zone_changed)

func _create_drop_zone() -> void:
	# Create visual drop zone with a semi-transparent background
	var visual_bg = ColorRect.new()
	visual_bg.name = "DropZoneVisual"
	visual_bg.color = Color(1.0, 0.302, 0.302, 0.118)
	visual_bg.z_index = 1
	visual_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Coverage: 8 columns x 4 rows (roughly), with some padding
	var zone_width = get_viewport().get_visible_rect().size.x
	var zone_height = get_viewport().get_visible_rect().size.y
	visual_bg.size = Vector2(zone_width, zone_height)
	drop_zone_size = visual_bg.size
	drop_zone_rect = Rect2(global_position, drop_zone_size)
	
	add_child(visual_bg)
	
	# Create invisible collision area for detection
	drop_zone = Area2D.new()
	drop_zone.name = "DropZone"
	drop_zone.collision_layer = 1
	drop_zone.collision_mask = 0
	add_child(drop_zone)
	
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(zone_width, zone_height)
	collision.shape = shape
	drop_zone.add_child(collision)

func is_point_inside_drop_zone(global_point: Vector2) -> bool:
	if drop_zone_size == Vector2.ZERO:
		return false

	if not drop_zone_rect.has_area():
		drop_zone_rect = Rect2(global_position, drop_zone_size)

	var query := PhysicsPointQueryParameters2D.new()
	query.position = global_point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 1

	var hits := get_world_2d().direct_space_state.intersect_point(query)
	for hit in hits:
		if hit.has("collider") and hit.collider == drop_zone:
			return true

	return false

func _on_player_zone_changed(p_index: int, zone_name: String) -> void:
	if p_index != player_index:
		return
	if zone_name == "battlefield":
		refresh_cards()

func refresh_cards() -> void:
	if game_state == null:
		return
	
	var cards = game_state.get_battlefield_cards(player_index)
	
	# Clear old visuals (but preserve drop_zone and its visual)
	for child in get_children():
		if child != drop_zone and child.name != "DropZoneVisual":
			child.queue_free()
	card_visuals.clear()
	
	# Create visual for each card
	for i in range(cards.size()):
		var card_id = cards[i]
		var is_tapped = game_state.is_card_tapped_on_battlefield(player_index, card_id)
		var card_display = create_card_visual(card_id, is_tapped, i)
		add_child(card_display)
		card_visuals[card_id] = card_display

func create_card_visual(card_id: String, is_tapped: bool, index: int) -> Node2D:
	var container = Node2D.new()
	container.name = "Card_%s" % card_id
	
	# Calculate grid position
	var col = index % grid_cols
	var row = index / grid_cols
	var pos = Vector2(col * spacing.x, row * spacing.y)
	container.position = pos
	
	# Card rect (placeholder)
	var card_rect = ColorRect.new()
	card_rect.size = card_size
	card_rect.color = Color(0.2, 0.5, 0.8, 1)
	
	# Label with card ID
	var label = Label.new()
	label.text = card_id
	label.add_theme_font_size_override("font_size", 8)
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -15
	label.offset_top = -10
	card_rect.add_child(label)
	
	# Tapped appearance (rotated 90 degrees)
	if is_tapped:
		card_rect.rotation = PI / 2
		card_rect.modulate = Color(0.169, 0.169, 0.169, 0.502)  # dimmed
	
	# Clickable area
	var area = Area2D.new()
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = card_size
	collision.shape = shape
	area.add_child(collision)
	area.input_event.connect(func(_viewport, event, _shape_idx):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_card_clicked(card_id)
	)
	
	container.add_child(card_rect)
	container.add_child(area)
	return container

func _on_card_clicked(card_id: String) -> void:
	if game_state == null:
		return
	game_state.toggle_tap_on_battlefield(player_index, card_id)
	refresh_cards()

func set_player_index(index: int) -> void:
	player_index = index
	refresh_cards()
