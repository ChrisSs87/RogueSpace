extends Area3D

## Pickup puntual de exploración para 6A.2. No crea inventario ni respawnea:
## la instancia de escena vuelve al reiniciar la run.
@export var oxygen_restore_amount: float = 10.0

var available := true


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		collect()


## Refuerzo para cargas/reposicionamientos donde Area3D no genera enter.
func _physics_process(_delta: float) -> void:
	if not available:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null and global_position.distance_to(player.global_position) <= 1.0:
		collect()


func collect() -> bool:
	if not available:
		return false
	available = false
	var restored := RunState.restore_oxygen(oxygen_restore_amount)
	EventBus.oxygen_cache_collected.emit(restored)
	queue_free()
	return true
