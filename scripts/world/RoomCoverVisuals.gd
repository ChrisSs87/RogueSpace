extends RefCounted

## BoxMesh details only: no extra collider, bake proxy, light or shader.
## The existing solid CSG box remains the sole conservative bake source.
static func dress(cover: LogicalCover, variant: RoomCoverVariantResource) -> void:
	var accent := StandardMaterial3D.new()
	accent.albedo_color = variant.accent_color
	var size := variant.size
	match variant.family:
		RoomCoverVariantResource.Family.CONSOLE:
			_box(cover,"Display",Vector3(size.x*0.72,size.y*0.24,0.025),Vector3(0,size.y*0.23,-size.z*0.5+0.015),accent)
			_box(cover,"Controls",Vector3(size.x*0.6,0.025,size.z*0.25),Vector3(0,size.y*0.5-0.015,-size.z*0.2),accent)
		RoomCoverVariantResource.Family.MACHINERY:
			for index in 3:
				_box(cover,"Vent%d" % index,Vector3(size.x*0.7,0.08,0.025),Vector3(0,size.y*(0.15-index*0.15),-size.z*0.5+0.015),accent)
			_box(cover,"ServicePanel",Vector3(size.x*0.4,size.y*0.16,0.025),Vector3(0,size.y*0.35,-size.z*0.5+0.015),accent)
		RoomCoverVariantResource.Family.CONTAINER:
			for side in [-1,1]:
				_box(cover,"Band%d" % side,Vector3(size.x,0.06,0.025),Vector3(0,side*size.y*0.3,-size.z*0.5+0.015),accent)

static func _box(parent: Node3D, label: String, size: Vector3, position: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var detail := MeshInstance3D.new()
	detail.name = label
	detail.mesh = mesh
	detail.material_override = material
	detail.position = position
	parent.add_child(detail)
