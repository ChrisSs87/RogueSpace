extends CanvasLayer

## CombatAlertHUD.gd
## Placeholder del aviso de combate (Sección 11 del diseño de enemigos).
## Se muestra cuando el combate EMPIEZA DE VERDAD (todos los enemigos ya
## llegaron a distancia de combate y el jugador está congelado), no cuando
## un enemigo simplemente empieza a perseguir. Los estados de debug sobre la
## cabeza de cada enemigo (PATROL/CHASE/etc.) son independientes de este
## aviso y se pueden seguir usando para testear sin que se disparen juntos.
## Más adelante esto se reemplaza por una interfaz integrada al traje, con
## sonido.

@export var display_duration_sec: float = 2.0

@onready var label: Label = $Label

var _showing: bool = false


func _ready() -> void:
	EventBus.combat_ready.connect(_on_combat_ready)


func _on_combat_ready(_player: Node3D, _enemies: Array) -> void:
	if _showing:
		return
	_showing = true
	label.visible = true
	await get_tree().create_timer(display_duration_sec).timeout
	label.visible = false
	_showing = false
