extends RefCounted
## Read-only architecture adapters. No markers, colliders or navigation edits.
static func sockets(module: Node3D, definition: ModuleDefinitionResource, mount: String, covers: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var size := definition.footprint_size
	if mount == "CEILING": result.append({"id":"ceiling","position":Vector3(0,1.9,0),"basis":Basis.IDENTITY})
	if mount == "WALL": result.append({"id":"wall","position":Vector3(-size.x*0.5+0.25,1.6,size.y*0.3),"basis":Basis.looking_at(Vector3.RIGHT,Vector3.UP)})
	if mount == "CONSOLE":
		for row in covers:
			if row.node != StringName(module.name) or row.family != "CONSOLE": continue
			var pos: Vector3 = row.position
			var toward := Vector3(-pos.x,0,-pos.z).normalized()
			if toward.length() < 0.001: toward = Vector3.FORWARD
			var dimensions: Vector3 = row.size
			var offset := toward*Vector3(dimensions.x,0,dimensions.z)*0.5+toward*0.05
			result.append({"id":"console_%d" % result.size(),"position":pos+offset+Vector3.UP*dimensions.y*0.25,"basis":Basis.looking_at(toward,Vector3.UP)})
	for declared in definition.lighting_sockets:
		if declared.get("mount","") != mount: continue
		var pos: Vector3 = declared.get("position",Vector3.INF)
		if absf(pos.x) >= size.x*0.5 or absf(pos.z) >= size.y*0.5 or pos.y < 0: continue
		result.append({"id":declared.get("id","authored"),"position":pos,"basis":declared.get("basis",Basis.IDENTITY)})
	return result
