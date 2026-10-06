extends Node3D

func _ready() -> void:
	var dungeon: Node3D = $Stage6GProceduralPrototype
	while not dungeon.nav_ready:
		await get_tree().physics_frame
	dungeon.test_template_index = 1
	dungeon.test_content_profile_index = 0
	await dungeon.regenerate(62001)
	var combat_metrics: Dictionary = dungeon.get_content_slot_metrics()
	var combat_signature: String = str(combat_metrics.get("signature", ""))
	var assembly_signature: String = dungeon.get_assembly_signature()
	var combat_valid := _validate_runtime_slots(dungeon, true)
	dungeon.toggle_content_profile_from_debug()
	var exploration_metrics: Dictionary = dungeon.get_content_slot_metrics()
	var exploration_signature: String = str(exploration_metrics.get("signature", ""))
	var exploration_valid := _validate_runtime_slots(dungeon, false)
	var same_geometry: bool = assembly_signature == dungeon.get_assembly_signature()
	# El mismo seed/profile debe reconstruir idéntico placement, no sólo la
	# misma topología de dungeon.
	await dungeon.regenerate(62001)
	var replay_metrics: Dictionary = dungeon.get_content_slot_metrics()
	var deterministic: bool = exploration_signature == str(replay_metrics.get("signature", ""))
	var varied := false
	var all_valid := combat_valid and exploration_valid
	for seed in [62002, 62003]:
		await dungeon.regenerate(seed)
		all_valid = all_valid and _validate_runtime_slots(dungeon, false)
		var signature: String = dungeon.get_content_slot_metrics().signature
		varied = varied or signature != exploration_signature
	var profile_difference: bool = combat_signature != exploration_signature
	var passed: bool = all_valid and same_geometry and deterministic and varied and profile_difference
	print("6I content combat=%s exploration=%s same_geometry=%s deterministic=%s varied=%s" % [combat_signature, exploration_signature, same_geometry, deterministic, varied])
	if passed:
		print("Stage6I content placement: PASS")
		get_tree().quit(0)
	else:
		push_error("Stage6I content placement: FAIL")
		get_tree().quit(1)


func _validate_runtime_slots(dungeon: Node3D, combat_profile: bool) -> bool:
	var content_plan: ContentPlacementPlan = dungeon.current_content_plan
	var root := dungeon.get_node_or_null("ContentSlotDebug") as Node3D
	var modules := dungeon.get_node_or_null("AssembledModules") as Node3D
	if content_plan == null or root == null or modules == null or not content_plan.is_valid() or root.get_child_count() != content_plan.selected_slots.size():
		return false
	var seen: Dictionary = {}
	var categories: Dictionary = {}
	for slot in content_plan.selected_slots:
		var role: StringName = dungeon.current_plan.module_types.get(slot.node_id, &"")
		if seen.has(slot.unique_id) or role in [&"START", &"EXIT"] or not slot.occupied:
			return false
		seen[slot.unique_id] = true
		categories[slot.category] = true
		if combat_profile != (slot.category == &"ENCOUNTER"):
			return false
		var marker := root.get_node_or_null(NodePath(String(slot.unique_id).replace(":", "_"))) as MeshInstance3D
		var module := modules.get_node_or_null(NodePath(String(slot.node_id))) as Node3D
		if marker == null or module == null or marker.global_position.distance_to(slot.global_transform.origin) > 0.01:
			return false
		for child in module.get_children():
			if child is Marker3D and slot.global_transform.origin.distance_to((child as Marker3D).global_position) < slot.connector_clearance_m:
				return false
	if combat_profile:
		return categories.has(&"ENCOUNTER")
	return not categories.has(&"ENCOUNTER") and not categories.is_empty()
