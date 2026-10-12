extends StaticBody3D
class_name LogicalCover

## Dedicated physical prop body. Category is gameplay, not mesh height.
## Volume is authored in local space; keep it tight to the prop's footprint.
enum Category { HIGH, MEDIUM, LOW }
@export var category: Category = Category.MEDIUM
@export var visibility_volume := AABB(Vector3(-1,0,-0.5), Vector3(2,3,1))

func _ready() -> void:
	add_to_group("logical_cover")

func blocks_sight(from: Vector3, to: Vector3, crouched: bool) -> bool:
	if category == Category.LOW or (category == Category.MEDIUM and not crouched):
		return false
	return interposes(from, to)


func interposes(from: Vector3, to: Vector3) -> bool:
	var inverse := global_transform.affine_inverse()
	return visibility_volume.intersects_segment(inverse * from, inverse * to) != null
