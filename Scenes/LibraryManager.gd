extends CanvasLayer

class_name LibraryManager

const CARD_SCENE := preload("res://Scenes/Card.tscn")
const CARD_BACK_TEXTURE := preload("res://Images/sleeve_weathered_cardback.png")
const MAX_STACK_PREVIEW := 7

@onready var card_manager: Node = get_parent().get_node_or_null("CardManager")

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
	"CG33"
]

var library_cards: Array[String] = []
var top_card_revealed := false
var library_panel: PanelContainer
var count_label: Label
var status_label: Label
var preview_container: Node2D
var preview_children: Array = []

func _ready() -> void:
	create_library_debug_ui()
	reset_library()
	update_preview_card()

func _process(_delta: float) -> void:
	update_preview_position()

func create_library_debug_ui() -> void:
	library_panel = PanelContainer.new()
	library_panel.name = "LibraryPanel"
	library_panel.anchor_left = 0.0
	library_panel.anchor_right = 0.0
	library_panel.anchor_top = 0.0
	library_panel.anchor_bottom = 0.0
	library_panel.offset_left = 16
	library_panel.offset_top = 16
	library_panel.offset_right = 330
	library_panel.offset_bottom = 240
	add_child(library_panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	library_panel.add_child(vbox)

	var title_label = Label.new()
	title_label.text = "Library Debug"
	vbox.add_child(title_label)

	count_label = Label.new()
	count_label.name = "CountLabel"
	vbox.add_child(count_label)

	var draw_button = Button.new()
	draw_button.name = "DrawButton"
	draw_button.text = "Comprar do Baralho"
	draw_button.pressed.connect(_on_draw_button_pressed)
	vbox.add_child(draw_button)

	var shuffle_button = Button.new()
	shuffle_button.name = "ShuffleButton"
	shuffle_button.text = "Embaralhar"
	shuffle_button.pressed.connect(_on_shuffle_button_pressed)
	vbox.add_child(shuffle_button)

	var reveal_button = Button.new()
	reveal_button.name = "RevealButton"
	reveal_button.text = "Revelar Topo"
	reveal_button.pressed.connect(_on_reveal_button_pressed)
	vbox.add_child(reveal_button)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Library ready"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(status_label)

func reset_library() -> void:
	library_cards = starting_deck_ids.duplicate()
	top_card_revealed = false
	update_status("Deck carregado com %d cartas" % library_cards.size())
	update_count_label()

func draw_from_library() -> void:
	if library_cards.is_empty():
		update_status("Library vazia")
		return

	var card_id: String = library_cards.pop_back()
	if card_manager and card_manager.has_method("draw_card_to_hand"):
		card_manager.draw_card_to_hand(card_id)

	top_card_revealed = false
	update_status("Comprou: %s" % card_id)
	update_count_label()
	update_preview_card()

func shuffle_library() -> void:
	library_cards.shuffle()
	top_card_revealed = false
	update_status("Deck embaralhado")
	update_preview_card()

func reveal_top_card() -> void:
	if library_cards.is_empty():
		update_status("Library vazia")
		return

	top_card_revealed = true
	update_status("Topo revelado: %s" % library_cards.back())
	update_preview_card()

func update_count_label() -> void:
	if count_label:
		count_label.text = "Cartas no deck: %d" % library_cards.size()

func update_status(message: String) -> void:
	if status_label:
		status_label.text = message

func ensure_preview_card() -> void:
	if preview_container != null:
		return

	preview_container = Node2D.new()
	preview_container.name = "LibraryPreviewStack"
	preview_container.z_index = 20
	add_child(preview_container)

	preview_children = []
	for i in range(MAX_STACK_PREVIEW):
		var card_instance := CARD_SCENE.instantiate()
		card_instance.name = "PreviewCard_%d" % i
		card_instance.z_index = i
		preview_container.add_child(card_instance)

		var area := card_instance.get_node_or_null("Area2D") as Area2D
		if area:
			area.collision_layer = 0
			area.collision_mask = 0
			area.monitoring = false
			area.monitorable = false

		preview_children.append(card_instance)

	# hide initially
	preview_container.visible = false

func update_preview_position() -> void:
	if preview_container == null:
		return

	var viewport_size = get_viewport().get_visible_rect().size
	preview_container.global_position = Vector2(190, viewport_size.y - 350)

func update_preview_card() -> void:
	if library_cards.is_empty():
		if preview_container:
			preview_container.visible = false
		return

	ensure_preview_card()
	preview_container.visible = true

	var stack_count := get_stack_count(library_cards.size())
	var viewport_size = get_viewport().get_visible_rect().size
	var base_pos := Vector2(190, viewport_size.y - 350)

	# configure each preview child
	for i in range(MAX_STACK_PREVIEW):
		var card_node: Node = preview_children[i]
		if i >= stack_count:
			card_node.visible = false
			continue

		card_node.visible = true
		# position and rotation to give a skewed stacked look
		var idx_from_bottom := i
		var stagger_x := idx_from_bottom * 6
		var stagger_y := -idx_from_bottom * 4
		var degrees := 0.0
		if stack_count > 1:
			degrees = lerp(-8.0, 8.0, float(idx_from_bottom) / float(stack_count - 1))

		card_node.global_position = base_pos + Vector2(stagger_x, stagger_y)
		card_node.rotation_degrees = degrees
		card_node.scale = Vector2(0.98, 0.98)

		var card_image: Sprite2D = card_node.get_node_or_null("CardImage") as Sprite2D
		if card_image == null:
			continue

		# topmost in visual stack is the last visible (index stack_count - 1)
		if idx_from_bottom == stack_count - 1:
			var top_card_id: String = library_cards.back()
			if top_card_revealed and card_node.has_method("load_card_image"):
				card_node.call("load_card_image", top_card_id)
			else:
				card_image.texture = CARD_BACK_TEXTURE
		else:
			card_image.texture = CARD_BACK_TEXTURE

	update_preview_position()

func get_stack_count(cards_count: int) -> int:
	if cards_count >= 60:
		return 7
	elif cards_count >= 29:
		return 6
	elif cards_count >= 21:
		return 5
	elif cards_count >= 16:
		return 4
	elif cards_count >= 10:
		return 3
	elif cards_count >= 2:
		return 2
	elif cards_count == 1:
		return 1
	return 0

func _on_draw_button_pressed() -> void:
	draw_from_library()

func _on_shuffle_button_pressed() -> void:
	shuffle_library()

func _on_reveal_button_pressed() -> void:
	reveal_top_card()
