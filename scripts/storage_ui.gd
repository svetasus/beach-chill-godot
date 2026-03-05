extends Control

@onready var grid = $Panel/GridContainer
var target_chest: Node3D

var slot_prefab: PackedScene = preload(Global.INVENTORY_SLOT_PATH)

func setup(chest: Node3D):
	target_chest = chest
	refresh_inventory()

func refresh_inventory():
	# 1. Clear old buttons
	for child in grid.get_children():
		child.queue_free()
		
	# 2. Safety check
	if target_chest == null or not "inventory" in target_chest:
		return
		
	# 3. Aggregate items by data_path
	var aggregated_items = {} # data_path -> { "count": X, "indices": [i1, i2], "resource": item_data }
	for i in range(target_chest.inventory.size()):
		var data_path = target_chest.inventory[i]
		if not aggregated_items.has(data_path):
			aggregated_items[data_path] = {
				"count": 0,
				"indices": [],
				"resource": load(data_path)
			}
		aggregated_items[data_path]["count"] += 1
		aggregated_items[data_path]["indices"].append(i)

	# 4. Create a slot for each unique item type
	for data_path in aggregated_items.keys():
		var item_info = aggregated_items[data_path]
		var item_data = item_info["resource"]
		var count = item_info["count"]
		var withdraw_index = item_info["indices"][0] # Just pull the first one in the list
		
		var new_slot = slot_prefab.instantiate()
		
		# Set Icon
		var icon_rect = new_slot.get_node("Icon")
		if item_data and item_data.get("item_icon"):
			icon_rect.texture = item_data.item_icon

		# Set Count
		var count_label = new_slot.get_node("Count")
		count_label.text = "x" + str(count)

		# Set Name / display_name
		var display_name = data_path
		if item_data and item_data.get("display_name"):
			display_name = item_data.display_name
		elif item_data and item_data.get("name"):
			display_name = item_data.name

		var name_label = new_slot.get_node_or_null("Name")
		if name_label:
			name_label.text = display_name
			
		new_slot.tooltip_text = display_name

		# Overlay a transparent button to make the slot clickable
		var click_btn = Button.new()
		click_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		click_btn.flat = true
		new_slot.add_child(click_btn)

		click_btn.pressed.connect(_on_item_clicked.bind(withdraw_index))

		grid.add_child(new_slot)

func _on_item_clicked(index: int):
	if target_chest:
		# Tell the server we want to pull this item out!
		target_chest.request_withdraw.rpc_id(1, index)
		# Close the UI so the player can catch the item
		close_ui()

func _on_close_button_pressed():
	close_ui()

func close_ui():
	# Lock the mouse back to the game and destroy the menu
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_ui()
