extends Resource
class_name PaperData

@export var artData: ArtifactData 

var final_artifact_icon: Texture2D = artData.result_item.item_icon
var artifact_p1_icon: Texture2D = artData.required_parts[0].item_icon
var artifact_p2_icon: Texture2D = artData.required_parts[1].item_icon
var artifact_p3_icon: Texture2D
