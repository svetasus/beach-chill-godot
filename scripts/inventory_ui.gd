extends Control

@onready var item_list = $PanelContainer/ScrollContainer/ItemList
@export var slot_prefab: PackedScene # Drag InventorySlot.tscn here in Inspector

func _ready():
	# Hide by default when the game starts
	self.hide()

func refresh_ui(data: Dictionary):
	# Clear the old list
	for child in item_list.get_children():
		child.queue_free()
	
	for name in data.keys():
		var slot_data = data[name]
		var new_slot = slot_prefab.instantiate()
		item_list.add_child(new_slot)
		
		# 1. Set the Icon
		var icon_rect = new_slot.get_node("Icon")
		if slot_data["resource"].item_icon:
			icon_rect.texture = slot_data["resource"].item_icon
		
		# 2. Set the Count Label
		new_slot.get_node("Count").text = "x" + str(slot_data["count"])
		
		# 3. Add a tooltip (Hover over to see the name)
		new_slot.tooltip_text = name
		
		var name_label = new_slot.get_node_or_null("display_name")
		if name_label:
			name_label.text = name
