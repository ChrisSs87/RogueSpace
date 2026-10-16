extends "res://scripts/tests/varkhem_v23_a2_validation.gd"

func _ready() -> void:
	var environment: RoomEnvironmentProfileResource = preload("res://resources/run/VarkhemRoomEnvironment.tres")
	var style := environment.visual_style
	stage = EXPERIENCE.instantiate()
	add_child(stage)
	if not await ready_sector(): errors.append("initial fixture unavailable"); finish(); return
	for spec in [[65001,0],[65002,0],[65003,0],[65006,1]]:
		for variant in [&"OPERATIVA",&"REDUCIDA",&"EMERGENCIA"]:
			var original := ""
			var original_exposure: Array = []
			var previous_styled_nodes := -1
			var original_sources := ""
			for enabled in [false,true,true]:
				environment.visual_style = style if enabled else null
				stage.lighting_variant_id = variant
				var began := Time.get_ticks_usec()
				await stage.regenerate(spec[0])
				if not await ready_sector(): errors.append("sector unavailable"); finish(); return
				if spec[1] == 1:
					await stage.advance_sector_from_debug()
					if not await ready_sector(): errors.append("basement unavailable"); finish(); return
				var generation_ms := (Time.get_ticks_usec()-began)/1000.0
				var signature := physical_signature()
				var samples: Array = []
				var modules: Node3D = stage.get_node("AssembledModules")
				for module: Node3D in modules.get_children():
					for offset in [Vector3(0,0.85,0),Vector3(2,0.85,0),Vector3(-2,0.85,0)]:
						samples.append(LightingManager.get_exposure_at(module.to_global(offset)))
				var marks := modules.find_children("MilitarySurfaceMarkings","MeshInstance3D",true,false)
				var housings := modules.find_children("MilitaryLightHousing","MeshInstance3D",true,false)
				var labels := modules.find_children("MilitarySectionLabel","Label3D",true,false)
				var sources: Array = []
				for light in modules.find_children("*","Node3D",true,false):
					if light.get_script() == preload("res://scripts/world/RoomLogicalLight.gd"):
						sources.append([light.global_transform,light.active,light.visual.visible,light.visual.light_energy,light.visual.light_color,light.visual.spot_range,light.visual.spot_angle,light.visual.shadow_enabled])
				check(sources.size() == modules.find_children("FixtureLight","SpotLight3D",true,false).size(),"one visual light for each logical source")
				if not enabled:
					original = signature
					original_exposure = samples
					original_sources = var_to_str(sources)
				else:
					check(signature == original,"geometry/nav/covers/population/patrol unchanged")
					check(samples == original_exposure,"canonical exposure exactly unchanged")
					check(var_to_str(sources) == original_sources,"visual/logical source transforms energy activation and shadows unchanged")
					check(marks.size() == stage.current_plan.module_ids.size(),"one batched markings node per module")
					check(housings.size() == stage.current_room_environment_report.lighting.size(),"no extra light sources")
					var current_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
					if previous_styled_nodes >= 0: check(current_nodes == previous_styled_nodes,"no presentation nodes accumulated on repeated generation")
					previous_styled_nodes = current_nodes
					for detail in marks+housings+labels:
						check(detail.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"no unphysical shadow")
				rows.append({"seed":spec[0],"sector":spec[1],"variant":variant,"enabled":enabled,"generation_ms":generation_ms,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"lights":housings.size() if enabled else stage.current_room_environment_report.lighting.size(),"markings":marks.size(),"labels":labels.size()})
	print("V23B_RESULT="+JSON.stringify({"valid":errors.is_empty(),"errors":errors,"rows":rows}))
	get_tree().quit(0 if errors.is_empty() else 1)
