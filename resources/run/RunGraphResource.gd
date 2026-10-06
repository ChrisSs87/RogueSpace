extends Resource
class_name RunGraphResource
@export var graph_id: StringName
@export var start_node_id: StringName
@export var nodes: Array[RunNodeResource] = []
func get_node(id: StringName) -> RunNodeResource:
	for node in nodes:
		if node != null and node.node_id == id: return node
	return null
