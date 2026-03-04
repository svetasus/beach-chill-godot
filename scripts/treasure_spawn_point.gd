@tool
extends Marker3D
class_name TreasureSpawnPoint

@export var loot_table: Array[ItemData]
@export var base_item_scene: PackedScene = preload("res://scenes/features/baseItem.tscn") : set = _set_base_item_scene
@export var sand_particles: PackedScene = preload("res://scenes/vfx/vfxSandShovelBurst.tscn") : set = _set_sand_particles
@export var treasure_scene: PackedScene = preload("res://scenes/features/treasurePoint.tscn") : set = _set_treasure_scene

var preview_mesh: MeshInstance3D

func _ready():
	if Engine.is_editor_hint():
		return

	# Only the server should spawn the pre-placed treasures.
	if multiplayer.is_server():
		_spawn_treasure.call_deferred()
	else:
		# Clients don't need the spawn points, as the server will spawn the actual items
		# and the MultiplayerSpawner will sync them to the clients.
		queue_free()

func _spawn_treasure():
	if not treasure_scene:
		print("TreasureSpawnPoint [%s]: Missing treasure_scene!" % name)
		queue_free()
		return

	var treasure_instance = treasure_scene.instantiate()

	# Give it a unique network name so it syncs correctly
	treasure_instance.name = "TreasurePoint_" + str(get_instance_id())

	# Add it to the correct container watched by MultiplayerSpawner
	var container = get_node_or_null(Global.TREASURES_CONTAINER_PATH)
	if not container:
		container = get_tree().root.get_node_or_null(Global.TREASURES_CONTAINER_PATH)

	if container:
		container.add_child(treasure_instance, true)
	else:
		print("TreasureSpawnPoint: Could not find TreasuresContainer at %s" % Global.TREASURES_CONTAINER_PATH)
		# Fallback to current parent if container not found
		get_parent().add_child(treasure_instance, true)

	# Ensure the spawned treasure maintains its required group so the MetalDetector can find it
	if not treasure_instance.is_in_group("treasures"):
		treasure_instance.add_to_group("treasures")

	# Apply transform
	treasure_instance.global_transform = global_transform

	# Apply properties
	if "loot_table" in treasure_instance:
		treasure_instance.loot_table = loot_table
	if "base_item_scene" in treasure_instance:
		treasure_instance.base_item_scene = base_item_scene
	if "sand_particles" in treasure_instance:
		treasure_instance.sand_particles = sand_particles

	# We are done here, remove the spawn point
	queue_free()

# --- EDITOR PREVIEW LOGIC ---

func _set_base_item_scene(new_val):
	base_item_scene = new_val

func _set_sand_particles(new_val):
	sand_particles = new_val

func _set_treasure_scene(new_val):
	treasure_scene = new_val
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

	if treasure_scene:
		var preview = treasure_scene.instantiate()
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
