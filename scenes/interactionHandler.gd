extends ShapeCast3D

@onready var player = get_owner()

func get_interaction_target():
	if is_colliding():
		var collider = get_collider(0)
		if collider is Item:
			return collider
	return null

func _process(_delta):
	if not is_multiplayer_authority(): return
	_update_action_ui()

func _update_action_ui():
	var action_label = player.action_label
	var equipment = player.get_node("Body/Head/Camera3D/EquipmentManager")
	var target_text = ""

	if equipment.carried_item == null:
		var target = get_interaction_target()
		if target and target is Item:
			target_text = "[E] Take " + target.display_name
	else:
		var tool = player.get_held_tool()
		if tool and tool.can_interact_with(player.current_treasure):
			target_text = "[E] " + tool.get_action_name()
		else:
			target_text = "[E] Drop " + equipment.carried_item.display_name

	if action_label.text != target_text:
		action_label.text = target_text
		var tween = create_tween()
		if target_text == "":
			tween.tween_property(action_label, "modulate:a", 0.0, 0.1)
		else:
			action_label.modulate.a = 0.0
			tween.tween_property(action_label, "modulate:a", 1.0, 0.2)
