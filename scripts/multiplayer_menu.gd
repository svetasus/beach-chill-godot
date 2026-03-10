extends Control

var enet_peer = ENetMultiplayerPeer.new()

func _ready():
	# Ensure the mouse is visible so we can click Host/Join
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_host_button_pressed():
	# Set global team money setting based on the check box
	var checkbox = get_node_or_null("TeamMoneyCheckBox")
	if checkbox:
		Global.split_money_in_team = checkbox.button_pressed

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
	
	
	# Determine spawn point from level
	var spawn_pos = Vector3.ZERO
	var spawn_rot = Vector3.ZERO
	var container = get_node_or_null(Global.PLAYERS_CONTAINER_PATH)

	var level_container = get_node_or_null(Global.LEVEL_PATH)
	if level_container and level_container.get_child_count() > 0:
		var current_level = level_container.get_child(0)
		var markers_folder = current_level.get_node_or_null(Global.PLAYER_MARKERS_LEVEL_PATH)
		if markers_folder:
			var all_markers = markers_folder.get_children()
			if not all_markers.is_empty():
				# We calculate spawn index based on current number of players already in container
				var spawn_index = 0
				if container:
					spawn_index = container.get_child_count()
				if spawn_index >= all_markers.size():
					# Fallback or wrap around if we exceed markers
					spawn_index = spawn_index % all_markers.size()
				var target_marker = all_markers[spawn_index]
				spawn_pos = target_marker.global_position
				spawn_rot = target_marker.global_rotation

	# Set transform before adding to tree for proper MultiplayerSynchronizer init
	player.position = spawn_pos
	player.rotation = spawn_rot

	if container:
		container.add_child(player)
	
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
