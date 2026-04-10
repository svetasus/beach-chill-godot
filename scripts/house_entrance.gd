extends StaticBody3D

@onready var label = $Label3D
@onready var spawn_point = $SpawnPoint

@export var owner_id: int = -1
var house_node: Node3D = null

func _ready():
	pass

func set_entrance_owner(player_id: int, p_house_node: Node3D):
	owner_id = player_id
	house_node = p_house_node
	_rpc_set_label_text.rpc("Player " + str(player_id) + "'s House")

@rpc("call_local", "authority", "reliable")
func _rpc_set_label_text(text: String):
	label.text = text

func interact(player: Node3D):
	if not player.is_in_group("players"): return

	_rpc_request_enter.rpc_id(1, player.get_path())

@rpc("any_peer", "call_local")
func _rpc_request_enter(player_path: NodePath):
	if not multiplayer.is_server(): return

	var player = get_node_or_null(player_path)
	if player and is_instance_valid(player) and house_node and is_instance_valid(house_node):
		var house_spawn = house_node.get_node_or_null("SpawnPoint")
		if house_spawn:
			player.teleport(house_spawn.global_position, house_spawn.global_rotation)

func get_interaction_text() -> String:
	return "[E] to enter house"
