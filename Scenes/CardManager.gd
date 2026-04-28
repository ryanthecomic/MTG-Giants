extends Node2D

const COLLISION_MASK_CARD = 1

var screen_size
var card_being_dragged
var max_tilt_deg := 12.0
var tilt_smooth := 10.0
var hover_max_offset := 160.0
var max_scale_tilt := 0.08
var move_smooth := 14.0
var grab_scale_factor := 1.08

func _ready() -> void:
	screen_size = get_viewport_rect().size

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		# keep grab offset so the click point stays under the cursor
		var grab_offset = Vector2()
		if card_being_dragged.has_meta("grab_offset"):
			grab_offset = card_being_dragged.get_meta("grab_offset")
		var desired_pos = mouse_pos + grab_offset
		# smooth movement toward the mouse
		card_being_dragged.global_position = card_being_dragged.global_position.lerp(desired_pos, clamp(move_smooth * delta, 0, 1))

		# tilt/pinch intensity depends on how far the card still is from the mouse
		var to_mouse = mouse_pos - card_being_dragged.global_position
		var dist = to_mouse.length()
		var intensity = clamp(dist / hover_max_offset, 0.0, 1.0)
		var dir = 0.0
		if hover_max_offset != 0:
			dir = clamp(to_mouse.x / hover_max_offset, -1.0, 1.0)

		var target_rotation = -dir * deg_to_rad(max_tilt_deg) * intensity
		card_being_dragged.rotation = lerp_angle(card_being_dragged.rotation, target_rotation, clamp(tilt_smooth * delta, 0, 1))

		# apply pinch/scale with grabbed cards slightly larger
		var base_scale = card_being_dragged.get_meta("base_scale") if card_being_dragged.has_meta("base_scale") else card_being_dragged.scale
		var s_x = base_scale.x + abs(dir) * max_scale_tilt * intensity
		var s_y = base_scale.y - abs(dir) * max_scale_tilt * intensity
		var target_scale = Vector2(s_x, s_y)
		card_being_dragged.scale = card_being_dragged.scale.lerp(target_scale, clamp(tilt_smooth * delta, 0, 1))

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var card = raycast_check_for_card()
			if card:
				card_being_dragged = card
				# store original state and grab offset so the card doesn't jump
				var mouse_pos = get_global_mouse_position()
				var grab = card.global_position - mouse_pos
				card.set_meta("grab_offset", grab)
				card.set_meta("orig_scale", card.scale)
				# make grabbed card slightly larger (base scale while grabbed)
				card.set_meta("base_scale", card.scale * grab_scale_factor)
				card.scale = card.get_meta("base_scale")
				card.set_meta("orig_rotation", card.rotation)
				card.set_meta("orig_z", card.z_index)
				card.z_index = 100
		else:
			# restore original transform when released
			if card_being_dragged:
				if card_being_dragged.has_meta("orig_scale"):
					card_being_dragged.scale = card_being_dragged.get_meta("orig_scale")
				if card_being_dragged.has_meta("orig_rotation"):
					card_being_dragged.rotation = card_being_dragged.get_meta("orig_rotation")
				if card_being_dragged.has_meta("orig_z"):
					card_being_dragged.z_index = card_being_dragged.get_meta("orig_z")
				card_being_dragged.set_meta("grab_offset", null)
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
