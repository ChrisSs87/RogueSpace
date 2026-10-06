extends CanvasLayer

## CombatUI.gd
## HUD de combate. Solo LEE el estado de CombatManager/RunState y llama a
## play_card()/select_target()/end_turn() — ninguna regla de combate vive
## acá. Así, agregar más adelante controles táctiles, mando o mirada
## (Cardboard) es cuestión de disparar esos mismos métodos desde otro lado,
## sin tocar CombatManager ni este script.
##
## Dos formas de elegir objetivo, ambas válidas y NINGUNA desactiva a la
## otra — coexisten mediante una ventana corta de prioridad, no un
## interruptor:
##   1) Tocar el panel de un enemigo, o las flechas ←/→ en PC
##      (_on_enemy_panel_pressed / _cycle_target). Al elegir así, se abre
##      manual_target_override_duration_sec de prioridad manual: durante
##      ese rato la mirada NO reasigna el objetivo, para que dé tiempo a
##      jugar la carta sin que un vistazo de reojo lo pise.
##   2) Centrarlo con la cámara: pasado ese ratito, vuelve a mandar el
##      enemigo más cerca del centro de la vista si está dentro de
##      gaze_target_max_angle_deg (_update_gaze_target, todos los frames).
##      Si ninguno está lo bastante centrado, se conserva la selección
##      anterior. Es clave para Cardboard: en VR "mirar" ES la forma
##      natural de señalar — pero el jugador SIEMPRE puede elegir a mano un
##      enemigo fuera de su campo visual (al costado o detrás).

@export var gaze_target_max_angle_deg: float = 20.0
@export var manual_target_override_duration_sec: float = 2.0

@onready var root: Control = $Root
@onready var player_health_label: Label = $Root/PlayerHealthLabel
@onready var stamina_label: Label = $Root/StaminaLabel
@onready var block_label: Label = $Root/BlockLabel
@onready var end_turn_button: Button = $Root/EndTurnButton
@onready var card_slots: Array = [
	$Root/HandContainer/CardSlot0,
	$Root/HandContainer/CardSlot1,
	$Root/HandContainer/CardSlot2,
	$Root/HandContainer/CardSlot3,
]
@onready var enemy_panels: Array = [
	$Root/EnemyPanels/EnemyPanel0,
	$Root/EnemyPanels/EnemyPanel1,
]

@onready var defeat_overlay: Control = $DefeatOverlay
@onready var restart_button: Button = $DefeatOverlay/RestartButton

var _camera: Camera3D = null
var _manual_override_timer: float = 0.0


