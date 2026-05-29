extends Resource
class_name TaskSectionData

@export var section_name: String = "Section"
@export var has_timer: bool = false
@export var timer_duration_seconds: int = 86400 # 24 hours default
@export var num_slots: int = 3
@export var available_tasks: Array[TaskData] = []
