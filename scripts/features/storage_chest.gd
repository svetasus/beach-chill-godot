extends StaticBody3D

@export var chest_ui_scene: PackedScene
@export var item_scene: PackedScene # The base Item.tscn to spawn when withdrawing
@export var spawn_point: Marker3D # A marker slightly above/in front of the chest

var owner_id: int = 1
var inventory: Array = [] # Array of Strings (Item data_paths)

@onready var items_container = get_node(Global.ITEMS_CONTAINER_PATH) # Or ItemsContainer

func interact(player: Node3D):
	if chest_ui_scene == null:
		print("ERROR: chest_ui_scene is not assigned in the inspector!")
		return

	var ui = chest_ui_scene.instantiate()

	if player.has_method("open_ui"):
		if not player.open_ui(ui):
			return # UI was blocked/closed
	else:
		print("ERROR: player does not have open_ui method!")
		return

	if ui.has_method("setup"):
		ui.setup(self)

# --- 1. DEPOSITING (SERVER ONLY) ---

func deposit_item(item_node: Node3D, player_id: int):
	if not multiplayer.is_server(): return
	if owner_id != -1 and player_id != owner_id:
		print("ACCESS DENIED: Not your chest!")
		return
		
	var path = item_node.get("data_path")
	if path == null or path == "":
		print("ERROR: Item has no data_path to store!")
		return
		
	# 1. Save the data
	inventory.append(path)
	
	# 2. Destroy the physical object globally
	item_node.destroy_item.rpc()
	print("SERVER: Item stored! Inventory size: ", inventory.size())

	# 3. Update all clients
	_rpc_update_inventory.rpc(inventory)

# --- 2. WITHDRAWING (CLIENT ASKS SERVER) ---

# The UI calls this RPC when a player clicks an item button
@rpc("any_peer", "call_local", "reliable")
func request_withdraw(item_index: int):
	# 1. Server validation
	if not multiplayer.is_server(): return
	
	var sender_id = multiplayer.get_remote_sender_id()
	if owner_id != -1 and sender_id != owner_id:
		print("ACCESS DENIED: Player ", sender_id, " tried to rob a chest!")
		return
		
	if item_index < 0 or item_index >= inventory.size():
		print("ERROR: Invalid chest index!")
		return
		
	# 2. Extract the data and remove it from the chest
	var path_to_spawn = inventory[item_index]
	inventory.remove_at(item_index)
	
	# 3. Update all clients
	_rpc_update_inventory.rpc(inventory)

	# 4. Spawn the physical item back into the world
	_spawn_physical_item(path_to_spawn)

func _spawn_physical_item(path: String):
	var new_item = item_scene.instantiate()
	
	# Fix Godot 4 MultiplayerSpawner errors by setting transform BEFORE add_child
	new_item.position = spawn_point.global_position
	new_item.data_path = path
	
	items_container.add_child(new_item, true)
	print("SERVER: Item extracted and spawned successfully.")

func get_interaction_text() -> String:
	return "[E] Open Storage"

@rpc("any_peer", "call_local", "reliable")
func _rpc_update_inventory(new_inventory: Array):
	inventory = new_inventory
	# Optional: If the client currently has the UI open for THIS chest, trigger a refresh!
	var ui = get_tree().root.find_child("StorageUI", true, false)
	if ui and ui.has_method("refresh_inventory") and ui.target_chest == self:
		ui.refresh_inventory()
