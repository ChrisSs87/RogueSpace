extends RefCounted
class_name ContentPlacementRuntimeConsumer

## Puente minimo entre el resultado inmutable de Content Placement y nodos de
## juego. V1 soporta exclusivamente ENCOUNTER -> Enemy; las demas categorias
## permanecen intactas para futuros consumidores equivalentes.
const ENEMY_SCENE := preload("res://scenes/enemies/Enemy.tscn")


static func consume(plan: ContentPlacementPlan, profile: ContentPlacementProfileResource, spawn_root: Node3D) -> Dictionary:
	var report: Dictionary = {
		"spawned": [],
		"duplicates": [],
		"unsupported": [],
		"invalid_payloads": [],
		"patrol_procedural_gap": [],
		"size_classification": &"SIZE_CLASSIFICATION_NOT_AVAILABLE",
	}
	if plan == null or profile == null or spawn_root == null or not plan.is_valid():
		report.error = "invalid content plan, profile, or spawn root"
		return report

	var rng := RandomNumberGenerator.new()
	rng.seed = plan.seed + int(profile.stable_id.hash()) + int(StringName("CONTENT_RUNTIME_V1").hash())
	var slots: Array[DungeonContentSlot] = plan.selected_slots.duplicate()
	slots.sort_custom(func(a: DungeonContentSlot, b: DungeonContentSlot) -> bool: return String(a.unique_id) < String(b.unique_id))
	for slot in slots:
		if slot == null:
			continue
		if slot.category != &"ENCOUNTER":
			report.unsupported.append(String(slot.unique_id))
			continue
		var existing := _find_slot_instance(spawn_root, slot.unique_id)
		if existing != null:
			report.duplicates.append(String(slot.unique_id))
			continue
		var pool := _pool_for_category(profile, slot.category)
		var entry: WeightedEntryResource = pool.choose(rng) if pool != null else null
		var resource := entry.payload as EnemyResource if entry != null else null
		if resource == null:
			report.invalid_payloads.append(String(slot.unique_id))
			continue
		var enemy := ENEMY_SCENE.instantiate() as Enemy
		if enemy == null:
			report.invalid_payloads.append(String(slot.unique_id))
			continue
		enemy.name = "Encounter_%s" % String(slot.unique_id).replace(":", "_")
		var runtime_resource := resource
		if resource.can_patrol and profile.fallback_to_idle_without_patrol_points:
			## Enemy.gd interpreta patrol_points como NodePath authored. Al no
			## existir esa declaracion en DungeonContentSlot, no fabricamos rutas
			## ni Markers; conservamos la IA existente en IDLE y lo hacemos visible.
			runtime_resource = resource.duplicate() as EnemyResource
			runtime_resource.can_patrol = false
			report.patrol_procedural_gap.append(String(slot.unique_id))
		enemy.enemy_resource = runtime_resource
		enemy.transform = spawn_root.global_transform.affine_inverse() * slot.global_transform
		enemy.set_meta("content_slot_id", slot.unique_id)
		enemy.set_meta("content_category", slot.category)
		enemy.set_meta("content_payload_id", entry.stable_id)
		enemy.set_meta("content_source_resource_path", resource.resource_path)
		spawn_root.add_child(enemy)
		report.spawned.append({
			"slot_id": slot.unique_id,
			"category": slot.category,
			"payload_id": entry.stable_id,
			"resource_path": resource.resource_path,
			"patrol_fallback": runtime_resource != resource,
			"transform": enemy.global_transform,
		})
	return report


static func _pool_for_category(profile: ContentPlacementProfileResource, category: StringName) -> WeightedPoolResource:
	for mapping in profile.runtime_category_pools:
		if mapping != null and mapping.category == category:
			return mapping.pool
	return null


static func _find_slot_instance(spawn_root: Node3D, slot_id: StringName) -> Node:
	for child in spawn_root.get_children():
		if child.get_meta("content_slot_id", &"") == slot_id:
			return child
	return null
