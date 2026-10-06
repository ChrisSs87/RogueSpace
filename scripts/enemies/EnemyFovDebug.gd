extends MeshInstance3D

## Cono de desarrollo derivado de los mismos datos de FOV que Enemy.gd.
## La malla local apunta a -Z, el forward lógico estándar de Godot 3D.
const ARC_SEGMENTS: int = 24

var _last_range_m: float = -1.0
var _last_angle_deg: float = -1.0
var _last_color: Color = Color.TRANSPARENT


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(_delta: float) -> void:
	if not DebugConfig.perception_debug_enabled:
		visible = false
		return

	var enemy := get_parent()
	if enemy == null or not enemy.has_method("get_debug_fov_range_m"):
		visible = false
		return

	visible = true
	var range_m: float = enemy.get_debug_fov_range_m()
	var angle_deg: float = enemy.get_debug_fov_angle_deg()
	var color: Color = enemy.get_debug_fov_color()
	if is_equal_approx(range_m, _last_range_m) and is_equal_approx(angle_deg, _last_angle_deg) and color.is_equal_approx(_last_color):
		return

	_last_range_m = range_m
	_last_angle_deg = angle_deg
	_last_color = color
	_rebuild_cone(range_m, angle_deg, color)


func _rebuild_cone(range_m: float, angle_deg: float, color: Color) -> void:
	var immediate_mesh := ImmediateMesh.new()
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var half_angle_rad: float = deg_to_rad(angle_deg * 0.5)
	for index in range(ARC_SEGMENTS):
		var ratio: float = float(index) / float(ARC_SEGMENTS)
		var next_ratio: float = float(index + 1) / float(ARC_SEGMENTS)
		var angle: float = lerpf(-half_angle_rad, half_angle_rad, ratio)
		var next_angle: float = lerpf(-half_angle_rad, half_angle_rad, next_ratio)
		immediate_mesh.surface_add_vertex(Vector3.ZERO)
		immediate_mesh.surface_add_vertex(Vector3(sin(angle) * range_m, 0.0, -cos(angle) * range_m))
		immediate_mesh.surface_add_vertex(Vector3(sin(next_angle) * range_m, 0.0, -cos(next_angle) * range_m))
	immediate_mesh.surface_end()
	mesh = immediate_mesh

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = material
