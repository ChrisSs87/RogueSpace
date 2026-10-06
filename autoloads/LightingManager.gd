extends Node

## LightingManager.gd (autoload)
## Punto único para consultar el nivel de luz (0-5) en cualquier posición
## del mundo. Combina una luz AMBIENTAL global con FUENTES puntuales
## registradas (antorchas, etc.) — sin grilla, sin asignar nada al azar por
## metro. El generador procedural futuro puede llenar esto agregando
## LightSource nodes a la escena y ajustando ambient_light_level, sin tocar
## este script.
##
## IMPORTANTE (aclaración del usuario, válida para futuras etapas): esto es
## un canal de datos LÓGICO para gameplay. Todavía no está sincronizado con
## la iluminación VISUAL real de la escena (DirectionalLight/WorldEnvironment)
## — un lugar puede reportar light_level 1 acá y verse iluminado como nivel
## 5 en pantalla. Sincronizar ambos es un requisito pendiente para una etapa
## posterior, no de esta.

## Luz base del lugar cuando no hay ninguna fuente puntual cerca. Cada
## escena/bioma puede pisar esto llamando a set_ambient_light_level() al
## arrancar (todavía no hay biomas reales, así que por ahora es un único
## valor global editable acá).
@export var ambient_light_level: int = 1

var _sources: Array = []


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
	var level: float = float(ambient_light_level)
	for source in _sources:
		if not is_instance_valid(source):
			continue
		level += source.get_light_contribution_at(position)
	return clampi(roundi(level), 0, 5)
