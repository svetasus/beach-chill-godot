extends Node3D

var door_sound = preload("res://sounds/door_sound.ogg")

func _play_door_sound(player: Node3D):
	if player and player.has_node("InteractAudioPlayer"):
		var audio_player = player.get_node("InteractAudioPlayer")
		audio_player.stream = door_sound
		audio_player.play()


@onready var spawn_point = $SpawnPoint
@onready var label = $Label3D

@export var owner_id: int = -1
var entrance_node: Node3D = null

func _ready():
	pass

func set_house_owner(player_id: int, p_entrance_node: Node3D):
	owner_id = player_id
	entrance_node = p_entrance_node
	_rpc_set_label_text.rpc("Player " + str(player_id) + "'s House")

@rpc("call_local", "authority", "reliable")
func _rpc_set_label_text(text: String):
	label.text = text

func interact(player: Node3D):
	if not player.is_in_group("players"): return
	_play_door_sound(player)

	_rpc_request_exit.rpc_id(1, player.get_path())

@rpc("any_peer", "call_local")
func _rpc_request_exit(player_path: NodePath):
	if not multiplayer.is_server(): return

	var player = get_node_or_null(player_path)
	if player and is_instance_valid(player) and entrance_node and is_instance_valid(entrance_node):
		var spawn_marker = entrance_node.get_node_or_null("SpawnPoint")
		if spawn_marker:
			player.teleport(spawn_marker.global_position, spawn_marker.global_rotation)

func get_interaction_text() -> String:
	return "[E] to leave house"
