extends CanvasLayer

## HUD jugable mínimo, separado de DebugHUD: permanece visible aunque se
## apague el debug técnico de percepción/navegación.
@onready var status_label: Label = $Root/StatusLabel
@onready var warning_label: Label = $Root/OxygenWarning
@onready var pickup_label: Label = $Root/PickupMessage

var _message_time_left := 0.0


func _ready() -> void:
	RunState.player_health_changed.connect(_on_health_changed)
	RunState.oxygen_changed.connect(_on_oxygen_changed)
	EventBus.oxygen_cache_collected.connect(_on_oxygen_cache_collected)
	_refresh()


func _process(delta: float) -> void:
	if _message_time_left <= 0.0:
		return
	_message_time_left -= delta
	if _message_time_left <= 0.0:
		pickup_label.visible = false


func _on_health_changed(_current: int, _maximum: int) -> void:
	_refresh()


func _on_oxygen_changed(_current: float, _maximum: float) -> void:
	_refresh()


func _on_oxygen_cache_collected(amount: float) -> void:
	pickup_label.text = "Oxígeno recuperado: +%d" % roundi(amount)
	pickup_label.visible = true
	_message_time_left = 2.5


func _refresh() -> void:
	status_label.text = "HP: %d/%d\nO2: %d%%" % [RunState.player_health, RunState.max_player_health, roundi(RunState.oxygen_current)]
	warning_label.visible = RunState.oxygen_current <= 0.0
