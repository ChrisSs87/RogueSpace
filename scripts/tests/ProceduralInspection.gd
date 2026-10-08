extends CanvasLayer

## Debug-only observer of the real assembly and DungeonPlan. No generation,
## navigation, player transforms or run/combat state are owned here.
class LogicalMap extends Control:
	var nodes := {}
	var edges: Array = []
	var bounds := Rect2()
	var zoom_scale := 1.0
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.035,0.05,0.95))
		if nodes.is_empty():
			return
		var scale_factor: float = minf((size.x-80)/maxf(bounds.size.x,1),(size.y-100)/maxf(bounds.size.y,1))
		scale_factor *= zoom_scale
		var offset: Vector2 = size*0.5 - bounds.get_center()*scale_factor
		for edge in edges:
			if nodes.has(edge[0]) and nodes.has(edge[1]):
				draw_line(nodes[edge[0]].point*scale_factor+offset,nodes[edge[1]].point*scale_factor+offset,Color(0.65,0.72,0.8),2)
		for id in nodes:
			var entry: Dictionary = nodes[id]
			var p: Vector2 = entry.point*scale_factor+offset
			draw_circle(p,5,entry.color)
			draw_string(ThemeDB.fallback_font,p+Vector2(7,-5),entry.label,HORIZONTAL_ALIGNMENT_LEFT,-1,13,entry.color)
		draw_string(ThemeDB.fallback_font,Vector2(16,24),"REAL LINKS | START cyan / EXIT green / COMMAND gold / DISTRIBUTOR orange / ROOM teal",HORIZONTAL_ALIGNMENT_LEFT,-1,14)

var stage: Node3D
var top_camera: Camera3D
var player_camera: Camera3D
var info: Label
var logical_map: LogicalMap
var new_seed: Button
var next_sector: Button
var busy := false
var top_active := false
var assembly_key := ""
var bounds := AABB()


func _ready() -> void:
	# Existing CombatUI/RewardUI use layer 1: gameplay UI stays above debug.
	layer = 0
	stage = get_parent()
	player_camera = stage.get_node("Player/Head/Camera3D")
	stage.get_node("DebugHUD").visible = false
	top_camera = Camera3D.new()
	top_camera.name = "InspectionCamera"
	top_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	top_camera.rotation_degrees = Vector3(-90,0,0)
	add_child(top_camera)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := VBoxContainer.new()
	panel.position = Vector2(20,90)
	root.add_child(panel)
	info = Label.new()
	info.add_theme_font_size_override("font_size",16)
	panel.add_child(info)
	var views := HBoxContainer.new()
	panel.add_child(views)
	_button(views,"PLAYER VIEW",player_view)
	_button(views,"TOP VIEW",top_view)
	_button(views,"LOGICAL MAP",toggle_map)
	_button(views,"ZOOM +",func(): zoom(0.8))
	_button(views,"ZOOM -",func(): zoom(1.25))
	_button(views,"FIT",fit)
	var actions := HBoxContainer.new()
	panel.add_child(actions)
	new_seed = _button(actions,"NEW SEED",_new_seed)
	next_sector = _button(actions,"NEXT SECTOR",_next_sector)
	logical_map = LogicalMap.new()
	logical_map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logical_map.offset_left = 20
	logical_map.offset_right = -20
	logical_map.offset_top = 290
	logical_map.offset_bottom = -20
	logical_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logical_map.hide()
	root.add_child(logical_map)


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(116,48)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _process(_delta: float) -> void:
	# Legacy stage may create more than one diagnostic layer while regenerating.
	# Hide all of them locally; do not change the shared prototype lifecycle.
	for child in stage.get_children():
		if child is CanvasLayer and child.has_node("Stage6GDebug"):
			child.visible = false
	if stage.sector_run == null:
		return
	var index: int = stage.current_sector_index
	info.text = "VARKHEM V2.1.1 | SEED %d | EFFECTIVE %d | SIZE %s\nSECTOR %s %d/%d | TEMPLATE %s | ATTEMPT %d | NAV %s" % [stage.seed,stage.sector_effective_seed,stage.sector_run.sector_size_profiles[index].size_id,stage.sector_run.get_sector(index).sector_id,index+1,stage.sector_run.sector_count(),stage.get_active_template_id(),stage.sector_retry_index,stage.nav_ready]
	if stage.current_plan != null:
		var decisions := 0
		for id in stage.current_plan.links:
			if stage.current_plan.links[id].size() > 1: decisions += 1
		info.text += "\nMODULES %d | DISTRIBUTORS %d | COMMAND objective pending V2.2" % [stage.module_count,decisions]
	new_seed.disabled = busy or not stage.nav_ready
	next_sector.disabled = busy or not stage.nav_ready or index >= stage.sector_run.sector_count()-1
	if not stage.nav_ready:
		logical_map.nodes.clear()
		logical_map.queue_redraw()
		assembly_key = ""
		return
	var key: String = "%d/%d/%s" % [stage.seed,index,stage.get_assembly_signature()]
	if key != assembly_key:
		assembly_key = key
		refresh_geometry()
		fit()
	if top_active:
		top_camera.make_current()


