extends Node2D

var card_id: String = ""

func _ready() -> void:
	if card_id != "":
		load_card_image(card_id)

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
