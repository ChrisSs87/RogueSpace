extends Node3D
const EXPERIENCE := preload("res://scenes/tests/VarkhemV213ExperienceTest.tscn")
const PROFILE := preload("res://resources/lighting/VarkhemLighting.tres")
var errors: Array[String] = []
var rows: Array = []
var stage: Node3D

func check(value: bool, message: String) -> void:
	if not value: errors.append(message)

func isolated_profile() -> BiomeLightingProfileResource:
	var copy := PROFILE.duplicate() as BiomeLightingProfileResource
	copy.sources = []
	for source in PROFILE.sources: copy.sources.append(source.duplicate(true))
	copy.variants = []
	for variant in PROFILE.variants: copy.variants.append(variant.duplicate(true))
	return copy

func ready_sector() -> bool:
	var deadline := Time.get_ticks_msec()+15000
	while not stage.nav_ready and stage.assembly_error.is_empty() and Time.get_ticks_msec() < deadline: await get_tree().physics_frame
	if not stage.nav_ready: return false
	var player: CharacterBody3D = stage.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(-500,1,-500)
	for actor in stage.get_node("RuntimeContent").get_children():
		if actor is Enemy:
			actor.set_physics_process(false)
			actor.perception_timer.stop()
	return true

func physical_signature() -> String:
	var report: Dictionary = stage.current_room_environment_report
	return var_to_str([stage.get_assembly_signature(),stage.current_plan.get_topology_signature(),stage.nav_mesh.vertices,stage.nav_mesh.get_polygon_count(),stage.current_content_plan.get_signature(),stage.current_runtime_content_report,report.get("covers",[]),report.get("distribution",[]),report.get("rooms",[])])

