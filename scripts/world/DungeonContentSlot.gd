extends RefCounted
class_name DungeonContentSlot

var unique_id: StringName
var category: StringName
var node_id: StringName
var global_transform := Transform3D.IDENTITY
var tags: Array[StringName] = []
var enabled := true
var allows_multiple_occupants := false
var occupied := false
var occupant_id: StringName
var connector_clearance_m := 1.2
var definition: ContentSlotDefinitionResource
