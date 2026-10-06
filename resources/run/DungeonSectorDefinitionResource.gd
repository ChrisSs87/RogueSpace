extends Resource
class_name DungeonSectorDefinitionResource

## Describe un sector lógico de un archetype. La escena física se construye
## después, mediante el template seleccionado y el assembler 6G.
@export var sector_id: StringName
@export var display_name := "Sector"
@export var template_pool: Array[DungeonTemplateResource] = []
@export var size_profiles: Array[DungeonSizeProfileResource] = []
@export var light_profile_id: StringName
@export var population_profile_id: StringName
@export var population_density := 0.0
@export var allowed_enemy_faction_tags: Array[StringName] = []
@export var required_room_roles: Array[StringName] = []
@export var preferred_room_roles: Array[StringName] = []
@export var transition_to_next_type: StringName = &""
@export var semantic_locations: Array[SemanticLocationResource] = []
