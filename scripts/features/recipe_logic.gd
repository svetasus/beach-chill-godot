extends Node3D

func get_interaction_text() -> String:
	return "[E] Read recipe"

func interact(player: Node3D):
	_read_recipe(player)

func alt_interact(player: Node3D):
	_read_recipe(player)

func get_alt_interaction_text() -> String:
	return "[R] Read recipe"

func apply_item(item: Node3D) -> bool:
	return false

func _read_recipe(player: Node3D):
	if player.has_method("learn_recipe") and get_parent() and get_parent().get_parent() and "data" in get_parent().get_parent():
		var data = get_parent().get_parent().data
		if data is RecipeData and data.target_recipe:
			player.learn_recipe(data.target_recipe)
			var item_node = get_parent().get_parent()
			if item_node.has_method("destroy_item"):
				item_node.destroy_item.rpc()
			else:
				if multiplayer.is_server():
					item_node.queue_free()
