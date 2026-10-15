extends "res://scripts/tests/varkhem_v23_a2_validation.gd"

func _ready() -> void:
	var environment: RoomEnvironmentProfileResource = preload("res://resources/run/VarkhemRoomEnvironment.tres")
	var configured := environment.biome_lighting
	stage = EXPERIENCE.instantiate()
	stage.initial_seed = 65003
	add_child(stage)
	if not await ready_sector():
		check(false,"initial sector unavailable")
		finish()
		return
	var baseline := {}
	for seed in [65003,65005]:
		for variant in ["V23_A","OPERATIVA","REDUCIDA","EMERGENCIA"]:
			environment.biome_lighting = null if variant == "V23_A" else configured
			stage.lighting_variant_id = &"" if variant == "V23_A" else StringName(variant)
			await stage.regenerate(seed)
			if not await ready_sector(): check(false,"sector unavailable"); break
			if seed == 65005:
				await stage.advance_sector_from_debug()
				if not await ready_sector(): check(false,"upper sector unavailable"); break
			var signature := physical_signature().sha256_text()
			if not baseline.has(seed): baseline[seed] = signature
			else: check(baseline[seed] == signature,"same geometry/nav/covers/population "+str(seed))
			var points: Array = []
			var modules: Node3D = stage.get_node("AssembledModules")
			for id in stage.current_plan.module_ids:
				var module: Node3D = modules.get_node(NodePath(String(id)))
				for offset in [Vector3.ZERO,Vector3(2,0,0),Vector3(-2,0,0),Vector3(0,0,2),Vector3(0,0,-2)]:
					var point := module.to_global(offset)
					var nav := NavigationServer3D.map_get_closest_point(stage.nav_region.get_navigation_map(),point)
					if Vector2(point.x-nav.x,point.z-nav.z).length() > 0.12: continue
					point.y = module.global_position.y+0.85
					points.append({"node":id,"offset":offset,"position":point,"light":LightingManager.get_exposure_diagnostic(point)})
			var lights: Array = []
			for light in modules.find_children("*","Node3D",true,false):
				if light.get_script() == preload("res://scripts/world/RoomLogicalLight.gd"):
					check(light.active == light.visual.visible,"logical/visual activation")
					lights.append({"path":str(light.get_path()),"active":light.active,"visual_energy":light.visual.light_energy,"color":light.visual.light_color,"position":light.global_position})
			rows.append({"seed":seed,"sector":stage.current_sector_index,"variant":variant,"points":points,"lights":lights,"physical_signature":signature})
	print("A3_SECTOR="+JSON.stringify({"errors":errors,"rows":rows,"functional":"PASS" if errors.is_empty() else "FAIL"}))
	get_tree().quit(0 if errors.is_empty() else 1)
