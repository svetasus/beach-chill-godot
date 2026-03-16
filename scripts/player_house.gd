extends Node3D

@onready var spawn_point = $SpawnPoint
@onready var exit_area = $ExitArea
@onready var exit_marker = $ExitArea/ExitMarker
@onready var label = $Label3D

@export var owner_id: int = -1
var entrance_node: Node3D = null

func _ready():
	if not multiplayer.is_server(): return

	if exit_area:
		exit_area.body_entered.connect(_on_exit_area_body_entered)

func set_house_owner(player_id: int, p_entrance_node: Node3D):
	owner_id = player_id
	entrance_node = p_entrance_node
	_rpc_set_label_text.rpc("Player " + str(player_id) + "'s House")

@rpc("call_local", "authority", "reliable")
func _rpc_set_label_text(text: String):
	label.text = text

func _on_exit_area_body_entered(body: Node3D):
	if not multiplayer.is_server(): return

	if body.is_in_group("players"):
		# Teleport player back to the entrance marker
		if entrance_node and is_instance_valid(entrance_node):
			var spawn_marker = entrance_node.get_node_or_null("SpawnPoint")
			if spawn_marker:
				body.teleport(spawn_marker.global_position, spawn_marker.global_rotation)
