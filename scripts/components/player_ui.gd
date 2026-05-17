extends CanvasLayer
class_name PlayerUI

var player

func _ready():
	player = get_parent()
	if player and not player.is_multiplayer_authority():
		hide()
		return

func update_money_ui():
	var money_label = get_node_or_null("MoneyLabel")
	if money_label:
		money_label.text = "Money: $" + str(player.get("money"))

func show_floating_money(amount: int):
	if not player.is_multiplayer_authority(): return
	var floating_label = Label.new()
	floating_label.text = "+$" + str(amount)
	floating_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2)) # Green color
	floating_label.add_theme_font_size_override("font_size", 24)

	add_child(floating_label)

	var start_pos = Vector2(20, 60)
	if get_node_or_null("MoneyLabel"):
		start_pos = get_node("MoneyLabel").position + Vector2(0, 30)

	floating_label.position = start_pos

	var tween = create_tween()
	tween.tween_property(floating_label, "position", start_pos + Vector2(0, -50), 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(floating_label, "modulate:a", 0.0, 1.5)

	tween.tween_callback(floating_label.queue_free)

func toggle_milestones():
	if not player.is_multiplayer_authority(): return
	var progression_ui = get_node_or_null("ProgressionUI")
	if not progression_ui: return

	if progression_ui.visible and progression_ui.current_tab == "Milestones":
		progression_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		progression_ui.visible = true
		progression_ui.set_tab("Milestones")
		var inv_ui = get_node_or_null("CollectionUI")
		if inv_ui: inv_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_tasks():
	if not player.is_multiplayer_authority(): return
	var progression_ui = get_node_or_null("ProgressionUI")
	if not progression_ui: return

	if progression_ui.visible and progression_ui.current_tab == "Tasks":
		progression_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		progression_ui.visible = true
		progression_ui.set_tab("Tasks")
		var inv_ui = get_node_or_null("CollectionUI")
		if inv_ui: inv_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_collection():
	if not player.is_multiplayer_authority(): return
	var inv_ui = get_node_or_null("CollectionUI")
	if not inv_ui: return
	inv_ui.visible = !inv_ui.visible

	if inv_ui.visible:
		var prog_ui = get_node_or_null("ProgressionUI")
		if prog_ui: prog_ui.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		inv_ui.refresh_ui({"items": player.get("items_held"), "artifacts": player.get("artifacts_crafted")})
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
