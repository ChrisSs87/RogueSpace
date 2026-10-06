extends Area3D

@export var panel_path: NodePath

var activated := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_activate()


## Refuerzo para el Player CharacterBody3D: conserva el Area3D normal, pero
## también reconoce al jugador ya dentro del volumen luego de una carga o
## reposicionamiento de escena (caso que el monitor de físicas puede no emitir).
func _physics_process(_delta: float) -> void:
	if activated:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null and global_position.distance_to(player.global_position) <= 2.0:
		_activate()


func _activate() -> void:
	if activated:
		return
	activated = true
	var panel := get_node_or_null(panel_path)
	if panel != null:
		panel.set("visible", true)


func restart_test() -> void:
	RunState.reset_run()
	get_tree().reload_current_scene()
