extends Node
class_name PlayerInventory

var player: CharacterBody3D

signal inventory_slots_updated(slots, active_index)

var carried_items: Array[Node] = [null, null, null, null]
var current_slot_index: int = 0

func _ready():
	player = get_parent()

func get_carried_item() -> Node:
	return carried_items[current_slot_index]

func set_carried_item(item: Node):
	carried_items[current_slot_index] = item

func get_held_tool():
	if get_carried_item():
		var anchor = get_carried_item().get_node_or_null("MeshAnchor")
		if anchor and anchor.get_child_count() > 0:
			var potential_tool = anchor.get_child(0)
			if potential_tool.has_method("update_proximity"):
				return potential_tool
	return null

func switch_slot(index: int):
	if index < 0 or index >= carried_items.size(): return
	if current_slot_index == index: return

	var old_item = get_carried_item()
	if is_instance_valid(old_item):
		old_item.visible = false
		if old_item.has_method("set_ghost_appearance"):
			old_item.set_ghost_appearance(false)

		var anchor = old_item.get_node_or_null("MeshAnchor")
		if anchor and anchor.get_child_count() > 0:
			var potential_tool = anchor.get_child(0)
			if potential_tool.has_method("update_proximity"):
				potential_tool.update_proximity(null)

	current_slot_index = index
	var new_item = get_carried_item()

	if is_instance_valid(new_item):
		new_item.visible = true
		if new_item.has_method("set_ghost_appearance") and get_held_tool() == null:
			new_item.set_ghost_appearance(true)

	inventory_slots_updated.emit(carried_items, current_slot_index)
