extends RefCounted
class_name DungeonTransitionSlot

var slot_id: StringName
var node_id: StringName = &"EXIT"
var transition_type: StringName
var from_sector_index := 0
var to_sector_index := -1
var global_transform := Transform3D.IDENTITY
