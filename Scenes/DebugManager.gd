extends CanvasLayer

@onready var card_manager: Node = get_parent().get_node("CardManager")
@onready var player_hand: Hand = get_parent().get_node("Hand")
@onready var game_state: GameState = get_parent().get_node_or_null("GameState") as GameState

var debug_panel: PanelContainer
var root_vbox: VBoxContainer
var summary_label: Label
var hotkeys_label: Label
var card_id_input: LineEdit
var draw_button: Button
var clear_button: Button
var clear_hand_button: Button
var shuffle_button: Button
var pass_priority_button: Button
var next_phase_button: Button
var end_turn_button: Button
var resolve_stack_button: Button
var plus_life_button: Button
var minus_life_button: Button
var toggle_button: Button
var undo_button: Button
var status_label: Label
var turn_label: Label
var priority_label: Label
var stack_label: Label
var actions_visible := true

func _ready() -> void:
	create_debug_draw_ui()

func create_debug_draw_ui() -> void:
	debug_panel = PanelContainer.new()
	debug_panel.name = "DebugPanel"
	debug_panel.anchor_left = 0.0
	debug_panel.anchor_top = 0.0
	debug_panel.anchor_right = 0.0
	debug_panel.anchor_bottom = 0.0

	# clamp width to viewport so panel doesn't go off-screen
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_width: int = min(420, max(240, int(vp_size.x) - 40))
	# let Control size be driven by its children; avoid setting rect properties
	# directly to remain compatible across Godot versions
	add_child(debug_panel)

	# ensure debug panel is rendered above other UI
	# set this CanvasLayer to a high layer and raise the panel's z-index
	if self is CanvasLayer:
		self.layer = 100
	debug_panel.z_index = 100

	root_vbox = VBoxContainer.new()
	root_vbox.name = "RootVBox"
	root_vbox.add_theme_constant_override("separation", 8)
	debug_panel.add_child(root_vbox)

	var title_row = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	root_vbox.add_child(title_row)

	var title_label = Label.new()
	title_label.text = "Debug Arena"
	title_label.add_theme_font_size_override("font_size", 18)
	title_row.add_child(title_label)

	toggle_button = Button.new()
	toggle_button.name = "ToggleButton"
	toggle_button.text = "Hide (F1)"
	toggle_button.pressed.connect(_on_toggle_button_pressed)
	title_row.add_child(toggle_button)

	summary_label = Label.new()
	summary_label.name = "SummaryLabel"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.text = "Turn, priority and stack state"
	root_vbox.add_child(summary_label)

	hotkeys_label = Label.new()
	hotkeys_label.name = "HotkeysLabel"
	hotkeys_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hotkeys_label.text = "F1: hide/show | Space: priority | N: next phase | E: end turn | R: resolve stack | D: draw | S: shuffle | +/-: life"
	root_vbox.add_child(hotkeys_label)

	root_vbox.add_child(create_separator())

	var draw_section = create_section("Library / Draw")
	root_vbox.add_child(draw_section)

	var draw_row = HBoxContainer.new()
	draw_row.add_theme_constant_override("separation", 8)
	draw_section.add_child(draw_row)

	card_id_input = LineEdit.new()
	card_id_input.name = "CardIdInput"
	card_id_input.placeholder_text = "CR01"
	card_id_input.text = "CR01"
	card_id_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_id_input.text_submitted.connect(_on_card_id_submitted)
	draw_row.add_child(card_id_input)

	draw_button = Button.new()
	draw_button.name = "DrawButton"
	draw_button.text = "Draw (D)"
	draw_button.pressed.connect(_on_draw_button_pressed)
	draw_row.add_child(draw_button)

	shuffle_button = Button.new()
	shuffle_button.name = "ShuffleButton"
	shuffle_button.text = "Shuffle (S)"
	shuffle_button.pressed.connect(_on_shuffle_button_pressed)
	draw_section.add_child(shuffle_button)

	var control_section = create_section("Match Controls")
	root_vbox.add_child(control_section)

	var control_row = HBoxContainer.new()
	control_row.add_theme_constant_override("separation", 8)
	control_section.add_child(control_row)

	pass_priority_button = Button.new()
	pass_priority_button.name = "PassPriorityButton"
	pass_priority_button.text = "Pass Priority (Space)"
	pass_priority_button.pressed.connect(_on_pass_priority_pressed)
	control_row.add_child(pass_priority_button)

	next_phase_button = Button.new()
	next_phase_button.name = "NextPhaseButton"
	next_phase_button.text = "Next Phase (N)"
	next_phase_button.pressed.connect(_on_next_phase_pressed)
	control_row.add_child(next_phase_button)

	end_turn_button = Button.new()
	end_turn_button.name = "EndTurnButton"
	end_turn_button.text = "End Turn (E)"
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	control_row.add_child(end_turn_button)

	resolve_stack_button = Button.new()
	resolve_stack_button.name = "ResolveStackButton"
	resolve_stack_button.text = "Resolve Stack (R)"
	resolve_stack_button.pressed.connect(_on_resolve_stack_pressed)
	control_row.add_child(resolve_stack_button)

	undo_button = Button.new()
	undo_button.name = "UndoButton"
	undo_button.text = "Undo (Z)"
	undo_button.pressed.connect(_on_undo_pressed)
	control_row.add_child(undo_button)

	var life_section = create_section("Life / Hand")
	root_vbox.add_child(life_section)

	var life_row = HBoxContainer.new()
	life_row.add_theme_constant_override("separation", 8)
	life_section.add_child(life_row)

	plus_life_button = Button.new()
	plus_life_button.name = "PlusLifeButton"
	plus_life_button.text = "+1 Life"
	plus_life_button.pressed.connect(_on_plus_life_pressed)
	life_row.add_child(plus_life_button)

	minus_life_button = Button.new()
	minus_life_button.name = "MinusLifeButton"
	minus_life_button.text = "-1 Life"
	minus_life_button.pressed.connect(_on_minus_life_pressed)
	life_row.add_child(minus_life_button)

	clear_button = Button.new()
	clear_button.name = "ClearButton"
	clear_button.text = "Delete Board Nodes"
	clear_button.pressed.connect(_on_clear_button_pressed)
	life_section.add_child(clear_button)

	clear_hand_button = Button.new()
	clear_hand_button.name = "ClearHandButton"
	clear_hand_button.text = "Clear Hand"
	clear_hand_button.pressed.connect(_on_clear_hand_button_pressed)
	life_section.add_child(clear_hand_button)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Ready"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(status_label)

	turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.text = "Turn: -"
	root_vbox.add_child(turn_label)

	priority_label = Label.new()
	priority_label.name = "PriorityLabel"
	priority_label.text = "Priority: -"
	root_vbox.add_child(priority_label)

	stack_label = Label.new()
	stack_label.name = "StackLabel"
	stack_label.text = "Stack: 0"
	root_vbox.add_child(stack_label)

	bind_game_state()
	refresh_game_state_labels()
	refresh_visibility()

