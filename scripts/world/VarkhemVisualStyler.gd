extends RefCounted

## Opt-in static presentation. No lights/colliders/proxies/AI or RNG.
## Details sit on existing solid surfaces and never invent a closed doorway.
static func apply(plan: DungeonPlan, modules: Node3D, environment: RoomEnvironmentProfileResource, requested: StringName) -> void:
	var style := environment.visual_style
	var variant := environment.biome_lighting.get_variant(requested)
	var emergency := variant.stable_id == &"EMERGENCIA"
	var ambient := environment.biome_lighting.ambient*environment.biome_lighting.readability_per_ambient_unit
	var cache := {}
	var semantic := {}
	for location in plan.semantic_locations: semantic[location.node_id] = String(location.definition.semantic_id)
	for id in plan.module_ids:
		var module: Node3D = modules.get_node(NodePath(String(id)))
		var meaning: String = semantic.get(id,"")
		# Existing semantic Command scene uses a large floating billboard.
		# Keep its node but replace its visual role with the flush wall stencil.
		if meaning == "COMMAND_ROOM":
			var presentation := module.get_node_or_null("SemanticPresentation")
			if presentation != null:
				for old_label in presentation.find_children("*","Label3D",true,false): old_label.visible = false
		var accent: Color = style.semantic_accents.get(meaning,style.default_accent)
		if emergency: accent = variant.color
		for child in module.get_children():
			if child is CSGBox3D:
				var color := style.wall_color
				if child.name == &"Floor": color = style.floor_color
				elif String(child.name).begins_with("DoorFrame_"): color = style.frame_color
				child.material = material(cache,color,ambient)
			elif child is LogicalCover:
				for part in child.get_children():
					if part is CSGBox3D: part.material = material(cache,style.equipment_color,ambient)
		var surfaces := SurfaceTool.new()
		surfaces.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count := 0
		var wall: CSGBox3D
		# Prefer a real north wall for labels. No label on a connector opening.
		for name in ["Wall_north","Wall_south","Wall_west","Wall_east"]:
			var candidate := module.get_node_or_null(NodePath(name)) as CSGBox3D
			if candidate != null:
				if wall == null: wall = candidate
				var size := candidate.size
				var horizontal := size.x > size.z
				var normal := Vector3(0,0,-signf(candidate.position.z)) if horizontal else Vector3(-signf(candidate.position.x),0,0)
				var across := Vector3.RIGHT if horizontal else Vector3.BACK
				var center := candidate.position+normal*0.156
				center.y = 0.65
				quad(surfaces,center,across*(size.x if horizontal else size.z)*0.47,Vector3.UP*0.055,normal)
				count += 1
		# Flush painted floor lanes, not objects or a route-to-EXIT hint.
		var dimensions: Vector2 = module.get_meta("footprint_size")
		for side in [-1,1]:
			quad(surfaces,Vector3(0,0.006,side*(dimensions.y*0.5-0.6)),Vector3.RIGHT*(dimensions.x*0.5-0.45),Vector3.BACK*0.035,Vector3.UP)
			count += 1
		var detail := MeshInstance3D.new()
		detail.name = "MilitarySurfaceMarkings"
		detail.mesh = surfaces.commit()
		detail.material_override = material(cache,accent,ambient)
		detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		module.add_child(detail)
		if wall != null and style.semantic_labels.has(meaning):
			var label := Label3D.new()
			label.name = "MilitarySectionLabel"
			label.text = ("ALERTA / " if emergency else "")+String(style.semantic_labels[meaning])
			label.font_size = 40
			label.pixel_size = 0.006
			label.modulate = Color(0.55,0.60,0.53)
			label.outline_modulate = Color(0.06,0.08,0.08)
			# Muted stencil/readability channel, not a glowing light source.
			label.shaded = false
			label.no_depth_test = false
			label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			label.position = wall.position
			# Command's existing control panels occupy the middle of the wall.
			label.position.y = 1.9 if meaning == "COMMAND_ROOM" else 1.45
			if wall.size.x > wall.size.z:
				label.position.z -= signf(wall.position.z)*0.157
				label.rotation.y = 0.0 if wall.position.z < 0 else PI
			else:
				label.position.x -= signf(wall.position.x)*0.157
				label.rotation.y = PI/2 if wall.position.x < 0 else -PI/2
			module.add_child(label)
		for light in module.get_children():
			if light.get_script() != preload("res://scripts/world/RoomLogicalLight.gd"): continue
			var fixture := light.get_node("Fixture") as MeshInstance3D
			# The same active/inactive diffuser remains controlled by set_active().
			if fixture.mesh is BoxMesh:
				fixture.mesh.size = Vector3(1.8,0.05,0.28) if light.model.direction == Vector3.DOWN and light.basis == Basis.IDENTITY else Vector3(0.28,0.18,0.08)
			var housing := MeshInstance3D.new()
			housing.name = "MilitaryLightHousing"
			var box := BoxMesh.new()
			box.size = fixture.mesh.size+Vector3(0.12,0.04,0.08)
			housing.mesh = box
			housing.position.y = 0.06
			housing.material_override = material(cache,style.frame_color,ambient)
			housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			light.add_child(housing)

static func material(cache: Dictionary, color: Color, ambient: float) -> StandardMaterial3D:
	var key := color.to_html()
	if not cache.has(key):
		var result := StandardMaterial3D.new()
		result.albedo_color = color
		result.roughness = 0.85
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = ambient
		cache[key] = result
	return cache[key]

static func quad(surface: SurfaceTool, center: Vector3, x: Vector3, y: Vector3, normal: Vector3) -> void:
	var corners := [center-x-y,center+x-y,center+x+y,center-x+y]
	# Godot front faces are clockwise; choose orientation for the declared normal.
	var order := [0,2,1,0,3,2] if x.cross(y).dot(normal) > 0 else [0,1,2,0,2,3]
	for i in order:
		surface.set_normal(normal)
		surface.add_vertex(corners[i])
