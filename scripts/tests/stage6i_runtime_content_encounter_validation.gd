extends Node3D

const STAGE := preload("res://scripts/world/Stage6GProceduralPrototype.gd")
const RUNTIME_CONSUMER := preload("res://scripts/world/ContentPlacementRuntimeConsumer.gd")


func _ready() -> void:
	var first := await _capture_varkhem(65001, true)
	var replay := await _capture_varkhem(65001, false)
	var sample_valid := 0
	var sample_sectors := 0
	for run_seed in range(65001, 65021):
		var capture := await _capture_varkhem(run_seed, false)
		if bool(capture.get("valid", false)):
			sample_valid += 1
		sample_sectors += int(capture.get("sectors", 0))
	var unsupported := _validate_unsupported_category()
	var deterministic: bool = first.get("plan_signature", "") == replay.get("plan_signature", "") \
		and first.get("runtime_signature", "") == replay.get("runtime_signature", "")
	var passed: bool = bool(first.get("valid", false)) and bool(replay.get("valid", false)) and deterministic and unsupported and sample_valid == 20
	print("6I runtime content first=%s replay=%s deterministic=%s unsupported=%s sample=%d/20 sectors=%d" % [first, replay, deterministic, unsupported, sample_valid, sample_sectors])
	if passed:
		print("Stage6I runtime content encounters: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6I runtime content encounters: FAIL")
		get_tree().quit(1)


func _capture_varkhem(run_seed: int, verify_duplicate: bool) -> Dictionary:
	var dungeon := STAGE.new() as Node3D
	dungeon.archetype_mode = true
	dungeon.test_archetype_index = 1 # Seleccion de UI/debug; no participa del consumidor.
	dungeon.initial_seed = run_seed
	add_child(dungeon)
	var sector_reports: Array[Dictionary] = []
	while true:
		while not dungeon.nav_ready and dungeon.assembly_error.is_empty():
			await get_tree().physics_frame
		await get_tree().process_frame
		sector_reports.append(_capture_current_sector(dungeon, verify_duplicate and sector_reports.is_empty()))
		if not dungeon.assembly_valid or dungeon.sector_run == null or dungeon.current_sector_index >= dungeon.sector_run.sector_count() - 1:
			break
		await dungeon.advance_sector_from_debug()
	var valid := not sector_reports.is_empty()
	var plan_parts: Array[String] = []
	var runtime_parts: Array[String] = []
	for sector_report in sector_reports:
		valid = valid and bool(sector_report.get("valid", false))
		plan_parts.append(str(sector_report.get("plan_signature", "")))
		runtime_parts.append(str(sector_report.get("runtime_signature", "")))
	var result: Dictionary = {
		"valid": valid,
		"plan_signature": "||".join(plan_parts),
		"runtime_signature": "||".join(runtime_parts),
		"sectors": sector_reports.size(),
		"reports": sector_reports,
	}
	dungeon.queue_free()
	await get_tree().physics_frame
	return result


func _capture_current_sector(dungeon: Node3D, verify_duplicate: bool) -> Dictionary:
	var result: Dictionary = {"valid": false, "assembly_error": dungeon.assembly_error}
	var plan: ContentPlacementPlan = dungeon.current_content_plan
	var root := dungeon.get_node_or_null("RuntimeContent") as Node3D
	if dungeon.assembly_valid and dungeon.nav_ready and plan != null and plan.is_valid() and root != null:
		var enemies: Array[Enemy] = []
		var all_encounters := true
		for slot in plan.selected_slots:
			all_encounters = all_encounters and slot.category == &"ENCOUNTER"
		for child in root.get_children():
			if child is Enemy:
				enemies.append(child as Enemy)
		var runtime_report: Dictionary = dungeon.get_runtime_content_metrics()
		var before_count := enemies.size()
		var duplicate_safe := true
		if verify_duplicate:
			var duplicate_report := RUNTIME_CONSUMER.consume(plan, dungeon.current_content_profile, root)
			duplicate_safe = root.get_child_count() == before_count and duplicate_report.duplicates.size() == plan.selected_slots.size()
		var enemy_valid: bool = enemies.size() == plan.selected_slots.size() and not enemies.is_empty()
		var node_counts: Dictionary = {}
		for slot in plan.selected_slots:
			node_counts[slot.node_id] = int(node_counts.get(slot.node_id, 0)) + 1
			if int(node_counts[slot.node_id]) > 1:
				enemy_valid = false
		var signature_parts: Array[String] = []
		for enemy in enemies:
			enemy_valid = enemy_valid and enemy.enemy_resource != null and not enemy.enemy_resource.can_patrol
			enemy_valid = enemy_valid and enemy._state == Enemy.State.IDLE
			enemy_valid = enemy_valid and enemy.has_method("begin_combat_approach") and enemy.has_method("refresh_encounter_contact_valid")
			signature_parts.append("%s:%s:%s" % [enemy.get_meta("content_slot_id", &""), enemy.get_meta("content_source_resource_path", ""), enemy.global_transform])
		signature_parts.sort()
		var nav_valid: bool = not runtime_report.has("navigation_rejected")
		result = {
			"valid": all_encounters and enemy_valid and duplicate_safe and nav_valid and runtime_report.patrol_procedural_gap.size() == enemies.size(),
			"plan_signature": plan.get_signature(),
			"runtime_signature": "|".join(signature_parts),
			"selected": plan.selected_slots.size(),
			"spawned": enemies.size(),
			"duplicate_safe": duplicate_safe,
			"navigation_valid": nav_valid,
			"sector": dungeon.current_sector_index,
		}
	return result


func _validate_unsupported_category() -> bool:
	var plan := ContentPlacementPlan.new()
	plan.seed = 99
	var slot := DungeonContentSlot.new()
	slot.unique_id = &"unsupported:loot"
	slot.category = &"LOOT"
	plan.selected_slots.append(slot)
	var profile := ContentPlacementProfileResource.new()
	profile.stable_id = &"UNSUPPORTED_CATEGORY_TEST"
	var root := Node3D.new()
	add_child(root)
	var report := RUNTIME_CONSUMER.consume(plan, profile, root)
	var valid: bool = root.get_child_count() == 0 and report.unsupported.size() == 1 and report.invalid_payloads.is_empty()
	root.queue_free()
	return valid
