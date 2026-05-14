extends Control

@onready var item_list = $PanelContainer/VBoxContainer/ScrollContainer/ItemList
@export var slot_prefab: PackedScene

var current_data: Dictionary = {}
var current_tab: String = "Artifacts" # "Artifacts" or "Items"

var active_style: StyleBoxFlat
var inactive_style: StyleBoxFlat
var window_style: StyleBoxFlat

func _ready():
	self.hide()

	_setup_styles()

	var artifacts_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/ArtifactsTab")
	var items_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/ItemsTab")

	if artifacts_btn:
		artifacts_btn.pressed.connect(func(): set_tab("Artifacts"))
	if items_btn:
		items_btn.pressed.connect(func(): set_tab("Items"))

	update_tab_styles()

func _setup_styles():
	var light_grey = Color(0.8, 0.8, 0.8, 1.0)
	var dark_grey = Color(0.5, 0.5, 0.5, 1.0)
	var text_color = Color(0.1, 0.1, 0.1, 1.0)
	var inactive_text_color = Color(0.9, 0.9, 0.9, 1.0)

	window_style = StyleBoxFlat.new()
	window_style.bg_color = light_grey
	window_style.set_corner_radius_all(8)
	window_style.content_margin_left = 20
	window_style.content_margin_right = 20
	window_style.content_margin_top = 20
	window_style.content_margin_bottom = 20

	var panel = get_node_or_null("PanelContainer")
	if panel:
		panel.add_theme_stylebox_override("panel", window_style)

	active_style = StyleBoxFlat.new()
	active_style.bg_color = light_grey
	active_style.set_corner_radius_all(8)
	# Make it visually connect to the panel container below it
	active_style.corner_radius_bottom_left = 0
	active_style.corner_radius_bottom_right = 0
	active_style.content_margin_left = 30
	active_style.content_margin_right = 30
	active_style.content_margin_top = 15
	active_style.content_margin_bottom = 15

	inactive_style = StyleBoxFlat.new()
	inactive_style.bg_color = dark_grey
	inactive_style.set_corner_radius_all(8)
	inactive_style.content_margin_left = 30
	inactive_style.content_margin_right = 30
	inactive_style.content_margin_top = 15
	inactive_style.content_margin_bottom = 15

func update_tab_styles():
	var artifacts_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/ArtifactsTab")
	var items_btn = get_node_or_null("PanelContainer/VBoxContainer/TabContainer/ItemsTab")

	var text_color = Color(0.1, 0.1, 0.1, 1.0)
	var inactive_text_color = Color(0.9, 0.9, 0.9, 1.0)

	if artifacts_btn:
		artifacts_btn.add_theme_font_size_override("font_size", 32)
		if current_tab == "Artifacts":
			artifacts_btn.add_theme_stylebox_override("normal", active_style)
			artifacts_btn.add_theme_stylebox_override("hover", active_style)
			artifacts_btn.add_theme_stylebox_override("pressed", active_style)
			artifacts_btn.add_theme_color_override("font_color", text_color)
			artifacts_btn.add_theme_color_override("font_hover_color", text_color)
			artifacts_btn.add_theme_color_override("font_pressed_color", text_color)
		else:
			artifacts_btn.add_theme_stylebox_override("normal", inactive_style)
			artifacts_btn.add_theme_stylebox_override("hover", inactive_style)
			artifacts_btn.add_theme_stylebox_override("pressed", inactive_style)
			artifacts_btn.add_theme_color_override("font_color", inactive_text_color)
			artifacts_btn.add_theme_color_override("font_hover_color", inactive_text_color)
			artifacts_btn.add_theme_color_override("font_pressed_color", inactive_text_color)

	if items_btn:
		items_btn.add_theme_font_size_override("font_size", 32)
		if current_tab == "Items":
			items_btn.add_theme_stylebox_override("normal", active_style)
			items_btn.add_theme_stylebox_override("hover", active_style)
			items_btn.add_theme_stylebox_override("pressed", active_style)
			items_btn.add_theme_color_override("font_color", text_color)
			items_btn.add_theme_color_override("font_hover_color", text_color)
			items_btn.add_theme_color_override("font_pressed_color", text_color)
		else:
			items_btn.add_theme_stylebox_override("normal", inactive_style)
			items_btn.add_theme_stylebox_override("hover", inactive_style)
			items_btn.add_theme_stylebox_override("pressed", inactive_style)
			items_btn.add_theme_color_override("font_color", inactive_text_color)
			items_btn.add_theme_color_override("font_hover_color", inactive_text_color)
			items_btn.add_theme_color_override("font_pressed_color", inactive_text_color)

func set_tab(tab_name: String):
	current_tab = tab_name
	update_tab_styles()
	refresh_ui(current_data)

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

	for name in active_data.keys():
		var slot_data = active_data[name]
		var item_data = slot_data["resource"]

		var new_slot = slot_prefab.instantiate()
		item_list.add_child(new_slot)
		
		# 1. Set the Icon
		var icon_rect = new_slot.get_node("Icon")
		if slot_data["resource"].item_icon:
			icon_rect.texture = slot_data["resource"].item_icon
		
		# 2. Set the Count Label
		var count_label = new_slot.get_node("Count")
		count_label.text = "x" + str(slot_data["count"])
		count_label.hide()
		
		# 3. Add a tooltip
		new_slot.tooltip_text = name
		
		var name_label = new_slot.get_node_or_null("Name")
		if name_label:
			if "display_name" in slot_data["resource"]:
				name_label.text = slot_data["resource"].display_name
			else:
				name_label.text = name
