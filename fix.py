import re

with open("scripts/player.gd", "r") as f:
    content = f.read()

# Let's verify all occurrences of $PlayerUI are working, because if it's successfully loaded it should not be null.
# So I just fixed player_ui.tscn to have the right ext_resources.
# The user's screenshot had a parse error, and then a runtime error because of that parse error!
# Now that we fixed the missing ext_resources, the scene should parse and run correctly.
