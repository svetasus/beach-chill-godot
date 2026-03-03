extends VBoxContainer

@export var notification_prefab: PackedScene

func display_message(text: String):
	var popup = notification_prefab.instantiate()
	add_child(popup)
	popup.get_node("MessageLabel").text = text
	
	# Initial state (Invisible and slightly off-set)
	popup.modulate.a = 0
	popup.position.x += 50
	
	# The Animation (The "Juice")
	var tween = create_tween().set_parallel(true)
	# Fade in and slide left
	tween.tween_property(popup, "modulate:a", 1.0, 0.3)
	tween.tween_property(popup, "position:x", popup.position.x - 50, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Wait 2 seconds, then fade out and delete
	await get_tree().create_timer(2.0).timeout
	
	var fade_out = create_tween()
	fade_out.tween_property(popup, "modulate:a", 0, 0.5)
	fade_out.finished.connect(popup.queue_free)
