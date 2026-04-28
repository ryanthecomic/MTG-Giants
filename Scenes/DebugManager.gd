extends CanvasLayer

@onready var card_manager: Node = get_parent().get_node("CardManager")

var card_id_input: LineEdit
var draw_button: Button
var clear_button: Button
var status_label: Label

func _ready() -> void:
	create_debug_draw_ui()

func create_debug_draw_ui() -> void:
	var panel = PanelContainer.new()
	panel.name = "DrawPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 16
	panel.offset_top = 16
	panel.offset_right = 300
	panel.offset_bottom = 172
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	panel.add_child(vbox)

	var title_label = Label.new()
	title_label.text = "Draw card by ID"
	vbox.add_child(title_label)

	card_id_input = LineEdit.new()
	card_id_input.name = "CardIdInput"
	card_id_input.placeholder_text = "CR01"
	card_id_input.text = "CR01"
	card_id_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_id_input.text_submitted.connect(_on_card_id_submitted)
	vbox.add_child(card_id_input)

	draw_button = Button.new()
	draw_button.name = "DrawButton"
	draw_button.text = "Draw Card"
	draw_button.pressed.connect(_on_draw_button_pressed)
	vbox.add_child(draw_button)

	clear_button = Button.new()
	clear_button.name = "ClearButton"
	clear_button.text = "Delete All Cards"
	clear_button.pressed.connect(_on_clear_button_pressed)
	vbox.add_child(clear_button)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Press D, Draw Card, or Delete All Cards"
	vbox.add_child(status_label)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_D:
		draw_card_from_input()

func _on_draw_button_pressed() -> void:
	draw_card_from_input()

func _on_card_id_submitted(_text: String) -> void:
	draw_card_from_input()

func _on_clear_button_pressed() -> void:
	clear_all_cards()

func draw_card_from_input() -> void:
	if card_id_input == null or card_manager == null:
		return

	var card_id = card_id_input.text.strip_edges()
	if card_id == "":
		if status_label:
			status_label.text = "Enter a card ID first"
		return

	card_manager.draw_card(card_id)
	if status_label:
		status_label.text = "Drew: %s" % card_id

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
