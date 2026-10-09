extends RefCounted
class_name ContentPatrolRoutes

## Bounded route preparation, after the real bake. Enemy remains sole AI owner.
static func build(slot: DungeonContentSlot, plan: DungeonPlan, root: Node3D, navigation_map: RID, capsule: Shape3D) -> Dictionary:
	var spec := slot.definition.patrol
	if spec == null or spec.footprint_points.size() < 2 or plan == null or not navigation_map.is_valid():
		return {"error":"missing route definition or synchronized navigation"}
	var definition: ModuleDefinitionResource = plan.module_definitions.get(slot.node_id)
	if definition == null or not plan.assembly_transforms.has(slot.node_id):
		return {"error":"missing assembled module"}
	var transform: Transform3D = plan.assembly_transforms[slot.node_id]
	var inverse := transform.affine_inverse()
	var points: Array[Vector3] = []
	for fraction in spec.footprint_points:
		var point := transform * Vector3(fraction.x * definition.footprint_size.x, 0, fraction.y * definition.footprint_size.y)
		point.y = slot.global_transform.origin.y
		points.append(point)
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = capsule
	shape_query.collision_mask = 1
	var space := root.get_world_3d().direct_space_state
	var route_points: Array[Vector3] = [slot.global_transform.origin]
	route_points.append_array(points)
	for index in route_points.size():
		var from := route_points[index]
		var to := route_points[(index+1) % route_points.size()]
		var projected_from := NavigationServer3D.map_get_closest_point(navigation_map, from)
		var projected_to := NavigationServer3D.map_get_closest_point(navigation_map, to)
		if Vector2(projected_to.x-to.x, projected_to.z-to.z).length() > 0.12:
			return {"error":"waypoint outside navigation"}
		var path := NavigationServer3D.map_get_path(navigation_map, projected_from, projected_to, true)
		if path.is_empty(): return {"error":"unreachable waypoint"}
		for point in path:
			var local: Vector3 = inverse * point
			if absf(local.x) > definition.footprint_size.x*0.5 or absf(local.z) > definition.footprint_size.y*0.5:
				return {"error":"route leaves assigned module"}
		# Routes are deliberately straight inside the validated module. Sweep the
		# real capsule, not a point or AABB, across every segment, above floor contact.
		shape_query.transform = Transform3D(Basis.IDENTITY, from+Vector3.UP*0.04)
		shape_query.motion = to-from
		if not space.intersect_shape(shape_query).is_empty() or space.cast_motion(shape_query)[0] < 1.0:
			return {"error":"capsule route obstructed"}
	return {"points":points, "spec":spec}
