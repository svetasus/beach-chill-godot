extends StaticBody3D

func interact(player: Node3D):
	if get_parent() and get_parent().has_method("interact"):
		get_parent().interact(player)

func get_interaction_text() -> String:
	if get_parent() and get_parent().has_method("get_interaction_text"):
		return get_parent().get_interaction_text()
	return "[E] to interact"
