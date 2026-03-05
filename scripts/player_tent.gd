extends Node3D

@export var owner_id: int = -1 # The multiplayer ID of the player

func _ready():
	if has_node("Area3D"):
		$Area3D.body_entered.connect(_on_area_body_entered)
		$Area3D.body_exited.connect(_on_area_body_exited)

	_update_barrier(true)

# This is the "Bouncer" function
func can_player_modify(player_id: int) -> bool:
	return player_id == owner_id

func set_tent_owner(new_id: int):
	owner_id = new_id
	print("Tent initialized for Player: ", owner_id)
	
	if has_node("TentRulesBlock"):
		$TentRulesBlock.owner_id = owner_id

	var is_private = true
	if has_node("TentRulesBlock"):
		is_private = $TentRulesBlock.is_private
	_update_barrier(is_private)

	# Optional: Update a label or light color here
	if has_node("NameLabel"):
		$NameLabel.text = "Player " + str(owner_id) + "'s Tent"

	# Spawn a StorageChest for the tent, only on the server
	if multiplayer.is_server():
		var chest_scene = load("res://scenes/features/storageChest.tscn")
		if chest_scene:
			var chest = chest_scene.instantiate()
			chest.name = "StorageChest_" + str(owner_id)
			chest.owner_id = owner_id

			var storage_marker = get_node_or_null("storageMarker")
			if storage_marker:
				# Add it directly to the tent so it despawns with the tent
				storage_marker.add_child(chest, true)

func _on_area_body_entered(body):
	if body.is_multiplayer_authority() and body.multiplayer.get_unique_id() == body.name.to_int():
		var is_private = true
		if has_node("TentRulesBlock"):
			is_private = $TentRulesBlock.is_private

		if not is_private or body.multiplayer.get_unique_id() == owner_id:
			if has_node("Model/Tent"):
				$Model/Tent.hide()

func _on_area_body_exited(body):
	if body.is_multiplayer_authority() and body.multiplayer.get_unique_id() == body.name.to_int():
		if has_node("Model/Tent"):
			$Model/Tent.show()

func _update_barrier(is_private: bool):
	if has_node("TentBarrier"):
		if is_private and multiplayer.get_unique_id() != owner_id:
			$TentBarrier.set_collision_layer_value(1, true)
			$TentBarrier.set_collision_mask_value(2, true)
		else:
			$TentBarrier.set_collision_layer_value(1, false)
			$TentBarrier.set_collision_mask_value(2, false)
