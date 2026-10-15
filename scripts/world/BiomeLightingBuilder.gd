extends RefCounted
const LIGHT := preload("res://scripts/world/RoomLogicalLight.gd")
const SOCKETS := preload("res://scripts/world/LightingSocketProvider.gd")

static func build(plan: DungeonPlan, modules: Node3D, environment: RoomEnvironmentProfileResource, seed: int, requested: StringName, report: Dictionary) -> RoomLightModelResource:
	var profile := environment.biome_lighting
	var variant := profile.get_variant(requested)
	var candidates: Array[Dictionary] = []
	var semantic_by_node := {}
	for location in plan.semantic_locations: semantic_by_node[location.node_id] = location.definition.semantic_id
	for node_id in plan.module_ids:
		if plan.module_types[node_id] in [&"START",&"EXIT"]: continue
		var semantic: StringName = semantic_by_node.get(node_id,&"")
		if environment.excluded_semantic_ids.has(semantic): continue
		var module := modules.get_node(NodePath(String(node_id))) as Node3D
		for rule in profile.placement_rules:
			if not rule.get("roles",[]).has(plan.module_types[node_id]): continue
			if rule.get("semantic_only",false) and semantic == &"": continue
			if rule.has("semantics") and not rule.semantics.has(semantic): continue
			var stride: int = rule.get("depth_stride",1)
			if int(plan.node_depths.get(node_id,0)) % maxi(stride,1) != 0: continue
			var source := profile.get_source(rule.source)
			for socket in SOCKETS.sockets(module,plan.module_definitions[node_id],source.mount,report.covers):
				var key := "%s/%s/%s" % [node_id,rule.id,socket.id]
				candidates.append({"node":node_id,"semantic":semantic,"source":source,"socket":socket,"key":key,"priority":rule.get("priority",0),"supplemental":rule.get("supplemental",false),"order":String("%s/%s/%s" % [seed,profile.stable_id,key]).hash()})
	candidates.sort_custom(func(a,b): return a.priority > b.priority if a.priority != b.priority else (a.key < b.key if a.order == b.order else a.order < b.order))
	var primary := {}
	var count := 0
	var active_count := 0
	var eligible: Array[Node3D] = []
	report["lighting"] = []
	report["lit_rooms"] = []
	report["lighting_rejections"] = []
	for candidate in candidates:
		var source: LightingSourceResource = candidate.source
		var reason := ""
		if not variant.allowed_sources.has(source.stable_id): reason = "unauthorized source/variant combination"
		elif count >= profile.max_visual_lights: reason = "visual light budget"
		elif primary.has(candidate.node) and not candidate.supplemental: reason = "primary fixture already selected"
		if not reason.is_empty():
			report.lighting_rejections.append({"candidate":candidate.key,"reason":reason})
			continue
		var module := modules.get_node(NodePath(String(candidate.node))) as Node3D
		var light := LIGHT.new()
		light.show_inactive_fixture = true
		light.name = "RoomLogicalLight" if not module.has_node("RoomLogicalLight") else "SupplementalLight_%d" % count
		light.profile_id = String(profile.stable_id)
		light.addition = environment.room_light_addition
		light.model = source.create_model(light.addition,variant,profile.ambient*profile.readability_per_ambient_unit)
		light.position = candidate.socket.position
		light.basis = candidate.socket.basis
		light.set_meta("light_label",String(candidate.semantic) if candidate.semantic != &"" else String(candidate.node))
		module.add_child(light)
		var fixture := MeshInstance3D.new()
		fixture.name = "Fixture"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.2,0.05,0.15) if source.mount == "CEILING" else Vector3(0.18,0.15,0.08)
		fixture.mesh = mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = light.model.color
		fixture.material_override = material
		light.add_child(fixture)
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate.order
		light.set_active(source.enabled and light.visual.light_energy > 0 and rng.randf() < variant.activation_probability)
		light.set_meta("lighting_row",report.lighting.size())
		if source.enabled and light.visual.light_energy > 0: eligible.append(light)
		if light.active: active_count += 1
		if not candidate.supplemental: primary[candidate.node] = true
		count += 1
		if light.active and candidate.semantic != &"" and not report.lit_rooms.has(String(candidate.node)): report.lit_rooms.append(String(candidate.node))
		report.lighting.append({"node":String(candidate.node),"candidate":candidate.key,"source":String(source.stable_id),"mount":source.mount,"profile":String(profile.stable_id),"variant":String(variant.stable_id),"position":light.global_position,"direction":-light.visual.global_basis.z,"range_m":light.model.range_m,"logical_peak":light.addition*light.model.logical_peak_per_room_unit,"power_10":light.addition*light.model.logical_peak_per_room_unit*2.0,"visual_energy":light.visual.light_energy,"active":light.active,"shadows":light.visual.shadow_enabled,"half_angle_deg":light.model.cone_half_angle_deg})
	report["lighting_activation_fallbacks"] = []
	for light in eligible:
		if active_count >= variant.minimum_active_lights: break
		if light.active: continue
		light.set_active(true)
		active_count += 1
		var row: Dictionary = report.lighting[light.get_meta("lighting_row")]
		row.active = true
		if semantic_by_node.has(StringName(row.node)) and not report.lit_rooms.has(row.node): report.lit_rooms.append(row.node)
		report.lighting_activation_fallbacks.append({"candidate":row.candidate,"reason":"declared minimum active lights"})
	report["lighting_errors"] = []
	if active_count < variant.minimum_active_lights: report.lighting_errors.append("lighting minimum has no enabled authorized candidate")
	report["lighting_profile"] = {"id":String(profile.stable_id),"architecture":String(profile.architecture_id),"variant":String(variant.stable_id),"ambient_10":profile.ambient,"budget":profile.max_visual_lights,"visual_lights":count,"active_visual_lights":active_count}
	var presentation := RoomLightModelResource.new()
	presentation.ambient_readability = profile.ambient*profile.readability_per_ambient_unit
	return presentation
