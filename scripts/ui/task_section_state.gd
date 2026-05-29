extends Resource
class_name TaskSectionState

@export var section_name: String = ""
@export var next_refresh_time: float = 0.0
@export var active_task_ids: Array[String] = []

func to_dict() -> Dictionary:
	return {
		"section_name": section_name,
		"next_refresh_time": next_refresh_time,
		"active_task_ids": active_task_ids
	}

func from_dict(dict: Dictionary):
	section_name = dict.get("section_name", "")
	next_refresh_time = dict.get("next_refresh_time", 0.0)

	var active_ids_array = dict.get("active_task_ids", [])
	active_task_ids.clear()
	for id in active_ids_array:
		active_task_ids.append(str(id))
