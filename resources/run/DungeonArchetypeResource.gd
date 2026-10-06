extends Resource
class_name DungeonArchetypeResource

## Identidad data-driven de una familia de dungeon. No conoce el assembler ni
## nombres de biomas dentro de código: el director sólo consume estos datos.
@export var archetype_id: StringName
@export var display_name := "Dungeon Archetype"
@export_range(1, 8) var sector_count_min := 1
@export_range(1, 8) var sector_count_max := 1
@export var sectors: Array[DungeonSectorDefinitionResource] = []
@export var sector_paths: Array[DungeonSectorPathResource] = []
@export var semantic_locations: Array[SemanticLocationResource] = []
@export var allowed_enemy_faction_tags: Array[StringName] = []
@export var light_profile_id: StringName
@export var population_profile_id: StringName
@export var population_density := 0.0
@export var required_room_roles: Array[StringName] = []
@export var preferred_room_roles: Array[StringName] = []
