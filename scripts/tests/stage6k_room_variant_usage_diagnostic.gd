extends Node3D

const STAGE_SCRIPT := preload("res://scripts/world/Stage6GProceduralPrototype.gd")


func _ready() -> void:
	var dungeon: Node3D = STAGE_SCRIPT.new()
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1
	dungeon.initial_seed = 65001
	add_child(dungeon)
	while dungeon.nav_sync_state == "SYNCING" or dungeon.nav_sync_state == "IDLE":
		await get_tree().physics_frame
	var standard := 0
	var compact := 0
	var compact_required := 0
	var compact_optional := 0
	var invalid_sectors := 0
	for seed in range(65001, 65021):
		await dungeon.regenerate(seed)
		for sector_index in range(dungeon.sector_run.sector_count()):
			if dungeon.assembly_valid:
				var result := _count_room_choices(dungeon)
				standard += int(result.standard)
				compact += int(result.compact)
				compact_required += int(result.required)
				compact_optional += int(result.optional)
			else:
				invalid_sectors += 1
			if sector_index < dungeon.sector_run.sector_count() - 1:
				await dungeon.advance_sector_from_debug()
	print("6K.2 ROOM VARIANT DIAG standard=%d compact=%d compact_required=%d compact_optional=%d invalid_sectors=%d" % [standard, compact, compact_required, compact_optional, invalid_sectors])
	get_tree().quit(0)


func _count_room_choices(dungeon: Node3D) -> Dictionary:
	var result: Dictionary = {"standard": 0, "compact": 0, "required": 0, "optional": 0}
	var root := dungeon.get_node_or_null("AssembledModules") as Node3D
	var placed_before: Dictionary = {}
	for entry in dungeon.assembly_trace:
		if entry.get("status", "") != "PLACED":
			continue
		var id: StringName = entry.get("id", &"")
		var definition_id: StringName = entry.get("definition", &"")
		if definition_id == &"base_room":
			result.standard += 1
		elif definition_id == &"base_room_compact":
			result.compact += 1
			var parent := root.get_node_or_null(NodePath(String(entry.parent))) as Node3D
			var source := parent.get_node_or_null(NodePath(String(entry.source_connector))) as Marker3D
			var standard_definition: ModuleDefinitionResource = _standard_variant(dungeon.current_plan.module_definition_variants.get(id, []))
			var candidate: Node3D = dungeon._make_module(id, entry.role, standard_definition)
			root.add_child(candidate)
			var incoming: Marker3D = dungeon._find_available_connector(candidate, "in", {})
			dungeon._align_connectors(candidate, incoming, source)
			var seam: Dictionary = dungeon._validate_connector_contract(source, incoming)
			var conflicts: Array = dungeon._overlap_details(candidate, placed_before)
			if bool(seam.valid) and conflicts.is_empty():
				result.optional += 1
			else:
				result.required += 1
			root.remove_child(candidate)
			candidate.free()
		var placed_module := root.get_node_or_null(NodePath(String(id))) as Node3D
		if placed_module != null:
			placed_before[id] = placed_module
	return result


func _standard_variant(variants: Array) -> ModuleDefinitionResource:
	for variant in variants:
		if variant.stable_id == &"base_room":
			return variant
	return null
