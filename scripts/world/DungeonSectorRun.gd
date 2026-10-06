extends RefCounted
class_name DungeonSectorRun

## Estado lógico de una run de sectores. No duplica HP/O2/loadout: esos datos
## siguen en RunState y por eso sobreviven a cada reconstrucción física.
var archetype: DungeonArchetypeResource
var run_seed := 0
var selected_faction: StringName
var sector_definitions: Array[DungeonSectorDefinitionResource] = []
var sector_plans: Array[DungeonPlan] = []
var sector_templates: Array[DungeonTemplateResource] = []
var sector_size_profiles: Array[DungeonSizeProfileResource] = []
var archetype_semantic_locations: Array[Array] = []
var initialization_error := ""
var completed_sectors: Dictionary = {}
## Traza reproducible del sector que finalmente llegó a materializarse. No
## duplica RunState: RunState conserva HP/O2/stats; esta run conserva la
## identidad efectiva de cada sector procedural.
var sector_retry_indices: Array[int] = []
var effective_sector_seeds: Array[int] = []

func record_effective_sector_attempt(index: int, retry_index: int, effective_seed: int, plan: DungeonPlan) -> void:
	while sector_plans.size() <= index:
		sector_plans.append(null)
	while sector_retry_indices.size() <= index:
		sector_retry_indices.append(0)
	while effective_sector_seeds.size() <= index:
		effective_sector_seeds.append(0)
	sector_plans[index] = plan
	sector_retry_indices[index] = retry_index
	effective_sector_seeds[index] = effective_seed

func sector_count() -> int:
	return sector_definitions.size()

func get_sector(index: int) -> DungeonSectorDefinitionResource:
	return sector_definitions[index] if index >= 0 and index < sector_definitions.size() else null

func is_dungeon_complete() -> bool:
	return completed_sectors.size() >= sector_definitions.size()
