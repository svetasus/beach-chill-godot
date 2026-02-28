extends Resource
class_name ItemData

@export_group("Visuals")
@export var name: String = "Item"
@export var display_name: String = "Item"
# Use this for simple shells (drag .obj or .res here)
@export var item_icon: Texture2D
@export var particle_color: Color = Color.WHITE

@export var scene: PackedScene

#@export var texture: Texture2D # For UI icons

@export_group("Physics")
@export var mass: float = 1.0
@export var collision_size: Vector3 = Vector3(0.2, 0.2, 0.2)

@export_group("Logic")
@export var is_tool: bool = false
@export var is_collectible: bool = true
#@export_file("*.tscn") var tool_scene_path: String # The "Address" of the brain
