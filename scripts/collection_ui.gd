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

func set_tab(tab_name: String):
	current_tab = tab_name
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
