extends Resource
class_name EnemyResource

## EnemyResource.gd
## Datos compartidos por especie/tipo de enemigo. Un mismo Enemy.gd genérico
## se comporta distinto según qué EnemyResource tenga asignado: agregar un
## enemigo nuevo es crear un archivo .tres con otros números, no escribir
## código nuevo.

@export var enemy_name: String = "Enemigo"
## Identificador de especie para el sistema de ADN (ej. "orco",
## "xenomorfo"). Orco Melee y Orco Pícaro comparten "orco": son la misma
## especie a efectos de ADN, aunque tengan EnemyResource distintos. Vacío
## para enemigos sin especie de ADN definida todavía (ej. Boss).
@export var species_id: String = ""

@export_category("Comportamiento")
@export var can_patrol: bool = true
## Legado de comportamiento de especies. La persistencia de búsqueda actual
## se configura con lose_target_timeout_sec; nunca implica omnisciencia ni
## un CHASE detenido después de perder contacto.
@export var can_lose_interest: bool = true
@export var is_boss: bool = false
## "investigate" = al escuchar un ruido va a investigar el lugar (orco).
## "chase_directly" = al escuchar un ruido persigue directamente (xenomorfo).
@export_enum("investigate", "chase_directly") var noise_response_mode: String = "investigate"
## Duración de búsqueda en ALERT tras llegar a la última posición conocida.
## Permite que una especie sea más persistente sin inventar la posición actual
## del jugador fuera de percepción.
@export var lose_target_timeout_sec: float = 7.0

@export_category("Velocidad (niveles 1-5, ver autoload GameBalance)")
@export var patrol_speed_tier: int = 2
@export var chase_speed_tier: int = 3

@export_category("Percepción (en casilleros)")
@export var vision_range_tiles: float = 5.0
@export var vision_angle_deg: float = 100.0
@export var hearing_range_tiles: float = 5.0

## Cuánto tiempo (segundos) el jugador debe permanecer dentro del campo
## visual, con línea de visión clara, para que el enemigo lo IDENTIFIQUE
## (pase a CHASE). Una aparición más breve solo produce ALERT. Configurable
## por enemigo: elites/bosses/razas perceptivas podrán usar un valor menor
## más adelante — no se fija ningún valor especial todavía, todos usan el
## mismo número de prueba por ahora.
@export var detection_time_sec: float = 1.0

## Capacidad de detección (0.0-1.0) según el nivel de luz DONDE ESTÁ EL
## JUGADOR (índice 0 = luz 0 ... índice 5 = luz 5). La iluminación nunca
## bloquea la visión como una pared: modula la VELOCIDAD con la que se
## acumula tiempo de detección (ver Enemy.gd _evaluate_vision) — con luz
## baja tarda más en identificarlo, con luz 0 nunca lo identifica del todo
## por visión sola (queda en ALERT indefinido). Valores de ejemplo de la
## spec, provisorios y editables por enemigo.
@export var light_detection_curve: Array[float] = [0.0, 0.15, 0.5, 0.8, 0.9, 1.0]

## Distancia (casilleros) por debajo de la cual, estando en FOV y con línea
## de visión clara, la detección se fuerza a capacidad 1.0 sin importar la
## luz — para que nunca pase "el orco está a medio metro mirándolo y no lo
## vio" por una tabla de luz desfavorable. Es una excepción de seguridad,
## no el mecanismo principal de detección (ver Enemy.gd).
@export var proximity_override_tiles: float = 1.5

@export_category("Combate")
@export var combat_distance_tiles: float = 2.0
## Si un enemigo persigue físicamente al jugador y por alguna razón nunca
## logra llegar a combat_distance_tiles (por ejemplo, queda trabado contra
## una pared), después de este tiempo se lo cuenta igual como "en posición"
## donde esté, para que el combate no quede trabado esperándolo para siempre.
@export var combat_approach_timeout_sec: float = 6.0

@export_category("Percepción (frecuencia de chequeo)")
@export var perception_interval_sec: float = 0.2

@export_category("Combate: cartas y vida")
@export var max_health: int = 30
## Piel Dura y futuros rasgos iniciales. Se aplica una sola vez al entrar
## en combate; no depende de nombre ni de especie.
@export var opening_block: int = 0
## Inmunidad completa al estado VENENO durante este combate.
@export var poison_immune: bool = false
## Mazo interno del enemigo para el turno de combate: en cada turno se elige
## UNA carta al azar de este array (Array.pick_random()). Un enemigo con el
## array vacío (ej. Xenomorfo/Boss en esta etapa) simplemente no ataca ni se
## defiende — placeholder seguro mientras no tengan mazo propio definido.
@export var combat_deck: Array[CardResource] = []
