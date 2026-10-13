extends Node

const DIRECTOR := preload("res://scripts/world/DungeonArchetypeDirector.gd")
const STAGE := preload("res://scripts/world/Stage6GProceduralPrototype.gd")
const VARKHEM := preload("res://resources/run/test_archetypes/VarkhemBase.tres")
const FALLBACK := preload("res://resources/run/test_content_profiles/TestCombatHeavy.tres")
var errors: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print("P2B_CHECK %s %s" % [ok,label])
	if not ok: errors.append(label)

func wait_ready(stage: Node3D) -> bool:
	var deadline := Time.get_ticks_msec()+15000
	while not stage.nav_ready and Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
	return stage.nav_ready and stage.assembly_valid

func snapshot(stage: Node3D) -> String:
	return var_to_str([stage.get_assembly_signature(),stage.current_content_plan.get_signature(),stage.get_runtime_content_metrics().spawned,stage.current_room_environment_report])

func _ready() -> void:
	var archetype := VARKHEM.duplicate(true) as DungeonArchetypeResource
	var sector := archetype.sectors[0]
	var template := sector.template_pool[0]
	var initial := DIRECTOR.resolve_sector_profiles(archetype,sector,template,FALLBACK)
	check(initial.environment == archetype.room_environment_profile and initial.content == template.content_placement_profile,"null sector references preserve real Varkhem fallbacks")
	check(initial.effective.environment_source == "archetype" and initial.effective.content_source == "template","precedence origins explicit")
	check(initial.requested.archetype_environment == String(archetype.room_environment_profile.stable_id) and initial.requested.template_content == String(template.content_placement_profile.stable_id) and initial.requested.legacy_fallback_content == String(FALLBACK.stable_id),"configured fallback candidates retained independently from effective profile")
	var empty_sector := DungeonSectorDefinitionResource.new()
	var legacy := DIRECTOR.resolve_sector_profiles(null,empty_sector,null,FALLBACK)
	check(legacy.environment == null and legacy.content == FALLBACK and legacy.errors.is_empty(),"legacy defaults unchanged")
	var dimmer := archetype.room_environment_profile.duplicate(true) as RoomEnvironmentProfileResource
	dimmer.stable_id = &"TEST_SECTOR_DIMMER"
	dimmer.room_light_addition = 1 # Test-only within the existing 0..5 contract.
	var fixed := template.content_placement_profile.duplicate(true) as ContentPlacementProfileResource
	fixed.stable_id = &"TEST_SECTOR_FIXED_BUDGET"
	fixed.slot_count_ranges_by_size[&"MEDIUM"] = Vector2i(4,4)
	sector.room_environment_profile = dimmer
	sector.content_placement_profile = fixed
	var overridden := DIRECTOR.resolve_sector_profiles(archetype,sector,template,FALLBACK)
	check(overridden.environment == dimmer and overridden.content == fixed and overridden.effective.environment_source == "sector_override" and overridden.effective.content_source == "sector_override","typed sector overrides reach resolver")
	sector.population_density = 0.91
	var density := DIRECTOR.resolve_sector_profiles(archetype,sector,template,FALLBACK)
	check(density.requested.sector_density == 0.91 and density.content == fixed and density.limitations.has("DENSITY_BLOCKED_NO_APPROVED_BUDGET_CONTRACT"),"density observed, never silently converted into enemies")
	sector.room_environment_profile = RoomEnvironmentProfileResource.new()
	check(not DIRECTOR.resolve_sector_profiles(archetype,sector,template,FALLBACK).errors.is_empty(),"invalid explicit environment cannot fall back silently")
	sector.room_environment_profile = dimmer
	sector.content_placement_profile = ContentPlacementProfileResource.new()
	check(not DIRECTOR.resolve_sector_profiles(archetype,sector,template,FALLBACK).errors.is_empty(),"invalid explicit content cannot fall back silently")
	# End-to-end with production geometry, light nodes, pool and Enemy routes.
	var stage: Node3D = STAGE.new()
	stage.archetype_mode = true
	stage.test_archetype_index = 1
	stage.initial_seed = 65001
	add_child(stage)
	if not await wait_ready(stage):
		errors.append("baseline runtime unavailable")
		finish()
		return
	var baseline := snapshot(stage)
	var baseline_report: Dictionary = stage.get_sector_profile_metrics()
	check(baseline_report.applied.live_enemies == 6 and baseline_report.applied.environment == "VARKHEM_ROOM_ENVIRONMENT_B","real seed65001 baseline population/environment preserved")
	check(baseline_report.applied.density_applied == false and baseline_report.applied.budget_range == [4,6],"existing size range, density application explicitly false")
	var real_sector: DungeonSectorDefinitionResource = stage.sector_run.get_sector(0)
	var old_environment := real_sector.room_environment_profile
	var old_content := real_sector.content_placement_profile
	# Only in-memory test overrides; original .tres files remain untouched.
	real_sector.room_environment_profile = dimmer
	real_sector.content_placement_profile = fixed
	await stage._regenerate_current_sector()
	if not await wait_ready(stage):
		errors.append("override runtime unavailable")
	else:
		var applied: Dictionary = stage.get_sector_profile_metrics()
		check(applied.effective.environment == String(dimmer.stable_id) and applied.applied.environment == String(dimmer.stable_id) and applied.applied.room_light_addition == 1,"resolved lighting profile actually built")
		check(applied.effective.content == String(fixed.stable_id) and applied.applied.content == String(fixed.stable_id) and applied.applied.effective_budget == 4 and applied.applied.live_enemies == 4,"resolved content reaches real population within existing bounds")
		check(applied.applied.selected_slots == 4 and applied.applied.instantiated_reported == 4,"budget/selected/instantiated/live distinguished")
		check(applied.applied.content_status == "CONSUMED","actual runtime consumption status explicit")
		for node_id in stage.current_room_environment_report.lit_rooms:
			var module: Node3D = stage.get_node("AssembledModules").get_node(NodePath(node_id))
			check(module.get_node("RoomLogicalLight").addition == 1 and LightingManager.get_light_level_at(module.global_position) == 2,"real local light consumed, ambient retained")
		var override_signature := snapshot(stage)
		await stage._regenerate_current_sector()
		check(await wait_ready(stage) and snapshot(stage) == override_signature,"same seed/overrides deterministic")
		# Telemetry must keep applied values when configuration later changes.
		dimmer.room_light_addition = 2
		check(stage.get_sector_profile_metrics().applied.room_light_addition == 1,"applied snapshot is not merely current configuration")
		dimmer.room_light_addition = 1
	real_sector.room_environment_profile = old_environment
	real_sector.content_placement_profile = old_content
	await stage._regenerate_current_sector()
	check(await wait_ready(stage) and snapshot(stage) == baseline,"removing overrides restores exact baseline physical/content state")
	for spec in [[2,66001],[0,64005]]:
		stage.test_archetype_index = spec[0]
		await stage.regenerate(spec[1])
		check(await wait_ready(stage),"legacy archetype physically valid")
		var legacy_report: Dictionary = stage.get_sector_profile_metrics()
		check(legacy_report.applied.environment == "NOT_APPLIED" and stage.current_room_environment_report.is_empty(),"Varkhem room light does not leak into legacy biome")
		check(legacy_report.effective.environment_source == "legacy_none" and legacy_report.applied.density_applied == false,"Horvex/Ship defaults inert")
		var repeated := snapshot(stage)
		await stage.regenerate(spec[1])
		check(await wait_ready(stage) and snapshot(stage) == repeated,"legacy biome deterministic unchanged defaults")
	stage.queue_free()
	await get_tree().process_frame
	check(LightingManager._sources.is_empty(),"local light sources released, no global ambient mutation")
	finish()

func finish() -> void:
	print("P2B_RESULT="+JSON.stringify({"valid":errors.is_empty(),"checks":checks,"errors":errors}))
	get_tree().quit(0 if errors.is_empty() else 1)
