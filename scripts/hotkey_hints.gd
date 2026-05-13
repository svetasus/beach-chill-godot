extends VBoxContainer

func _ready():
	_setup_hints()

func _setup_hints():
	var hints_to_show = [
		{"action": "toggle_milestones", "text": "Milestones"},
		{"action": "inventory", "text": "Collections"},
		{"action": "toggle_tasks", "text": "Tasks"},
		{"action": "toggle_camera", "text": "Change camera mode"}
	]

	for hint in hints_to_show:
		var action_name = hint["action"]
		var description = hint["text"]

		# Get the mapped key for the action
		var key_string = "?"
		if InputMap.has_action(action_name):
			var events = InputMap.action_get_events(action_name)
			for event in events:
				if event is InputEventKey:
					key_string = OS.get_keycode_string(event.physical_keycode)
					break

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)

		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
		style.border_color = Color(0.8, 0.8, 0.8, 1.0)
		style.border_width_bottom = 2
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 2
		style.content_margin_bottom = 2
		panel.add_theme_stylebox_override("panel", style)

		var key_label = Label.new()
		key_label.text = key_string
		key_label.add_theme_font_size_override("font_size", 16)
		panel.add_child(key_label)

		var desc_label = Label.new()
		desc_label.text = description
		desc_label.add_theme_font_size_override("font_size", 16)
		desc_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		desc_label.add_theme_constant_override("outline_size", 4)

		hbox.add_child(panel)
		hbox.add_child(desc_label)
		add_child(hbox)
