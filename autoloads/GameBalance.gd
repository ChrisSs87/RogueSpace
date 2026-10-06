extends Node

## GameBalance.gd (autoload)
## Punto único de valores de balance compartidos entre sistemas (jugador,
## enemigos, etc.), para que sean configurables desde el editor sin tocar
## código. Se va a ir ampliando con más valores a medida que los sistemas
## los necesiten (oxígeno, daño, drop de ADN...).

## Velocidad en metros/segundo para cada NIVEL de velocidad (1 a 5).
## Índice 0 = nivel 1, índice 4 = nivel 5. Los sistemas de jugador/enemigos
## solo hablan en "niveles" (1-5); la conversión real a m/s vive acá.
@export var speed_tiers_mps: Array[float] = [1.0, 2.0, 3.0, 4.0, 5.0]

## Cuántos metros representa un "casillero" del Documento Maestro.
## DECISIÓN PENDIENTE: el documento no define esta equivalencia todavía.
## Por ahora asumo 1 casillero = 1 metro; si se define otro valor, se ajusta
## acá y todos los sistemas de visión/oído/patrulla lo heredan automáticamente.
@export var tile_size_m: float = 1.0

## Etapa 6A.2: valor deliberadamente provisional para medir el recorrido del
## greybox. El coste usa metros horizontales reales, nunca tiempo quieto.
@export var oxygen_cost_per_meter: float = 0.10
@export var normal_combat_oxygen_cost: float = 3.0


func get_speed(tier: int) -> float:
	var index: int = clampi(tier - 1, 0, speed_tiers_mps.size() - 1)
	return speed_tiers_mps[index]