func _ready() -> void:
	for profile in [PROFILE,preload("res://resources/lighting/HorvexLighting.tres"),preload("res://resources/lighting/NythariLighting.tres")]:
		check(profile.validate_variant(&"OPERATIVA").is_empty(),"catalog valid "+String(profile.stable_id))
		check(not profile.validate_variant(&"FORBIDDEN").is_empty(),"unknown variant rejected")
	check(PROFILE.ambient == 3.0,"Varkhem declared ambient 3/10")
	var original_flags := PROFILE.sources.map(func(source): return source.enabled)
	var invalid := isolated_profile()
	invalid.variants[0].allowed_sources.append(&"UNAUTHORIZED")
	check(not invalid.validate_variant(&"OPERATIVA").is_empty(),"invalid source/variant combination rejected")
	invalid = isolated_profile()
	for source in invalid.sources: source.enabled = false
	check(not invalid.validate_variant(&"EMERGENCIA").is_empty(),"minimum never overrides disabled sources")
	check(PROFILE.sources.map(func(source): return source.enabled) == original_flags and PROFILE.validate_variant(&"OPERATIVA").is_empty(),"negative fixtures do not mutate shared catalogue")
	check(preload("res://resources/lighting/HorvexLighting.tres").ambient == 1.0,"Horvex preparatory ambient 1/10")
	check(preload("res://resources/lighting/NythariLighting.tres").ambient == 2.0,"Nythari preparatory ambient 2/10")
	# Legacy species retain their existing integer curve input exactly.
	for level in 6:
		LightingManager.set_ambient_light_level(level)
		check(LightingManager.get_light_level_at(Vector3.ZERO) == level and LightingManager.get_exposure_at(Vector3.ZERO) == level*2.0,"legacy scale adapter")
	LightingManager.set_ambient_light_level(1)
	stage = EXPERIENCE.instantiate()
	add_child(stage)
	if not await ready_sector():
		errors.append("initial fixture unavailable: "+stage.assembly_error)
		finish()
		return
	for seed in range(65001,65007):
		var baseline: Array[String] = []
		var deterministic := {}
		for variant_id in [&"OPERATIVA",&"REDUCIDA",&"EMERGENCIA",&"OPERATIVA"]:
			stage.lighting_variant_id = variant_id
			await stage.regenerate(seed)
			if not await ready_sector(): errors.append("generation failure"); break
			var sector := 0
			while true:
				var signature := physical_signature()
				if baseline.size() <= sector: baseline.append(signature)
				else: check(signature == baseline[sector],"geometry/nav/population/patrol/covers unchanged across variants")
				var report: Dictionary = stage.current_room_environment_report
				check(report.lighting.size() <= PROFILE.max_visual_lights,"strict visual budget")
				check(report.lighting_profile.variant == String(variant_id),"requested/effective variant")
				for light_row in report.lighting:
					var source := PROFILE.get_source(StringName(light_row.source))
					var variant := PROFILE.get_variant(variant_id)
					check(variant.allowed_sources.has(StringName(light_row.source)),"authorized source only")
					var gain: float = stage.current_sector_profiles.environment.room_light_addition
					var expected_power := clampf(source.power*gain/source.reference_room_gain*variant.power_multiplier,0,10)
					check(is_equal_approx(light_row.power_10,expected_power),"configured/effective/applied power")
					check(is_equal_approx(light_row.visual_energy,source.visual_energy*expected_power/source.power),"configured/effective/applied energy")
					check(light_row.range_m == source.range_m,"effective source range")
				var lights := stage.get_node("AssembledModules").find_children("*","Node3D",true,false).filter(func(n): return n.get_script() == preload("res://scripts/world/RoomLogicalLight.gd"))
				var active := 0
				for light in lights:
					check(light.visual.visible == light.active,"activation shared")
					if light.active: active += 1
					else: check(light.get_light_contribution_at(light.global_position+light.global_basis*light.model.direction*0.5) == 0.0,"inactive source contributes zero")
					check(light.get_node("Fixture").visible,"inactive physical fixture remains visible, not removed")
					if variant_id == &"EMERGENCIA": check(light.visual.light_color == PROFILE.get_variant(variant_id).color,"authorized red tint")
				var point: Vector3 = stage.start_point
				check(active >= PROFILE.get_variant(variant_id).minimum_active_lights,"declared minimum active sources")
				var expected := PROFILE.ambient
				for light in lights: expected += light.get_light_contribution_at(point)*2.0
				check(is_equal_approx(LightingManager.get_exposure_at(point),clampf(expected,0,10)),"single canonical sum")
				check(LightingManager.get_light_level_at(point) == clampi(roundi(expected/2.0),0,5),"existing species use explicit adapter")
				var key := "%s/%s" % [seed,sector]
				if variant_id == &"OPERATIVA":
					var lighting_signature := var_to_str(report.lighting)
					if deterministic.has(key): check(deterministic[key] == lighting_signature,"lighting deterministic")
					deterministic[key] = lighting_signature
				var started := Time.get_ticks_usec()
				for index in 1000: LightingManager.get_exposure_at(point)
				rows.append({"seed":seed,"sector":sector,"variant":String(variant_id),"lights":lights.size(),"active":active,"queries_1000_usec":Time.get_ticks_usec()-started,"population":stage.get_runtime_content_metrics().spawned.size(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"memory":Performance.get_monitor(Performance.MEMORY_STATIC)})
				if stage.current_sector_index+1 >= stage.sector_run.sector_count(): break
				await stage.advance_sector_from_debug()
				if not await ready_sector(): errors.append("transition failure"); break
				sector += 1
			if not errors.is_empty(): break
		if not errors.is_empty(): break
	stage.queue_free()
	for tick in 4: await get_tree().physics_frame
	check(LightingManager.get_ambient_exposure() == 2.0,"profile released on scene destruction")
	finish()

func finish() -> void:
	print("V23_A2_RESULT="+JSON.stringify({"valid":errors.is_empty(),"errors":errors,"rows":rows}))
	get_tree().quit(0 if errors.is_empty() else 1)
