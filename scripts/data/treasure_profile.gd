extends Resource
class_name TreasureProfile

@export var loot_table: Array[ItemData]
@export var base_item_scene: PackedScene = preload("res://scenes/features/baseItem.tscn")
@export var sand_particles: PackedScene = preload("res://scenes/vfx/vfxSandShovelBurst.tscn")
@export var treasure_scene: PackedScene = preload("res://scenes/features/treasurePoint.tscn")
