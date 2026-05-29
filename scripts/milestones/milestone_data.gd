extends Resource
class_name MilestoneData

@export var id: String = ""
@export var title: String = "Milestone Title"
@export var description: String = "Milestone Description"
@export var reward_description: String = "Reward details"
@export_enum("none", "money", "recipe", "item") var reward_type: String = "none"
@export var reward_money: int = 0
@export var reward_recipe: ArtifactData
@export var reward_item: ItemData

@export var icon: Texture2D

@export_enum("gather", "sell", "craft") var action: String = "gather"
@export var any_item: bool = false
@export var item_type: ItemData.ItemValueType = ItemData.ItemValueType.COMMON
@export var specific_item: ItemData
@export var specific_artifact: ArtifactData
@export var target_count: int = 1

# Positioning for the tech-tree UI
@export var grid_position: Vector2i = Vector2i(0, 0)

# IDs of milestones that must be completed before this one unlocks
@export var prerequisites: Array[String] = []
