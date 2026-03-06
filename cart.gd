extends CharacterBody3D

var inventory_nodes: Array[Node3D] = []

# When a player clicks the cart while holding an item
func deposit_item_cart(item_node: Node3D):
	if not multiplayer.is_server(): return
	
	# 1. We don't delete the node anymore! We just add it to our list
	if not inventory_nodes.has(item_node):
		inventory_nodes.append(item_node)
		
		# 2. Tell the item to freeze and stick to the cart
		if item_node.has_method("lock_to_cart"):
			item_node.lock_to_cart(self)
			
		print("SERVER: Physical item locked into cart. Total: ", inventory_nodes.size())
