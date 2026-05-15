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
@export var is_furniture: bool = false
#@export_file("*.tscn") var tool_scene_path: String # The "Address" of the brain

enum ItemValueType { COMMON, RARE, EPIC, ARTIFACT }
@export var item_value_type: ItemValueType = ItemValueType.COMMON

func get_value() -> int:
	match item_value_type:
		ItemValueType.COMMON:
			return 10
		ItemValueType.RARE:
			return 20
		ItemValueType.EPIC:
			return 40
		ItemValueType.ARTIFACT:
			return 80
	return 10

func get_chance() -> int:
	match item_value_type:
		ItemValueType.COMMON:
			return 8
		ItemValueType.RARE:
			return 4
		ItemValueType.EPIC:
			return 2
		ItemValueType.ARTIFACT:
			return 1
	return 1
