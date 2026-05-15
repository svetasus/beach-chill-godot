extends ItemData
class_name ClothingData

enum ClothingType { HAT, TOP, PANTS, GLASSES }

@export_group("Clothing Settings")
@export var clothing_type: ClothingType = ClothingType.HAT
@export var worn_scene: PackedScene
@export var vision_color: Color = Color(1, 1, 1, 1) # Used primarily for Glasses
