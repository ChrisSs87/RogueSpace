extends MeshInstance3D

## Anillo de desarrollo: muestra exactamente el radio que consulta Enemy.gd
## mediante Player.get_current_noise_radius_m(). No participa en gameplay.
const RING_THICKNESS_M: float = 0.035
const RING_SEGMENTS: int = 48

var _last_radius_m: float = -1.0


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.85, 1.0, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material_override = material


func _process(_delta: float) -> void:
	if not DebugConfig.perception_debug_enabled:
		visible = false
		return

	visible = true
	var player := get_parent()
	if player == null or not player.has_method("get_current_noise_radius_m"):
		visible = false
		return

	var radius_m: float = player.get_current_noise_radius_m()
	if is_equal_approx(radius_m, _last_radius_m):
		return

	_last_radius_m = radius_m
	var ring := TorusMesh.new()
	ring.inner_radius = maxf(radius_m - RING_THICKNESS_M, 0.01)
	ring.outer_radius = radius_m + RING_THICKNESS_M
	ring.rings = RING_SEGMENTS
	ring.ring_segments = 6
	mesh = ring
