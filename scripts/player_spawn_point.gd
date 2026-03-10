@tool
extends Marker3D
class_name PlayerSpawnPoint

@export var player_scene: PackedScene : set = _set_player_scene

var preview_node: Node3D

func _ready():
	if Engine.is_editor_hint():
		return

	# Clear the preview when the game actually starts running
	if preview_node:
		preview_node.queue_free()

func _set_player_scene(new_scene: PackedScene):
	player_scene = new_scene
	if Engine.is_editor_hint():
		_update_preview()

func _enter_tree():
	if Engine.is_editor_hint():
		if not preview_node:
			preview_node = Node3D.new()
			add_child(preview_node)
			# Don't save the preview mesh to the scene file
			preview_node.owner = null
		_update_preview()

func _update_preview():
	if not Engine.is_editor_hint() or not preview_node:
		return

	# Clear existing preview
	for child in preview_node.get_children():
		child.queue_free()

	if player_scene:
		var preview = player_scene.instantiate()
		preview_node.add_child(preview)
		# Disable any scripts or physics on the preview so it doesn't run in editor
		_disable_nodes_recursive(preview)

func _disable_nodes_recursive(node: Node):
	node.set_process(false)
	node.set_physics_process(false)
	if node is RigidBody3D or node is StaticBody3D or node is Area3D:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	if node is MultiplayerSynchronizer:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_disable_nodes_recursive(child)
