extends Node3D
class_name LightSource

## LightSource.gd
## Fuente de luz puntual (ej. una antorcha) para el canal LÓGICO de
## iluminación (ver LightingManager.gd). Se registra sola al entrar en la
## escena. intensity = aporte de luz en el centro (0-5); radius = metros
## hasta donde llega, con caída lineal continua. LightingManager suma los
## aportes continuos y recién allí los cuantiza al nivel lógico 0-5.
##
## También arma una representación visual BARATA (dos mallas sin sombra,
## nada de luces/sombras reales de Godot) solo para que el foco se pueda
## reconocer a simple vista durante las pruebas — un núcleo emisivo chico
## en el centro, y una esfera grande y muy translúcida del tamaño de
## radius, para que se note "acá empieza/termina el área". Esto es
## puramente decorativo: el cálculo de luz que usa Perception es el de
## get_light_contribution_at(), no depende en nada de estas mallas.

@export var intensity: int = 5
@export var radius: float = 5.0


func _ready() -> void:
	LightingManager.register_light_source(self)
	_build_visual_indicator()


func _exit_tree() -> void:
	LightingManager.unregister_light_source(self)


func get_light_contribution_at(position: Vector3) -> float:
	var distance: float = global_position.distance_to(position)
	if distance >= radius or radius <= 0.0:
		return 0.0
	var falloff: float = 1.0 - (distance / radius)
	return float(intensity) * falloff


func _build_visual_indicator() -> void:
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.25
	core_mesh.height = 0.5
	core.mesh = core_mesh
	var core_material := StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.albedo_color = Color(1.0, 0.85, 0.4)
	core_material.emission_enabled = true
	core_material.emission = Color(1.0, 0.85, 0.4)
	core_material.emission_energy_multiplier = 2.0
	core.material_override = core_material
	add_child(core)

	var range_indicator := MeshInstance3D.new()
	var range_mesh := SphereMesh.new()
	range_mesh.radius = radius
	range_mesh.height = radius * 2.0
	range_indicator.mesh = range_mesh
	var range_material := StandardMaterial3D.new()
	range_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	range_material.albedo_color = Color(1.0, 0.85, 0.4, 0.08)
	range_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	range_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	range_indicator.material_override = range_material
	add_child(range_indicator)
