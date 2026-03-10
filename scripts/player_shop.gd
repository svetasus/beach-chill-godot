extends StaticBody3D

@export var item_scene: PackedScene # The base Item.tscn to spawn when withdrawing
@export var spawn_point: Marker3D # A marker slightly above/in front of the chest

var owner_id: int = 1
var shop_items: Array = [] # Array of Strings (Item data_paths)

@onready var items_container = get_node(Global.ITEMS_CONTAINER_PATH) # Or ItemsContainer




@rpc("any_peer", "call_local", "reliable")
func request_withdraw(item_index: int):
	# 1. Server validation
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
		
	if item_index < 0 or item_index >= shop_items.size():
		print("ERROR: Invalid shop item index!")
		return
		
	
		
	# 2. Extract the data and remove it from the chest
	var path_to_spawn = shop_items[item_index]
	shop_items.remove_at(item_index)
	
	# 3. Spawn the physical item back into the world
	_spawn_physical_item(path_to_spawn)


func _spawn_physical_item(path: String):
	var new_item = item_scene.instantiate()
	new_item.name = "Item_Extracted_" + str(Time.get_ticks_msec())
	
	# Add to world BEFORE pushing data (The Patience Patch!)
	items_container.add_child(new_item, true)
	new_item.global_position = spawn_point.global_position
	
	await get_tree().process_frame
	
	if is_instance_valid(new_item):
		new_item.data_path = path
		print("SERVER: Item extracted and spawned successfully.")
