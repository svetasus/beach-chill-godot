extends Node


const ITEMS_CONTAINER_PATH: String = "/root/Main/World/Containers/ItemsContainer"
const TREASURES_CONTAINER_PATH: String = "/root/Main/World/Containers/TreasuresContainer"
const PLAYERS_CONTAINER_PATH: String = "/root/Main/World/Containers/PlayersContainer/"
const TENTS_CONTAINER_PATH: String = "/root/Main/World/Containers/TentsContainer"
const LEVEL_PATH:String = "/root/Main/LevelLoaded"
const PLAYER_MARKERS_LEVEL_PATH: String = "Markers/PlayerSpawnMarkers"
const TENT_MARKERS_LEVEL_PATH: String = "Markers/TentSpawnMarkers"
const TREASURE_MARKERS_LEVEL_PATH: String = "Markers/TreasureSpawnMarkers"

const PLAYER_SCENE_PATH: String = "res://scenes/features/player.tscn"

var split_money_in_team: bool = false
