extends "res://scripts/world/Stage6GProceduralPrototype.gd"

## Experiencia manual aislada para comparar los tres archetypes 6K. No forma
## parte del flujo productivo ni cambia el entry point normal del proyecto.
var _experience_panel: VBoxContainer
var _next_sector_button: Button
var _space_label: Label
var _last_ui_signature := ""
var _last_space_label := ""


func _ready() -> void:
	_create_experience_controls()
	await super._ready()
	_refresh_experience_controls()


func _process(_delta: float) -> void:
	var signature := "%d:%d:%d:%s" % [test_archetype_index, seed, current_sector_index, nav_sync_state]
	if signature != _last_ui_signature:
		_last_ui_signature = signature
		_refresh_experience_controls()
	_refresh_current_space_label()


func _floor_debug_color(kind: StringName) -> Color:
	var base := super._floor_debug_color(kind)
	var tint := Color(0.25, 0.40, 0.62, 1.0) # ABANDONED_SHIP
	if test_archetype_index == 1:
		tint = Color(0.28, 0.64, 0.42, 1.0) # VARKHEM_BASE
	elif test_archetype_index == 2:
		tint = Color(0.56, 0.25, 0.56, 1.0) # HORVEX_NEST
	return base.lerp(tint, 0.24)


func _create_experience_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ArchetypeExperienceControls"
	add_child(layer)
	_experience_panel = VBoxContainer.new()
	_experience_panel.position = Vector2(20, 130)
	_experience_panel.add_theme_constant_override("separation", 6)
	layer.add_child(_experience_panel)
	var title := Label.new()
	title.text = "6K ARCHETYPE EXPERIENCE (DEBUG)"
	title.add_theme_font_size_override("font_size", 18)
	_experience_panel.add_child(title)
	var archetypes := HBoxContainer.new()
	archetypes.add_theme_constant_override("separation", 6)
	_experience_panel.add_child(archetypes)
	for data in [["SHIP", 0], ["VARKHEM", 1], ["HORVEX", 2]]:
		var button := Button.new()
		button.text = data[0]
		button.custom_minimum_size = Vector2(120, 46)
		button.pressed.connect(_select_archetype.bind(int(data[1])))
		archetypes.add_child(button)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	_experience_panel.add_child(actions)
	var regenerate_button := Button.new()
	regenerate_button.text = "NEW SEED"
	regenerate_button.custom_minimum_size = Vector2(160, 46)
	regenerate_button.pressed.connect(_regenerate_new_seed)
	actions.add_child(regenerate_button)
	_next_sector_button = Button.new()
	_next_sector_button.text = "NEXT SECTOR"
	_next_sector_button.custom_minimum_size = Vector2(160, 46)
	_next_sector_button.pressed.connect(_advance_sector)
	actions.add_child(_next_sector_button)
	_space_label = Label.new()
	_space_label.text = "SPACE: circulation"
	_space_label.add_theme_font_size_override("font_size", 16)
	_experience_panel.add_child(_space_label)


func _select_archetype(index: int) -> void:
	test_archetype_index = index
	await regenerate(seed)
	_refresh_experience_controls()


func _regenerate_new_seed() -> void:
	await regenerate_from_debug()
	_refresh_experience_controls()


func _advance_sector() -> void:
	await advance_sector_from_debug()
	_refresh_experience_controls()


func _refresh_experience_controls() -> void:
	if _next_sector_button == null:
		return
	var has_next := sector_run != null and current_sector_index < sector_run.sector_count() - 1
	_next_sector_button.disabled = not has_next
	_next_sector_button.text = "NEXT SECTOR" if has_next else "DUNGEON COMPLETE"


func _refresh_current_space_label() -> void:
	if _space_label == null:
		return
	var player := get_node_or_null("Player") as CharacterBody3D
	if player == null or current_plan == null:
		return
	var nearest_id := StringName()
	var nearest_distance := INF
	for location in current_plan.semantic_locations:
		var distance := player.global_position.distance_squared_to(location.global_transform.origin)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest_id = location.definition.semantic_id
	var text := "SPACE: circulation"
	# Markers live at each semantic module's center. The conservative radius avoids
	# claiming a destination while the player is still travelling through a tunnel.
	if nearest_id != &"" and nearest_distance <= 49.0:
		text = "SPACE: %s" % String(nearest_id).replace("_", " ")
	if text != _last_space_label:
		_last_space_label = text
		_space_label.text = text
