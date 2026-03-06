extends Node3D

@export var owner_id: int = -1:
	set(new_id):
		owner_id = new_id
		_on_owner_id_changed()

@export var is_private: bool = true:
	set(value):
		is_private = value
		if has_node("TentRulesBlock"):
			$TentRulesBlock.is_private = value
		_update_barrier(is_private)

func _ready():
	if has_node("Area3D"):
		$Area3D.body_entered.connect(_on_area_body_entered)
		$Area3D.body_exited.connect(_on_area_body_exited)

	if has_node("TentRulesBlock"):
		$TentRulesBlock.is_private = is_private
	_update_barrier(is_private)

	_on_owner_id_changed()

func _on_owner_id_changed():
	if not is_inside_tree(): return
	
	if has_node("TentRulesBlock"):
		$TentRulesBlock.owner_id = owner_id

	_update_barrier(is_private)

	# Optional: Update a label or light color here
	if has_node("NameLabel"):
		$NameLabel.text = "Player " + str(owner_id) + "'s Tent"

	var storage_chest = get_node_or_null("storageMarker/StorageChest")
	if storage_chest:
		storage_chest.owner_id = owner_id

# This is the "Bouncer" function
func can_player_modify(player_id: int) -> bool:
	return player_id == owner_id

func set_tent_owner(new_id: int):
	owner_id = new_id
	print("Tent initialized for Player: ", owner_id)

func _on_area_body_entered(body):
	if body.is_multiplayer_authority() and body.multiplayer.get_unique_id() == body.name.to_int():
		if not is_private or body.multiplayer.get_unique_id() == owner_id:
			if has_node("Model/Tent"):
				$Model/Tent.hide()

@rpc("any_peer", "call_local")
func _rpc_toggle_rules():
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == owner_id:
		is_private = !is_private

func _on_area_body_exited(body):
	if body.is_multiplayer_authority() and body.multiplayer.get_unique_id() == body.name.to_int():
		if has_node("Model/Tent"):
			$Model/Tent.show()

func _update_barrier(is_private: bool):
	if not is_inside_tree(): return
	if has_node("TentBarrier"):
		if is_private and multiplayer.get_unique_id() != owner_id:
			$TentBarrier.set_collision_layer_value(1, true)
			$TentBarrier.set_collision_mask_value(2, true)
		else:
			$TentBarrier.set_collision_layer_value(1, false)
			$TentBarrier.set_collision_mask_value(2, false)
