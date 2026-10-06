extends Node

## Read-only diagnostic for the historical Stage6J Varkhem sample. It makes no
## changes to generation, templates, semantic placement, or physical assembly.
const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const BASE := preload("res://resources/run/test_archetypes/VarkhemBase.tres")


func _ready() -> void:
	var ranges := [Vector2i(63001, 63020), Vector2i(65001, 65020), Vector2i(65021, 65060)]
	var grouped: Dictionary = {}
	var total_valid := 0
	var total_invalid := 0
	var invalid_seeds: Array[String] = []
	for interval in ranges:
		for seed in range(interval.x, interval.y + 1):
			var result := _inspect_seed(seed)
			if bool(result.valid):
				total_valid += 1
			else:
				total_invalid += 1
				invalid_seeds.append(String(result.label))
				var reason: String = String(result.reason)
				grouped[reason] = int(grouped.get(reason, 0)) + 1
	print("6K.2 historical 6J diagnostic valid=%d invalid=%d grouped=%s" % [total_valid, total_invalid, grouped])
	if not invalid_seeds.is_empty():
		print("6K.2 historical invalid seeds:\n%s" % "\n".join(invalid_seeds))
	print("Stage6K.2 historical 6J diagnostic: COMPLETE")
	get_tree().quit(0)


func _inspect_seed(seed: int) -> Dictionary:
	var director: DungeonArchetypeDirector = DIRECTOR.new()
	var run: DungeonSectorRun = director.create_sector_run(BASE, seed)
	var valid := run.initialization_error.is_empty()
	var reports: Array[String] = []
	var first_reason := run.initialization_error
	for sector_index in range(run.sector_count()):
		var sector: DungeonSectorDefinitionResource = run.get_sector(sector_index)
		var profile: DungeonSizeProfileResource = run.sector_size_profiles[sector_index]
		var template: DungeonTemplateResource = director.get_sector_template(run, sector_index)
		var plan := director.build_sector_plan(run, sector_index)
		var plan_valid: bool = plan != null and plan.is_valid()
		if not plan_valid:
			valid = false
			var generation_error := plan.generation_error if plan != null else "null_plan"
			var semantic_error := plan.semantic_error if plan != null else "null_plan"
			if first_reason.is_empty():
				first_reason = "generation=%s semantic=%s" % [generation_error, semantic_error]
		var rules: Array[String] = []
		if template != null:
			for rule in template.grammar_rules:
				if rule != null:
					rules.append("%s:%d..%d consecutive=%d" % [rule.role, rule.min_count, rule.max_count, rule.max_consecutive])
		var sequence: Array[String] = []
		var reserved: Array[String] = []
		if plan != null:
			for node_id in plan.module_ids:
				sequence.append("%s=%s" % [node_id, plan.module_types.get(node_id, &"")])
			for location in plan.semantic_locations:
				reserved.append("%s@%s(depth=%d)" % [location.definition.semantic_id, location.node_id, location.depth_from_start])
		reports.append("sector=%d id=%s profile=%s modules=%d..%d template=%s valid=%s rules=[%s] sequence=[%s] reserved=[%s] generation=%s semantic=%s" % [sector_index, sector.sector_id if sector != null else &"", profile.size_id if profile != null else &"", template.min_modules if template != null else -1, template.max_modules if template != null else -1, template.resource_path if template != null else "null", plan_valid, "; ".join(rules), ", ".join(sequence), ", ".join(reserved), plan.generation_error if plan != null else "null_plan", plan.semantic_error if plan != null else "null_plan"])
	var labels: Array[String] = []
	for sector in run.sector_definitions:
		labels.append(String(sector.sector_id))
	var label := "seed=%d sectors=%s initialization=%s\n%s" % [seed, ",".join(labels), run.initialization_error, "\n".join(reports)]
	return {"valid": valid, "reason": first_reason if not first_reason.is_empty() else "valid", "label": label}
