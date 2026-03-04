# Using ItemSpawnPoint

## The Problem
Previously, when items were placed directly in a map scene file, late-joining clients would still see them even if the server had already destroyed them (e.g., used them in crafting an artifact). This is because pre-placed items do not exist under a `MultiplayerSpawner` from the very start of the network lifecycle, and the `destroy_item.rpc()` happens before late-joiners connect.

## The Fix
We created a new tool script: `scripts/item_spawn_point.gd`.

### How to use it in your Level
1. Open your Level Scene in the editor.
2. Find any pre-placed `Item` nodes in your scene tree.
3. Replace them by adding a new `Marker3D` node to the scene.
4. Drag and drop the `scripts/item_spawn_point.gd` script onto this `Marker3D`.
5. In the Inspector for the Marker:
   - Set the `item_data` to the Resource (e.g. `res://data/items/wood.tres`) that you want to spawn.
   - Set the `item_scene` to the base item scene (e.g. `res://scenes/features/item.tscn`).
6. Because it is a `@tool` script, you should instantly see a preview of the item mesh in the editor!

### How it works
When the game starts, the Server will automatically instance the real `Item` scene at that Marker's location, apply the `ItemData` to it, and place it directly into the `ItemsContainer` (which is monitored by the `MultiplayerSpawner_Items`). The spawner then takes care of synchronizing this item to all clients (including late joiners!) and naturally synchronizes its destruction when crafted. The Marker will delete itself so the game hierarchy stays clean.

---

# Using TreasureSpawnPoint

Treasure points follow the exact same logic as Item Spawn Points, ensuring that `MultiplayerSpawner` can network sync newly dug up loot to late joiners, while hiding the "invisible" dig spots from clients correctly.

### How to use it
1. You can place `TreasureSpawnPoint` markers in the main scene (under `World/Containers/TreasuresContainer`) or directly in level scenes.
2. Add a `Marker3D` and attach the `scripts/treasure_spawn_point.gd` script.
3. Configure the inspector variables:
   - `loot_table`: An Array of `ItemData` resources that the treasure might drop.
   - `base_item_scene`: The base `.tscn` that the loot uses (usually `baseItem.tscn`).
   - `sand_particles`: The VFX `.tscn` to play when digging.
   - `treasure_scene`: The actual `TreasurePoint` area `.tscn`.
4. The server will instantiate the real `TreasurePoint` Area3D at runtime inside `Global.TREASURES_CONTAINER_PATH` and delete the marker.
