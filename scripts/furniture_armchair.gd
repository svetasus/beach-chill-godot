extends Node3D

# This will keep track of who is sitting on this armchair
var occupant_id: int = 0

func interact(player: Node3D):
	if occupant_id == 0:
		# Tell the server someone wants to sit here
		rpc_id(1, "_request_sit", player.get_multiplayer_authority())

@rpc("any_peer", "call_local")
func _request_sit(peer_id: int):
	if not multiplayer.is_server(): return

	if occupant_id == 0:
		_sync_sit.rpc(peer_id)

@rpc("any_peer", "call_local")
func _sync_sit(peer_id: int):
	occupant_id = peer_id

	if multiplayer.get_unique_id() == peer_id:
		# I am the one sitting down!
		var players = get_tree().get_nodes_in_group("players")
		for p in players:
			if p.get_multiplayer_authority() == peer_id:
				p.use_furniture(self)

func leave(player: Node3D):
	if occupant_id == player.get_multiplayer_authority():
		rpc_id(1, "_request_leave")

@rpc("any_peer", "call_local")
func _request_leave():
	if not multiplayer.is_server(): return

	_sync_leave.rpc()

@rpc("any_peer", "call_local")
func _sync_leave():
	occupant_id = 0

func get_interaction_text() -> String:
	if occupant_id == 0:
		return "[R] Sit"
	else:
		return "Occupied"
