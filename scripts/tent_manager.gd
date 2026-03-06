extends Node

@export var tent_scene: PackedScene

# Reference to the global container
@onready var tents_container = get_node(Global.TENTS_CONTAINER_PATH)

# Dictionary to track { player_id: tent_node }
var active_tents = {}



func spawn_tent_for_player(player_id: int):
	print("--- TENT DEBUG START (Player: ", player_id, ") ---")
	
	if not multiplayer.is_server(): 
		print("DEBUG: Not the server, aborting.")
		return
	
	var level_container = get_node_or_null(Global.LEVEL_PATH)
	if level_container == null:
		print("DEBUG ERROR: /root/Main/LevelLoaded does not exist!")
		return
	
	if level_container.get_child_count() == 0:
		print("DEBUG ERROR: LevelLoaded has NO children (Level not loaded yet).")
		return
		
	var current_level = level_container.get_child(0)
	print("DEBUG: Searching inside level: ", current_level.name)
	
	# Check the path strictly: Markers/TentSpawnMarkers
	var markers_folder = current_level.get_node_or_null(Global.TENT_MARKERS_LEVEL_PATH)
	if markers_folder == null:
		print("DEBUG ERROR: Could not find 'Markers/TentSpawnMarkers' inside ", current_level.name)
		# PRINT THE ACTUAL CHILDREN TO HELP US FIND THE RIGHT PATH
		print("DEBUG: Available children in level: ", current_level.get_children())
		return
	
	var all_markers = markers_folder.get_children()
	if all_markers.is_empty():
		print("DEBUG ERROR: Markers folder is empty!")
		return
		
	# Pick marker based on current tent count
	var spawn_index = active_tents.size()
	if spawn_index >= all_markers.size():
		print("DEBUG ERROR: No markers left for index: ", spawn_index)
		return
		
	var target_marker = all_markers[spawn_index]
	
	if not target_marker.is_inside_tree():
		await target_marker.tree_entered

	# Wait for a frame to ensure the global position is valid after entering the tree
	await get_tree().process_frame

	# Instantiate and Add
	var tent = tent_scene.instantiate()
	tent.name = "Tent_" + str(player_id)
	
	# Make sure tents_container is valid
	if tents_container == null:
		tents_container = get_node_or_null(Global.TENTS_CONTAINER_PATH)
		
	# Setting both global_position and global_rotation explicitly to ensure synchronization
	# and proper rotation application across the network.
	tent.global_position = target_marker.global_position
	tent.global_rotation = target_marker.global_rotation
	
	if tent.has_method("set_tent_owner"):
		tent.set_tent_owner(player_id)

	tents_container.add_child(tent, true)
	
	active_tents[player_id] = tent
	print("--- TENT DEBUG SUCCESS: Tent_", player_id, " spawned at ", target_marker.name, " ---")

func remove_tent(player_id: int):
	if not multiplayer.is_server(): return
	if active_tents.has(player_id):
		active_tents[player_id].queue_free()
		active_tents.erase(player_id)
		
		
