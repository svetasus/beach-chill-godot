extends Control

@onready var item_list = $PanelContainer/VBoxContainer/ScrollContainer/ItemList
@export var slot_prefab: PackedScene

var current_data: Dictionary = {}
var current_tab: String = "Artifacts" # "Artifacts" or "Items"

func _ready():
	self.hide()

	var artifacts_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/ArtifactsTab")
	var items_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/ItemsTab")

	if artifacts_btn:
		artifacts_btn.pressed.connect(func(): set_tab("Artifacts"))
	if items_btn:
		items_btn.pressed.connect(func(): set_tab("Items"))

	update_tab_styles()

func update_tab_styles():
	var artifacts_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/ArtifactsTab")
	var items_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/ItemsTab")

	var panel = get_node_or_null("PanelContainer")
	if panel:
		panel.theme_type_variation = "WindowPanel"

	if artifacts_btn:
		if current_tab == "Artifacts":
			artifacts_btn.theme_type_variation = "ActiveTabBtn"
		else:
			artifacts_btn.theme_type_variation = "InactiveTabBtn"

	if items_btn:
		if current_tab == "Items":
			items_btn.theme_type_variation = "ActiveTabBtn"
		else:
			items_btn.theme_type_variation = "InactiveTabBtn"

func set_tab(tab_name: String):
	current_tab = tab_name
	update_tab_styles()
	refresh_ui(current_data)

func _get_all_files(path: String, extension: String) -> Array:
	var files = []
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if dir.current_is_dir() and not file_name.begins_with("."):
				files.append_array(_get_all_files(path + "/" + file_name, extension))
			else:
				if file_name.ends_with(extension):
					files.append(path + "/" + file_name)
			file_name = dir.get_next()
	return files

func refresh_ui(data: Dictionary):
	current_data = data

	if item_list == null:
		return

	# Clear the old list
	for child in item_list.get_children():
		child.queue_free()
	
	var active_data = {}
	if current_tab == "Artifacts" and data.has("artifacts"):
		active_data = data["artifacts"]
	elif current_tab == "Items" and data.has("items"):
		active_data = data["items"]

	var all_files = []
	if current_tab == "Artifacts":
		var recipes_res = load("res://resources/combiner_recipes/artifact_recipes_list.tres") as ArtifactRecipeList
		if recipes_res:
			for recipe in recipes_res.recipes:
				if recipe and recipe.result_item:
					all_files.append({"resource": recipe.result_item, "is_artifact": true})
	else:
		var item_paths = _get_all_files("res://resources/items", ".tres")
		for p in item_paths:
			var res = load(p) as ItemData
			if res and res.item_icon and (res.is_collectible or res.is_tool):
				all_files.append({"resource": res, "is_artifact": false})

	if all_files.is_empty():
		var empty_label = Label.new()
		if current_tab != "Artifacts":
			empty_label.text = "No artifacts. Craft an artifact to add it to the collection."
		else:
			empty_label.text = "No items available."

		empty_label.add_theme_font_size_override("font_size", 24)
		empty_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 1.0))
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		item_list.add_child(empty_label)
		return

	# Deduplicate all files by name to avoid issues
	var unique_files = []
	var seen_names = {}
	for file_data in all_files:
		var res_name = file_data["resource"].name
		if not seen_names.has(res_name):
			seen_names[res_name] = true
			unique_files.append(file_data)

	for file_data in unique_files:
		var item_res = file_data["resource"]
		var res_name = item_res.name

		var is_owned = active_data.has(res_name)
		var slot_data = null
		if is_owned:
			slot_data = active_data[res_name]

		var new_slot = slot_prefab.instantiate()
		item_list.add_child(new_slot)
		
		# 1. Set the Icon
		var icon_rect = new_slot.get_node("Icon")
		if item_res.item_icon:
			icon_rect.texture = item_res.item_icon
			if not is_owned:
				icon_rect.modulate = Color(0, 0, 0, 0.776)
		
		# 2. Set the Count Label
		var count_label = new_slot.get_node("Count")
		if is_owned:
			count_label.text = "x" + str(slot_data["count"])
		count_label.hide()
		
		# 3. Add a tooltip & Name
		var name_label = new_slot.get_node_or_null("Name")
		if not is_owned:
			new_slot.tooltip_text = "???"
			if name_label:
				name_label.text = "???"
		else:
			new_slot.tooltip_text = res_name
			if name_label:
				if "display_name" in item_res:
					name_label.text = item_res.display_name
				else:
					name_label.text = res_name
