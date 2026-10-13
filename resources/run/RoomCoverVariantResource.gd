extends Resource
class_name RoomCoverVariantResource

## Physical box is the conservative collision/bake envelope. Visual details
## remain inside it; LogicalCover alone decides gameplay occlusion.
enum Family { CONSOLE, MACHINERY, CONTAINER }
@export var stable_id: StringName
@export var family: Family = Family.CONTAINER
@export var category: LogicalCover.Category = LogicalCover.Category.MEDIUM
@export var allowed_semantic_ids: Array[StringName] = []
@export var size := Vector3(1.8,1.1,0.9)
@export var body_color := Color(0.32,0.4,0.25)
@export var accent_color := Color(0.6,0.7,0.5)
