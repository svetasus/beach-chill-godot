extends StaticBody3D

@export var ingredient_scene: PackedScene 

func interact(player):
	print("GUEST/HOST: I clicked the crate!") # If you don't see this, your Raycast is missing the crate
	
	if ingredient_scene == null:
		print("ERROR: You forgot to drag a Tomato/Ingredient scene into the Crate's Inspector!")
		return

	if not multiplayer.is_server():
		print("GUEST: Requesting Host to spawn...")
		rpc_id(1, "request_spawn", player.get_path())
	else:
		print("HOST: Spawning for myself...")
		spawn_ingredient(player)

@rpc("any_peer", "call_local")
func request_spawn(player_path):
	print("HOST: Received RPC from Guest for path: ", player_path)
	var player = get_node_or_null(player_path)
	if player:
		spawn_ingredient(player)
	else:
		print("HOST ERROR: Could not find player node at: ", player_path)

func spawn_ingredient(player):
	var new_item = ingredient_scene.instantiate()
	
	new_item.name = "Item_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 1000)
	
	# This searches the WHOLE tree for 'ItemsContainer' so paths don't matter
	var container = get_tree().root.find_child("ItemsContainer", true, false)
	
	if container:
		container.add_child(new_item, true)
		new_item.global_transform = player.hand.global_transform
		player.pick_up(new_item)
		print("HOST: ITEM BORN! Check your hand.")
	else:
		print("HOST ERROR: I cannot find a node named 'ItemsContainer' anywhere in the tree!")
