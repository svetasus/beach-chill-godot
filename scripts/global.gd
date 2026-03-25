extends Node


const ITEMS_CONTAINER_PATH: String = "/root/Main/World/Containers/ItemsContainer"
const TREASURES_CONTAINER_PATH: String = "/root/Main/World/Containers/TreasuresContainer"
const PLAYERS_CONTAINER_PATH: String = "/root/Main/World/Containers/PlayersContainer/"
const TENTS_CONTAINER_PATH: String = "/root/Main/World/Containers/TentsContainer"
const HOUSES_CONTAINER_PATH: String = "/root/Main/World/Containers/HousesContainer"
const HOUSE_ENTRANCES_CONTAINER_PATH: String = "/root/Main/World/Containers/HouseEntrancesContainer"
const LEVEL_PATH:String = "/root/Main/LevelLoaded"
const PLAYER_MARKERS_LEVEL_PATH: String = "Markers/PlayerSpawnMarkers"
const TENT_MARKERS_LEVEL_PATH: String = "Markers/TentSpawnMarkers"
const HOUSE_MARKERS_LEVEL_PATH: String = "Markers/HouseSpawnMarkers"
const HOUSE_ENTER_MARKERS_LEVEL_PATH: String = "Markers/HouseEnterMarkers"
const TREASURE_MARKERS_LEVEL_PATH: String = "Markers/TreasureSpawnMarkers"

const PLAYER_SCENE_PATH: String = "res://scenes/features/player.tscn"
const HIGHLIGHT_OBJECT_MAT_PATH: String = "res://resources/materials/post_process_outline.tres"

var split_money_in_team: bool = false
var account_id: String = ""
var peer_to_account: Dictionary = {}

var chat_proximity_radius: float = 20.0