func _ready() -> void:
	visible = false
	defeat_overlay.visible = false

	end_turn_button.pressed.connect(_on_end_turn_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	for i in card_slots.size():
		card_slots[i].pressed.connect(_on_card_slot_pressed.bind(i))
	for i in enemy_panels.size():
		enemy_panels[i].pressed.connect(_on_enemy_panel_pressed.bind(i))

	CombatManager.combat_started.connect(_on_combat_started)
	CombatManager.combat_ended.connect(_on_combat_ended)
	CombatManager.state_updated.connect(_on_state_updated)
	CombatManager.player_defeated.connect(_on_player_defeated)


## Capa de "combat card input" por teclado (PC). A propósito es la ÚNICA
## responsabilidad de input propia de este método: no toca movimiento
## (Player.gd) ni cámara (InputEventMouseMotion se ignora acá, ni falta
## hace) — solo reacciona a las acciones play_card_1..4 y a ←/→ para elegir
## objetivo. Al no consumir el evento ni tocar Input.mouse_mode, el
## mouse-look sigue procesándose en Player.gd exactamente igual, en el
## mismo frame. ui_left/ui_right son las acciones default de Godot para las
## flechas — no hizo falta agregar nada al InputMap.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("play_card_1"):
		_on_card_slot_pressed(0)
	elif event.is_action_pressed("play_card_2"):
		_on_card_slot_pressed(1)
	elif event.is_action_pressed("play_card_3"):
		_on_card_slot_pressed(2)
	elif event.is_action_pressed("play_card_4"):
		_on_card_slot_pressed(3)
	elif event.is_action_pressed("ui_left"):
		_cycle_target(-1)
	elif event.is_action_pressed("ui_right"):
		_cycle_target(1)


func _cycle_target(direction: int) -> void:
	var count: int = CombatManager.get_combatant_count()
	if count <= 0:
		return
	var current: int = CombatManager.get_selected_target_index()
	var next_index: int = (current + direction + count) % count
	_select_target_manually(next_index)


func _process(delta: float) -> void:
	if _manual_override_timer > 0.0:
		_manual_override_timer -= delta
		return
	# Solo tiene sentido gastar esto en combate; en exploración no hay
	# combatants (get_combatant_count() da 0) así que sale al toque.
	_update_gaze_target()


## Encuentra el combatiente más centrado en la cámara actual y, si está
## dentro del ángulo tolerado, lo selecciona. No corre mientras dura la
## prioridad manual (_manual_override_timer) — ver _process().
func _update_gaze_target() -> void:
	var combatant_count: int = CombatManager.get_combatant_count()
	if combatant_count == 0:
		return

	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
		if _camera == null:
			return

	var camera_forward: Vector3 = -_camera.global_transform.basis.z
	var camera_pos: Vector3 = _camera.global_position

	var best_index: int = -1
	var best_angle_deg: float = INF

	for i in combatant_count:
		var enemy_node: Node3D = CombatManager.get_combatant_node(i)
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		var to_enemy: Vector3 = enemy_node.global_position - camera_pos
		if to_enemy.length() <= 0.01:
			continue
		var angle_deg: float = rad_to_deg(camera_forward.angle_to(to_enemy.normalized()))
		if angle_deg < best_angle_deg:
			best_angle_deg = angle_deg
			best_index = i

	if best_index != -1 and best_angle_deg <= gaze_target_max_angle_deg:
		CombatManager.select_target(best_index)


func _on_combat_started() -> void:
	visible = true
	root.visible = true
	defeat_overlay.visible = false
	_camera = get_viewport().get_camera_3d()
	_manual_override_timer = 0.0


func _on_combat_ended() -> void:
	visible = false


func _on_player_defeated() -> void:
	root.visible = false
	defeat_overlay.visible = true


func _on_state_updated() -> void:
	player_health_label.text = "Vida: %d/%d" % [RunState.player_health, RunState.max_player_health]
	stamina_label.text = "Stamina: %d/%d%s" % [RunState.stamina, RunState.max_stamina, "  VENENO: -2 próximo turno" if CombatManager.get_debug_player_poisoned() else ""]
	block_label.text = "Bloqueo: %d" % RunState.block

	var target_index: int = CombatManager.get_selected_target_index()
	var combatant_count: int = CombatManager.get_combatant_count()

	for i in enemy_panels.size():
		var panel: Button = enemy_panels[i]
		if i < combatant_count:
			panel.visible = true
			var prefix: String = "[Objetivo] " if i == target_index else ""
			panel.text = "%s%s\nVida: %d/%d\nBloqueo: %d\nIntención: %s" % [
				prefix,
				CombatManager.get_combatant_display_name(i),
				CombatManager.get_combatant_health(i),
				CombatManager.get_combatant_max_health(i),
				CombatManager.get_combatant_block(i),
				CombatManager.get_combatant_intention_text(i),
			]
		else:
			panel.visible = false
			panel.text = "—"

	for i in card_slots.size():
		var slot: Button = card_slots[i]
		if i < RunState.hand.size():
			var card: CardResource = RunState.hand[i]
			slot.visible = true
			slot.text = "%s\n(%d stamina)" % [card.card_name, card.stamina_cost]
			slot.disabled = RunState.stamina < card.stamina_cost
		else:
			slot.visible = false
			slot.text = "—"


func _on_card_slot_pressed(index: int) -> void:
	if index >= RunState.hand.size():
		return
	CombatManager.play_card(RunState.hand[index])


func _on_enemy_panel_pressed(index: int) -> void:
	_select_target_manually(index)


## Punto único para toda selección MANUAL de objetivo (panel o flechas):
## selecciona y abre la ventana de prioridad que frena a la mirada por un
## rato (ver _process/_update_gaze_target).
func _select_target_manually(index: int) -> void:
	CombatManager.select_target(index)
	_manual_override_timer = manual_target_override_duration_sec


func _on_end_turn_pressed() -> void:
	CombatManager.end_turn()


func _on_restart_pressed() -> void:
	DNAManager.reset()
	RunState.reset_run()
	CombatManager.reset_after_defeat()
	CombatEncounterManager.reset()
	get_tree().reload_current_scene()
