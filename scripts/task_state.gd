extends Resource
class_name TaskState

@export var task_id: String = ""
@export var current_count: int = 0
@export var is_completed: bool = false
@export var reward_claimed: bool = false

func to_dict() -> Dictionary:
	return {
		"task_id": task_id,
		"current_count": current_count,
		"is_completed": is_completed,
		"reward_claimed": reward_claimed
	}

func from_dict(dict: Dictionary):
	task_id = dict.get("task_id", "")
	current_count = dict.get("current_count", 0)
	is_completed = dict.get("is_completed", false)
	reward_claimed = dict.get("reward_claimed", false)
