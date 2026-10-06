extends Node

## DebugConfig.gd (autoload)
## Interruptor central para herramientas de desarrollo. En el build final,
## alcanza con poner estos en false desde este Inspector — no hace falta
## borrar ningún nodo ni script.

@export var debug_hud_enabled: bool = true

## Agrega una segunda línea al label flotante de cada enemigo con línea de
## visión, distancia, nivel de luz del jugador y resultado de percepción
## (Sección 17 de la spec de percepción/iluminación). Independiente de
## debug_hud_enabled.
@export var perception_debug_enabled: bool = true
