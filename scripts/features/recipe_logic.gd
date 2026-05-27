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
	if not player.has_method("learn_recipe"):
		return

	var item_node = self
	var data = null
	while item_node != null:
		if "data" in item_node and item_node.data != null:
			data = item_node.data
			break
		item_node = item_node.get_parent()

	if data is RecipeData and data.target_recipe:
		player.learn_recipe(data.target_recipe)
		if item_node.has_method("destroy_item"):
			item_node.destroy_item.rpc()
		else:
			if multiplayer.is_server():
				item_node.queue_free()
