extends Node3D


func _on_multiplayer_spawner_spawned(node: Node) -> void:
	
	print("Player joined: ", node.name)


func _on_player_connected(id: int):
	# Wait a frame to ensure player is fully in
	await get_tree().process_frame
	$TentManager.spawn_tent_for_player(id)

func _on_player_disconnected(id: int):
	$TentManager.remove_tent(id)
