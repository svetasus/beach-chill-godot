extends LineEdit


func _input(event):
	if event.is_action_pressed("chat"): # 'ui_accept' is usually the Enter key
		var my_id = multiplayer.get_unique_id()
		var my_player = get_node_or_null(Global.PLAYERS_CONTAINER_PATH + str(my_id))
		
		if not visible:
			# 1. Show the chat box and focus it
			show()
			call_deferred("grab_focus")
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			# STOP the player from moving
			if my_player: my_player.is_typing = true
			get_viewport().set_input_as_handled()
		else:
			# 2. If it's already open, SEND the message
			send_chat()
			if my_player: my_player.is_typing = false
			get_viewport().set_input_as_handled()
			
			
func send_chat():
	if text != "":
		# Find the node that belongs to ME (the local player)
		var my_id = multiplayer.get_unique_id()
		var my_player = get_node(Global.PLAYERS_CONTAINER_PATH + str(my_id))
		
		if my_player:
			# This is where we call the function we wrote in player.gd
			my_player.rpc("receive_message", text)
			
			
	# 3. Clean up
	text = ""
	hide()
	# Tell the player they can move again
	var my_id = multiplayer.get_unique_id()
	var my_player = get_node_or_null(Global.PLAYERS_CONTAINER_PATH + str(my_id))
	if my_player: my_player.is_typing = false
	
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# IMPORTANT: Stop the 'Enter' or 'Space' from triggering a jump right as you close the chat
	get_viewport().set_input_as_handled()


func _gui_input(event):
	
	# If the chat is open and I click away or hit Esc, close it
	if event is InputEventMouseButton and event.pressed:
		release_focus()
		hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