func refresh_geometry() -> void:
	var modules := stage.get_node_or_null("AssembledModules")
	if modules == null or modules.get_child_count() == 0:
		return
	bounds = stage._world_bounds(modules.get_child(0))
	logical_map.nodes.clear()
	logical_map.edges.clear()
	var commands := {}
	for location in stage.current_plan.semantic_locations:
		if location.definition.semantic_id == &"COMMAND_ROOM":
			commands[location.node_id] = true
	var decisions := 0
	for module in modules.get_children():
		bounds = bounds.merge(stage._world_bounds(module))
		var id := StringName(module.name)
		var role: StringName = stage.current_plan.module_types.get(id,&"")
		var distributed: bool = stage.current_plan.links.get(id,[]).size() > 1
		var color := Color(0.8,0.8,0.8)
		var suffix := ""
		if role == &"START": color = Color.CYAN; suffix = " START"
		elif role == &"EXIT": color = Color.GREEN; suffix = " EXIT"
		elif commands.has(id): color = Color.GOLD; suffix = " COMMAND"
		elif distributed: color = Color.ORANGE; suffix = " DIST"; decisions += 1
		elif role in [&"ROOM",&"SIDE_ROOM"]: color = Color.TURQUOISE; suffix = " ROOM"
		var label: String = String(id).trim_prefix("NODE_")
		if not suffix.is_empty():
			label = suffix.strip_edges()
		logical_map.nodes[id] = {"point":Vector2(module.global_position.x,module.global_position.z),"color":color,"label":label}
	for parent in stage.current_plan.links:
		for child in stage.current_plan.links[parent]:
			logical_map.edges.append([parent,child])
	logical_map.bounds = Rect2(Vector2(bounds.position.x,bounds.position.z),Vector2(bounds.size.x,bounds.size.z))
	logical_map.queue_redraw()
	logical_map.tooltip_text = "Modules %d | Distributors %d | Seed %d" % [modules.get_child_count(),decisions,stage.seed]


func fit() -> void:
	logical_map.zoom_scale = 1.0
	logical_map.queue_redraw()
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x/maxf(viewport_size.y,1)
	# Fit into the visible area BELOW the touch/debug controls, not behind them.
	var reserved_height := minf(290,viewport_size.y*0.5)
	var usable_fraction := (viewport_size.y-reserved_height)/maxf(viewport_size.y,1)
	top_camera.size = maxf(bounds.size.z/usable_fraction,bounds.size.x/aspect)*1.15
	top_camera.size = maxf(top_camera.size,10)
	top_camera.global_position = bounds.get_center()+Vector3(0,maxf(bounds.size.x,bounds.size.z)+10,0)
	top_camera.global_position.z -= top_camera.size*reserved_height/(2*maxf(viewport_size.y,1))
	top_camera.far = top_camera.global_position.y-bounds.position.y+100


func top_view() -> void:
	top_active = true
	top_camera.make_current()


func player_view() -> void:
	top_active = false
	player_camera.make_current()


func zoom(factor: float) -> void:
	top_camera.size = clampf(top_camera.size*factor,5,2000)
	logical_map.zoom_scale = clampf(logical_map.zoom_scale/factor,0.25,8)
	logical_map.queue_redraw()


func toggle_map() -> void:
	logical_map.visible = not logical_map.visible
	logical_map.queue_redraw()


func _new_seed() -> void:
	if busy:
		return
	busy = true
	await stage.regenerate_from_debug()
	busy = false


func _next_sector() -> void:
	if busy:
		return
	busy = true
	await stage.advance_sector_from_debug()
	busy = false