func create_section(title_text: String) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var header = Label.new()
	header.text = title_text
	header.add_theme_font_size_override("font_size", 14)
	section.add_child(header)

	return section

func create_separator() -> HSeparator:
	return HSeparator.new()

func _input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_F1:
			_toggle_visibility()
		KEY_APOSTROPHE:
			draw_card_from_input()
		KEY_D:
			draw_card_from_input()
		KEY_S:
			shuffle_library()
		KEY_SPACE:
			pass_priority()
		KEY_N:
			next_phase()
		KEY_E:
			end_turn()
		KEY_R:
			resolve_stack()
		KEY_EQUAL:
			adjust_life(1)
		KEY_MINUS:
			adjust_life(-1)
		KEY_Z:
			# undo last action
			if game_state:
				var ok: bool = game_state.undo_last_action()
				if ok:
					set_status("Undo executed")
				else:
					set_status("Nothing to undo")

func _on_draw_button_pressed() -> void:
	draw_card_from_input()

func _on_shuffle_button_pressed() -> void:
	shuffle_library()

func _on_pass_priority_pressed() -> void:
	pass_priority()

func _on_next_phase_pressed() -> void:
	next_phase()

func _on_end_turn_pressed() -> void:
	end_turn()

func _on_resolve_stack_pressed() -> void:
	resolve_stack()

func _on_plus_life_pressed() -> void:
	adjust_life(1)

func _on_minus_life_pressed() -> void:
	adjust_life(-1)

func _on_toggle_button_pressed() -> void:
	_toggle_visibility()

func _on_undo_pressed() -> void:
	if game_state == null:
		set_status("GameState not found")
		return

	var ok: bool = game_state.undo_last_action()
	if ok:
		set_status("Undo executed")
	else:
		set_status("Nothing to undo")

func _on_card_id_submitted(_text: String) -> void:
	draw_card_from_input()

func _on_clear_button_pressed() -> void:
	clear_all_cards()

func _on_clear_hand_button_pressed() -> void:
	clear_hand()

func draw_card_from_input() -> void:
	if card_id_input == null or card_manager == null:
		return

	var card_id = card_id_input.text.strip_edges()
	if card_id == "":
		if status_label:
			status_label.text = "Enter a card ID first"
		return

	card_manager.draw_card_to_hand(card_id)
	if status_label:
		status_label.text = "Drew: %s" % card_id

func shuffle_library() -> void:
	if game_state == null:
		set_status("GameState not found")
		return

	game_state.shuffle_library()
	set_status("Deck shuffled")

