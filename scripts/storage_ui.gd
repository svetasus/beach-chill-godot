extends Control

@onready var grid = $Panel/GridContainer
var target_chest: Node3D

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
		
	# 3. Create a button for every item in the chest's array
	for i in range(target_chest.inventory.size()):
		var data_path = target_chest.inventory[i]
		var item_data = load(data_path)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		
		# If your ItemData has an icon, show it! Otherwise, use the name.
		if item_data and item_data.get("icon"):
			btn.icon = item_data.icon
			btn.expand_icon = true
		else:
			btn.text = "Item " + str(i)
			
		# Connect the button click to the withdraw function
		btn.pressed.connect(_on_item_clicked.bind(i))
		grid.add_child(btn)

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
