extends StaticBody3D

@export var owner_id: int = -1
@export var is_private: bool = true:
	set(value):
		is_private = value
		_update_label()
		_update_tent_collision()

@onready var label = $RulesLabel

# This will be passed the player object from player.gd `target.interact(self)`
func interact(player):
	if player.multiplayer.get_unique_id() == owner_id:
		# Toggle the rules
		_rpc_toggle_rules.rpc_id(1)
	else:
		print("Only the tent owner can change the rules!")

# Used by player.gd update_action_ui()
func get_interaction_text() -> String:
	if multiplayer.get_unique_id() == owner_id:
		return "[E] Change rules"
	else:
		return ""

@rpc("any_peer", "call_local")
func _rpc_toggle_rules():
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	if sender_id == owner_id:
		is_private = !is_private
		# the MultiplayerSynchronizer handles syncing `is_private` to everyone

func _update_label():
	if not is_node_ready(): return
	if is_private:
		label.text = "Private"
		label.modulate = Color.RED
	else:
		label.text = "Everyone welcome"
		label.modulate = Color.GREEN

func _ready():
	_update_label()

func _update_tent_collision():
	var parent_tent = get_parent()
	if parent_tent and parent_tent.has_method("_update_barrier"):
		parent_tent._update_barrier(is_private)
