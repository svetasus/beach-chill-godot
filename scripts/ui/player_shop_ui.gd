extends Control

@onready var grid = $Panel/GridContainer
var target_shop: Node3D
var player_node: Node3D

var slot_prefab: PackedScene = preload("res://ui/collectionSlot.tscn")

func setup(shop: Node3D, player: Node3D):
	target_shop = shop
	player_node = player
	refresh_inventory()

func refresh_inventory():
	# 1. Clear old buttons
	for child in grid.get_children():
		child.queue_free()

	# 2. Safety check
	if target_shop == null or not "items_for_sale" in target_shop:
		return

	# 3. Create a slot for each item in shop
	for i in range(target_shop.items_for_sale.size()):
		var item_data = target_shop.items_for_sale[i]
		if not item_data: continue

		var new_slot = slot_prefab.instantiate()

		# Set Icon
		var icon_rect = new_slot.get_node("Icon")
		if item_data.get("item_icon"):
			icon_rect.texture = item_data.item_icon

		# Hide Count since infinite
		var count_label = new_slot.get_node("Count")
		count_label.visible = false

		# Set Name
		var display_name = item_data.name
		if item_data.get("display_name") and item_data.display_name != "":
			display_name = item_data.display_name

		var name_label = new_slot.get_node_or_null("Name")
		if name_label:
			name_label.text = display_name

		new_slot.tooltip_text = display_name

		# Price & Buy button setup
		var price_label = new_slot.get_node_or_null("Price")
		var buy_btn = new_slot.get_node_or_null("BuyButton")

		if price_label and buy_btn:
			price_label.visible = true
			buy_btn.visible = true

			var price = item_data.get_value()
			price_label.text = "$" + str(price)

			if player_node and player_node.money >= price:
				price_label.add_theme_color_override("font_color", Color.GREEN)
				buy_btn.disabled = false
			else:
				price_label.add_theme_color_override("font_color", Color.RED)
				buy_btn.disabled = true

			buy_btn.pressed.connect(_on_buy_clicked.bind(i, price))

		grid.add_child(new_slot)

func _on_buy_clicked(index: int, price: int):
	if target_shop and player_node:
		if player_node.money >= price:
			player_node.money -= price
			player_node.save_money()
			if player_node.has_node("PlayerUI"): player_node.get_node("PlayerUI").update_money_ui()

			target_shop.request_buy.rpc_id(1, index)

			# Refresh to update colors/disabled states of buttons in case we ran out of money
			refresh_inventory()

func _on_close_button_pressed():
	close_ui()

func close_ui():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_ui()
