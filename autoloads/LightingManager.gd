extends Node

## LightingManager.gd (autoload)
## Canonical exposure: get_exposure_at() uses 0..10. Existing perception curves
## use get_light_level_at(), an explicit 0..5 compatibility adapter of that sum.
## Punto único para consultar exposición en cualquier posición
## del mundo. Combina una luz AMBIENTAL global con FUENTES puntuales
## registradas (antorchas, etc.) — sin grilla, sin asignar nada al azar por
## metro. El generador procedural futuro puede llenar esto agregando
## LightSource nodes a la escena y ajustando ambient_light_level, sin tocar
## este script.
##
## IMPORTANTE (aclaración del usuario, válida para futuras etapas): esto es
## un canal de datos LÓGICO para gameplay. Todavía no está sincronizado con
## la iluminación VISUAL real de la escena (DirectionalLight/WorldEnvironment)
## Legacy — un lugar puede reportar light_level 1 acá y verse iluminado como nivel
## 5 en pantalla. Sincronizar ambos es un requisito pendiente para una etapa
## posterior. Varkhem V2.3-A activa explícitamente fuentes coherentes por perfil;
## las fuentes legacy y otros biomas conservan su comportamiento anterior.

## Luz base del lugar cuando no hay ninguna fuente puntual cerca. Cada
## escena/bioma puede pisar esto llamando a set_ambient_light_level() al
## arrancar (todavía no hay biomas reales, así que por ahora es un único
## valor global editable acá).
@export var ambient_light_level: int = 1

var _sources: Array = []
var _biome_profile: BiomeLightingProfileResource
var _profile_owner := 0

## Explicit scope prevents a departed Varkhem scene leaking its ambient into Ship/Horvex.
func configure_biome(profile: BiomeLightingProfileResource, owner: Node) -> void:
	_biome_profile = profile.duplicate(true) if profile != null else null
	_profile_owner = owner.get_instance_id()
	var cleanup := _release_profile.bind(_profile_owner)
	if not owner.tree_exited.is_connected(cleanup): owner.tree_exited.connect(cleanup,CONNECT_DEFERRED)

func _release_profile(owner_id: int) -> void:
	if owner_id == _profile_owner:
		_biome_profile = null
		_profile_owner = 0

func get_ambient_exposure() -> float:
	return _biome_profile.ambient if _biome_profile != null else float(ambient_light_level)*2.0


func set_ambient_light_level(level: int) -> void:
	ambient_light_level = clampi(level, 0, 5)


func register_light_source(source: Node) -> void:
	if source not in _sources:
		_sources.append(source)


func unregister_light_source(source: Node) -> void:
	_sources.erase(source)


## Nivel de luz (0-5) en una posición del mundo: suma la luz ambiental y
## los aportes continuos de todas las fuentes puntuales registradas. Recién
## al final cuantiza y limita el resultado, para que las fuentes superpuestas
## no sufran redondeos prematuros. Barato: solo resta de posiciones, sin
## física ni raycasts.
func get_light_level_at(position: Vector3) -> int:
	# Existing species curves remain 0..5; conversion happens AFTER aggregation.
	return clampi(roundi(get_exposure_at(position)/2.0),0,5)

## Canonical 0..10 exposure. Legacy sources are adapted, not duplicated.
func get_exposure_at(position: Vector3) -> float:
	var level := get_ambient_exposure()
	for source in _sources:
		if not is_instance_valid(source):
			continue
		level += source.get_light_contribution_at(position)*2.0
	return clampf(level,0.0,10.0)

## Read-only diagnostic, same registered sources and quantization as perception.
func get_exposure_diagnostic(position: Vector3) -> Dictionary:
	var total := get_ambient_exposure()
	var maximum := 0.0
	var principal := "AMBIENT"
	var principal_label := "AMBIENT"
	for source in _sources:
		if not is_instance_valid(source): continue
		var contribution: float = source.get_light_contribution_at(position)*2.0
		total += contribution
		if contribution > maximum:
			maximum = contribution
			principal = str(source.get_path())
			principal_label = str(source.get_meta("light_label",source.name))
	return {"level":clampi(roundi(total/2.0),0,5),"exposure":clampf(total,0,10),"continuous":total,"scale":10,"ambient":get_ambient_exposure(),"principal":principal,"principal_label":principal_label,"contribution":maximum}
