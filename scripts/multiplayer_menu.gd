extends Control

var enet_peer = ENetMultiplayerPeer.new()

func _ready():
	# Ensure the mouse is visible so we can click Host/Join
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_host_button_pressed():
	# 1. Setup the server
	var error = enet_peer.create_server(9999)
	if error != OK:
		print("Cannot host: ", error)
		return
		
	multiplayer.multiplayer_peer = enet_peer
	
	# 2. Tell the game to run 'add_player' when someone joins
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)
	
	# 3. Add YOURSELF (the host) to the game
	add_player(multiplayer.get_unique_id())
	
	# 4. Trigger autospawn for items/treasures
	AutoSpawner.trigger_spawn()

	# 5. Hide the menu UI
	self.hide()

func _on_join_button_pressed():
	# Get the text from your LineEdit node
	var address = $AddressEntry.text # Make sure the name matches your LineEdit node
	
	# If the box is empty, default to localhost
	if address == "":
		address = "127.0.0.1"
	
	var error = enet_peer.create_client(address, 9999)
	
	if error != OK:
		print("Failed to join: ", error)
		return
	multiplayer.multiplayer_peer = enet_peer
	hide()

func add_player(peer_id):
	var player = preload(Global.PLAYER_SCENE_PATH).instantiate()
	player.name = str(peer_id) # This name MUST be the ID for authority to work!
	
	
	var container = get_node_or_null(Global.PLAYERS_CONTAINER_PATH)
	if container:
		container.add_child(player)
	
	# Move them to the spawn point AFTER adding to tree
	var spawn_point = get_node_or_null(Global.PLAYERS_SPAWNPOINT_PATH)
	if spawn_point:
		player.global_position = spawn_point.global_position
	
	var tent_manager = get_tree().root.get_node_or_null("Main/TentManager")
	if tent_manager:
		tent_manager.spawn_tent_for_player(peer_id)
		
	
	print("Spawned player ", peer_id, " at ", player.global_position)

func remove_player(peer_id: int):
	var container = get_node_or_null(Global.PLAYERS_CONTAINER_PATH)
	if container:
		var player = container.get_node_or_null(str(peer_id))
		if player:
			player.queue_free()

	var tent_manager = get_tree().root.get_node_or_null("Main/TentManager")
	if tent_manager:
		tent_manager.remove_tent(peer_id)
