extends Resource
class_name TaskData

@export var description: String = "Task description"
@export_enum("gather", "sell") var action: String = "gather"
@export var any_item: bool = false

# Ignored if any_item is true or specific_item is set
@export var item_type: ItemData.ItemValueType = ItemData.ItemValueType.COMMON

# If set, we look for this specific item. If null, we fall back to item_type (or any_item)
@export var specific_item: ItemData

@export var target_count: int = 3
@export var reward_money: int = 100

# Unique ID to match TaskData with TaskState in saves
@export var id: String = ""
