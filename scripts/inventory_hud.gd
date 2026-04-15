extends Control

@onready var slots = [
	$HBoxContainer/Slot0,
	$HBoxContainer/Slot1,
	$HBoxContainer/Slot2
]

var active_slot_color = Color(1.0, 1.0, 1.0, 0.5)
var inactive_slot_color = Color(0.2, 0.2, 0.2, 0.5)

func _ready():
	var player = get_parent().get_parent()
	if player.has_signal("inventory_slots_updated"):
		player.inventory_slots_updated.connect(_on_inventory_slots_updated)

	# Initial clear
	for i in range(3):
		_update_slot(i, null, i == 0)

func _on_inventory_slots_updated(items: Array, active_index: int):
	for i in range(items.size()):
		_update_slot(i, items[i], i == active_index)

func _update_slot(index: int, item: Node, is_active: bool):
	var slot = slots[index]
	var panel = slot.get_node("Panel")
	var icon = slot.get_node("VBoxContainer/Icon")
	var label = slot.get_node("VBoxContainer/Label")
	var num_label = slot.get_node("NumberLabel")

	if is_active:
		panel.self_modulate = active_slot_color
	else:
		panel.self_modulate = inactive_slot_color

	if item != null and is_instance_valid(item):
		label.text = item.get("display_name") if "display_name" in item else item.name
		var tex = null
		if "data" in item and item.data != null and "item_icon" in item.data:
			tex = item.data.item_icon
		if tex:
			icon.texture = tex
			icon.show()
		else:
			icon.texture = null
			icon.hide()
	else:
		label.text = "Empty"
		icon.texture = null
		icon.hide()
