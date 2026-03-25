extends Control

@onready var chat_history = $VBoxContainer/ScrollContainer/ChatHistory

func _ready():
	# Hide background or something initially? Or just stay visible.
	pass

func add_message(sender_name: String, text: String, color: Color = Color.WHITE):
	var new_message = RichTextLabel.new()
	new_message.bbcode_enabled = true
	new_message.fit_content = true
	new_message.scroll_active = false

	# Determine color hex string for BBCode
	var color_hex = color.to_html()

	# E.g. [color=#ffff00]Player1:[/color] Hello!
	new_message.text = "[color=#" + color_hex + "]" + sender_name + ":[/color] " + text

	chat_history.add_child(new_message)

	# Auto-scroll to bottom
	await get_tree().process_frame
	var scroll = $VBoxContainer/ScrollContainer
	scroll.scroll_vertical = scroll.get_v_scroll_bar().max_value