func pass_priority() -> void:
	if game_state == null:
		set_status("GameState not found")
		return

	if not game_state.pass_priority(game_state.local_player_index):
		set_status("Cannot pass priority right now")

func next_phase() -> void:
	if game_state == null:
		set_status("GameState not found")
		return

	game_state.advance_phase()
	set_status("Advanced phase")

func end_turn() -> void:
	if game_state == null:
		set_status("GameState not found")
		return

	game_state.end_turn()
	set_status("Ended turn")

func resolve_stack() -> void:
	if game_state == null:
		set_status("GameState not found")
		return

	var resolved_item: Dictionary = game_state.resolve_top_of_stack()
	if resolved_item.is_empty():
		set_status("Stack empty")
		return

	set_status("Resolved: %s" % game_state.get_stack_entry_label(resolved_item))

func adjust_life(amount: int) -> void:
	if game_state == null:
		set_status("GameState not found")
		return

	game_state.change_player_life(game_state.local_player_index, amount)
	set_status("Life %+d" % amount)

func clear_all_cards() -> void:
	if card_manager == null:
		return

	var removed_count := 0
	for child in card_manager.get_children():
		if child is Node:
			child.queue_free()
			removed_count += 1

	if status_label:
		status_label.text = "Deleted %d card(s)" % removed_count

func clear_hand() -> void:
	if player_hand == null:
		return

	var removed_count = player_hand.cards.size()
	for card in player_hand.cards.duplicate():
		card.queue_free()
	player_hand.cards.clear()

	if status_label:
		status_label.text = "Cleared %d card(s) from hand" % removed_count

func set_status(message: String) -> void:
	if status_label:
		status_label.text = message

func _toggle_visibility() -> void:
	actions_visible = not actions_visible
	refresh_visibility()

func refresh_visibility() -> void:
	if debug_panel == null:
		return

	if root_vbox:
		for child in root_vbox.get_children():
			if child == status_label or child == turn_label or child == priority_label or child == stack_label:
				child.visible = true
			elif child == summary_label or child == hotkeys_label:
				child.visible = true
			else:
				child.visible = actions_visible

	if toggle_button:
		toggle_button.text = "Show (F1)" if not actions_visible else "Hide (F1)"

func bind_game_state() -> void:
	if game_state == null:
		return

	if not game_state.game_state_changed.is_connected(_on_game_state_changed):
		game_state.game_state_changed.connect(_on_game_state_changed)
	if not game_state.turn_started.is_connected(_on_turn_state_changed):
		game_state.turn_started.connect(_on_turn_state_changed)
	if not game_state.turn_ended.is_connected(_on_turn_state_changed):
		game_state.turn_ended.connect(_on_turn_state_changed)
	if not game_state.phase_changed.is_connected(_on_phase_changed):
		game_state.phase_changed.connect(_on_phase_changed)
	if not game_state.priority_changed.is_connected(_on_priority_changed):
		game_state.priority_changed.connect(_on_priority_changed)
	if not game_state.stack_changed.is_connected(_on_stack_changed):
		game_state.stack_changed.connect(_on_stack_changed)
	if not game_state.action_logged.is_connected(_on_action_logged):
		game_state.action_logged.connect(_on_action_logged)

	# ensure panel updates when window resizes
	# connect once to viewport size changes so panel width stays clamped
	var vp := get_viewport()
	if vp and not vp.is_connected("size_changed", Callable(self, "_on_viewport_resized")):
		vp.connect("size_changed", Callable(self, "_on_viewport_resized"))

func refresh_game_state_labels() -> void:
	if game_state == null:
		return

	var summary: Dictionary = game_state.get_state_summary()
	if turn_label:
		turn_label.text = "Turn: %d | Phase: %s | Active: P%d" % [summary["turn_number"], summary["phase"], summary["active_player_index"]]
	if priority_label:
		priority_label.text = "Priority: P%d | Passes: %d" % [summary["priority_player_index"], summary["priority_pass_count"]]
	if stack_label:
		stack_label.text = "Stack: %d" % summary["stack_size"]

func _on_game_state_changed() -> void:
	refresh_game_state_labels()

func _on_turn_state_changed(_active_player_index: int, _turn_number: int) -> void:
	refresh_game_state_labels()

func _on_phase_changed(_active_player_index: int, _phase_name: String) -> void:
	refresh_game_state_labels()

func _on_priority_changed(_player_index: int) -> void:
	refresh_game_state_labels()

func _on_stack_changed(_stack_size: int) -> void:
	refresh_game_state_labels()

func _on_action_logged(message: String) -> void:
	set_status(message)

func _on_viewport_resized() -> void:
	# no-op resize handler to avoid setting properties that change across Godot versions
	# keep function for future safe resizing logic if needed
	return
