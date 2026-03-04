extends Node3D


func _on_multiplayer_spawner_spawned(node: Node) -> void:
	
	print("Player joined: ", node.name)


