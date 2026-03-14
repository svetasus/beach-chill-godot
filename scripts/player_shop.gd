extends StaticBody3D
class_name PlayerShop

@export var shop_ui_scene: PackedScene
@export var item_scene: PackedScene # The base Item.tscn to spawn when buying
@export var spawn_point: Marker3D # A marker slightly above/in front of the shop
@export var items_for_sale: Array[ItemData] = []

@onready var items_container = get_node(Global.ITEMS_CONTAINER_PATH)

func interact(player: Node3D):
	if shop_ui_scene == null:
		print("ERROR: shop_ui_scene is not assigned in the inspector!")
		return

	var ui = shop_ui_scene.instantiate()

	if player.has_method("open_ui"):
		if not player.open_ui(ui):
			return
	else:
		print("ERROR: player does not have open_ui method!")
		return

	if ui.has_method("setup"):
		ui.setup(self, player)

# The UI calls this RPC when a player clicks a buy button AND has already deducted money
@rpc("any_peer", "call_local", "reliable")
func request_buy(item_index: int):
	# 1. Server validation
	if not multiplayer.is_server(): return

	if item_index < 0 or item_index >= items_for_sale.size():
		print("ERROR: Invalid shop index!")
		return

	var item_data = items_for_sale[item_index]
	if item_data == null:
		print("ERROR: Item data is null at index: ", item_index)
		return

	var path_to_spawn = item_data.resource_path

	# 3. Spawn the physical item back into the world
	_spawn_physical_item(path_to_spawn)

func _spawn_physical_item(path: String):
	if not path or path == "":
		print("ERROR: Cannot spawn item with empty path!")
		return

	var new_item = item_scene.instantiate()
	new_item.name = "Item_Bought_" + str(Time.get_ticks_msec())

	# Add to world BEFORE pushing data
	items_container.add_child(new_item, true)
	new_item.global_position = spawn_point.global_position

	await get_tree().process_frame

	if is_instance_valid(new_item):
		new_item.data_path = path
		print("SERVER: Item bought and spawned successfully.")

func get_interaction_text() -> String:
	return "[E] Open Shop"
