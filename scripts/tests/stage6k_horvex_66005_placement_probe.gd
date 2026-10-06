extends "res://scripts/world/Stage6GProceduralPrototype.gd"

## Probe offline: fuerza decisiones ya existentes del catálogo, únicamente
## para diagnóstico. Nunca se usa en escenas productivas.
var forced_junction_choice: Dictionary = {}


func _ready() -> void:
	# El harness llama _assemble_plan directamente; evita regeneración/bake.
	pass


func _placement_options(plan: DungeonPlan, id: StringName, kind: StringName, parent: Node3D, used: Dictionary) -> Array[Dictionary]:
	var options: Array[Dictionary] = super._placement_options(plan, id, kind, parent, used)
	if current_sector_index != 1 or not forced_junction_choice.has(id):
		return options
	var choice: Dictionary = forced_junction_choice[id]
	var result: Array[Dictionary] = []
	for option in options:
		var definition: ModuleDefinitionResource = option.definition
		var source: Marker3D = option.source
		if definition.stable_id == StringName(choice.definition) and source.name == StringName("Connector_out_%s" % choice.side):
			result.append(option)
	return result
