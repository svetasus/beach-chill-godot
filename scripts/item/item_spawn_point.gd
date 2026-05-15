@tool
extends Marker3D
class_name ItemSpawnPoint

@export var item_data: Resource : set = _set_item_data
@export var item_scene: PackedScene

var preview_mesh: MeshInstance3D

func _ready():
	if Engine.is_editor_hint():
		return

	# Only the server should spawn the pre-placed items.
	if multiplayer.is_server():
		_spawn_item.call_deferred()
	else:
		# Clients don't need the spawn points, as the server will spawn the actual items
		# and the MultiplayerSpawner will sync them to the clients.
		queue_free()

func _spawn_item():
	if not item_scene or not item_data:
		print("ItemSpawnPoint [%s]: Missing item_scene or item_data!" % name)
		queue_free()
		return

	var item_instance = item_scene.instantiate()

	# Apply local position and rotation from the global transform
	item_instance.position = global_position
	item_instance.rotation = global_rotation

	# Pass data_path to trigger network sync (item_logic.gd uses data_path with a setter)
	if "data_path" in item_instance:
		item_instance.data_path = item_data.resource_path
	elif "data" in item_instance:
		item_instance.data = item_data

	if "is_autospawned" in item_instance:
		item_instance.is_autospawned = true

	# Add it to the correct container watched by MultiplayerSpawner
	var container = get_node_or_null(Global.ITEMS_CONTAINER_PATH)
	if container:
		# Add the child without manually modifying the name. The MultiplayerSpawner will seamlessly synchronize it.
		container.add_child(item_instance, true)
	else:
		print("ItemSpawnPoint: Could not find ItemsContainer at %s" % Global.ITEMS_CONTAINER_PATH)
		# Fallback to current parent if container not found
		get_parent().add_child(item_instance, true)
	
	print("Spawning item ", item_instance.name)
	# We are done here, remove the spawn point
	queue_free()

# --- EDITOR PREVIEW LOGIC ---

func _set_item_data(new_data):
	item_data = new_data
	if Engine.is_editor_hint():
		_update_preview()

func _enter_tree():
	if Engine.is_editor_hint():
		if not preview_mesh:
			preview_mesh = MeshInstance3D.new()
			add_child(preview_mesh)
			# Don't save the preview mesh to the scene file
			preview_mesh.owner = null
		_update_preview()

func _update_preview():
	if not Engine.is_editor_hint() or not preview_mesh:
		return

	# Clear existing preview
	for child in preview_mesh.get_children():
		child.queue_free()

	if item_data and item_data.get("scene"):
		# If the item data has a scene, try to instance it as a preview
		var scene_res = item_data.get("scene")
		if scene_res is PackedScene:
			var preview = scene_res.instantiate()
			preview_mesh.add_child(preview)
			# Disable any scripts or physics on the preview so it doesn't run in editor
			_disable_nodes_recursive(preview)

func _disable_nodes_recursive(node: Node):
	node.set_process(false)
	node.set_physics_process(false)
	if node is RigidBody3D or node is StaticBody3D or node is Area3D:
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_disable_nodes_recursive(child)
