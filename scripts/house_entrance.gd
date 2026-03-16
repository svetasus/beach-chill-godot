extends Node3D

@onready var enter_area = $EnterArea
@onready var label = $Label3D
@onready var spawn_point = $SpawnPoint

var owner_id: int = -1
var house_node: Node3D = null

func _ready():
	if not multiplayer.is_server(): return

	if enter_area:
		enter_area.body_entered.connect(_on_enter_area_body_entered)

func set_entrance_owner(player_id: int, p_house_node: Node3D):
	owner_id = player_id
	house_node = p_house_node
	_rpc_set_label_text.rpc("Player " + str(player_id) + "'s House")

@rpc("call_local", "authority", "reliable")
func _rpc_set_label_text(text: String):
	label.text = text

func _on_enter_area_body_entered(body: Node3D):
	if not multiplayer.is_server(): return

	if body.is_in_group("players"):
		if house_node and is_instance_valid(house_node):
			var house_spawn = house_node.get_node_or_null("SpawnPoint")
			if house_spawn:
				body.teleport(house_spawn.global_position, house_spawn.global_rotation)
