extends Area3D
class_name AutospawnArea

@export var spawn_profile: SpawnProfile
@export var treasure_profile: TreasureProfile

@export var max_items: int = 5
@export var max_treasures: int = 5

@export var item_scene: PackedScene = preload("res://scenes/features/baseItem.tscn")
