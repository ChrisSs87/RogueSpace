extends Resource
class_name RunNodeResource
enum NodeType { DUNGEON, EVENT, ELITE, BOSS, REWARD }
@export var node_id: StringName
@export var node_type: NodeType = NodeType.DUNGEON
@export var dungeon: Resource
@export var next_node_ids: Array[StringName] = []
@export var visible: bool = true
