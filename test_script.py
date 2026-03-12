import sys

def modify_tent_manager():
    with open("scripts/tent_manager.gd", "r") as f:
        content = f.read()

    replacement = """
			# Ensure we only save sleeping or loosely dropped items, not ones currently held
			if item.freeze and item.get_multiplayer_authority() != 1:
				print("DEBUG: Skipping item ", item.name, " because it is frozen and authority is ", item.get_multiplayer_authority())
				continue

			if item.data_path == "":
				print("DEBUG: Skipping item ", item.name, " because data_path is empty")
				continue

			# Add an upward offset to reliably detect items resting on the floor
			query.position = item.global_position + Vector3(0, 0.5, 0)
			var results = space_state.intersect_point(query)

			var inside_this_tent = false
			print("DEBUG: Checking item ", item.name, " at global pos ", item.global_position, " (query ", query.position, ")")
			print("DEBUG: intersect_point results: ", results)
			for res in results:
				print("DEBUG: found collider ", res.collider, " parent ", res.collider.get_parent())
				if res.collider is Area3D and res.collider.get_parent() == tent:
					inside_this_tent = true
					break

			if inside_this_tent:
				print("DEBUG: ITEM IS INSIDE TENT ", item.name)
"""

    # We will just replace the inner loop
    import re
    # find the block starting with "# Ensure we only save" to "inside_this_tent = true\n\t\t\t\t\t\tbreak"
    pattern = r"# Ensure we only save sleeping.*?break"
    content = re.sub(pattern, replacement.strip(), content, flags=re.DOTALL)

    with open("scripts/tent_manager.gd", "w") as f:
        f.write(content)

modify_tent_manager()
