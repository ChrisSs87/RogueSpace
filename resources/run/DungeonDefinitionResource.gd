extends Resource
class_name DungeonDefinitionResource
enum GenerationMode { FIXED, TEMPLATE, PROCEDURAL }
@export var stable_id: StringName
@export var display_name := "Dungeon"
@export var generation_mode: GenerationMode = GenerationMode.FIXED
@export var fixed_scene: PackedScene
@export var template: Resource
@export var encounter_pool: Resource
@export var reward_id: StringName
