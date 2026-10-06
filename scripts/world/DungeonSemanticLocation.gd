extends RefCounted
class_name DungeonSemanticLocation

var definition: SemanticLocationResource
var node_id: StringName
var depth_from_start := 0
var is_main_path := false
var is_branch := false
var global_transform := Transform3D.IDENTITY

func get_id() -> StringName:
	return StringName("%s:%s" % [definition.semantic_id if definition != null else &"UNKNOWN", node_id])
