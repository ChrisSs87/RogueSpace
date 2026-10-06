extends CharacterBody3D

## Player.gd
## Etapa 1: movimiento en primera persona, cámara y colisiones (PC: teclado + mouse).
## Etapa 1.5: lectura opcional de controles táctiles (Android).
## Etapa 2 (enemigos): sistema de niveles de velocidad (1-5, ver GameBalance),
## ruido configurable por estado de movimiento (para el oído de los enemigos),
## y congelamiento del jugador cuando arranca un combate.
##
## DECISIÓN DE DISEÑO (fija, no revisar sin discutirlo primero): durante
## combate la cámara SIEMPRE queda bajo control total del jugador. Nunca se
## rota la cámara mediante código (ni instantáneo ni suave/interpolado) —
## cualquier rotación no iniciada por el propio jugador es un disparador
## clásico de mareo en VR/Cardboard, y este proyecto los tiene como
## plataforma objetivo desde el diseño original. Lo único que se bloquea al
## entrar en combate es el DESPLAZAMIENTO (velocity), nunca la orientación.

enum MovementState { WALK, RUN, STEALTH }

# --- Velocidad: WALK conserva el nivel existente; los otros modos son
# multiplicadores explícitos para que velocidad y ruido no queden acoplados. ---
# La conversión real a m/s vive en el autoload GameBalance, para poder
# ajustarla globalmente sin tocar este script.
@export var walk_speed_tier: int = 2
@export var run_speed_tier: int = 4
@export var stealth_speed_tier: int = 1
@export var stealth_speed_multiplier: float = 0.65
@export var run_speed_multiplier: float = 1.50

# --- Ruido: radio (en casilleros) que alcanza el oído de los enemigos. ---
# noise_multiplier queda preparado para que el ADN lo modifique más adelante;
# por ahora vale 1.0 siempre y ningún sistema lo toca todavía.
@export var walk_noise_radius_tiles: float = 3.0
@export var run_noise_radius_tiles: float = 5.0
@export var stealth_noise_radius_tiles: float = 1.0
@export var noise_multiplier: float = 1.0

# --- Intensidad de ruido: separada de radius a propósito (Sección 8 de la
# spec de percepción), aunque hoy se comporten igual (ningún sistema todavía
# distingue "más fuerte pero de corto alcance" de "más lejos pero débil").
# Queda preparado para que el ADN pueda modificar uno sin el otro más
# adelante, sin tener que reestructurar nada.
@export var walk_noise_intensity: float = 3.0
@export var run_noise_intensity: float = 5.0
@export var stealth_noise_intensity: float = 1.0

@export var mouse_sensitivity: float = 0.003
@export var touch_look_sensitivity: float = 0.006
@export var pitch_limit_deg: float = 85.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# "Head" es un Node3D hijo que rota en el eje vertical (mirar arriba/abajo).
# El cuerpo (este nodo) rota en el eje horizontal (girar a izquierda/derecha).
# Separarlos así evita que el jugador se "incline" al mirar hacia arriba.
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

# Referencia opcional al nodo TouchControls, si está presente en la escena.
# Player.gd no depende de él para nada: solo lo consulta si existe.
var touch_controls: Node = null

var movement_state: MovementState = MovementState.WALK
var _mobile_movement_state: MovementState = MovementState.WALK
var is_frozen: bool = false
const NOISE_EVENT_INTERVAL_SEC: float = 0.20
const NOISE_EVENT_MIN_DISPLACEMENT_M: float = 0.01
var _noise_event_elapsed_sec: float = 0.0


func _ready() -> void:
	# El grupo "player" es cómo los enemigos encuentran al jugador sin que
	# este script necesite conocerlos a ellos (desacople, ver Enemy.gd).
	add_to_group("player")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	call_deferred("_find_touch_controls")
	EventBus.combat_ready.connect(_on_combat_ready)


func _find_touch_controls() -> void:
	touch_controls = get_tree().get_first_node_in_group("touch_controls")


## No toca la cámara para nada (ver nota de diseño arriba). Los enemigos ya
## están en sus posiciones espaciales reales (delante, detrás, al costado —
## lo que corresponda) para cuando esto se dispara; es tarea del jugador
## girar la cabeza/cámara para ubicarlos, tanto en pantalla como en Cardboard.
func _on_combat_ready(_player: Node3D, _enemies: Array) -> void:
	freeze_for_combat()


## Llamado por CombatEncounterManager cuando el combate queda listo para
## empezar (Sección 10). El jugador deja de DESPLAZARSE pero conserva
## control total de cámara (ver _unhandled_input/_physics_process). El mouse
## NO cambia de modo: sigue capturado, igual que en exploración — el click
## sobre las cartas funciona igual con el mouse capturado (Godot sigue
## trackeando una posición virtual para la UI), y así la mirada nunca se ve
## limitada por el cursor llegando al borde de la pantalla. Le avisa a
## TouchControls que bloquee únicamente el joystick de movimiento — la
## mirada táctil sigue funcionando exactamente igual que en exploración.
func freeze_for_combat() -> void:
	is_frozen = true
	velocity = Vector3.ZERO
	if touch_controls != null and touch_controls.has_method("set_combat_active"):
		touch_controls.set_combat_active(true)


## Llamado por CombatManager cuando el combate termina (victoria). Devuelve
## el control normal de exploración, incluyendo el joystick de movimiento.
## Reafirma el mouse capturado por las dudas de que se haya tocado a mano
## (ej. Esc) durante el combate.
func unfreeze_after_combat() -> void:
	is_frozen = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if touch_controls != null and touch_controls.has_method("set_combat_active"):
		touch_controls.set_combat_active(false)


func _unhandled_input(event: InputEvent) -> void:
	# Esc alterna el mouse capturado/libre en cualquier momento (utilidad de
	# depuración). Ya no hace falta ligarlo al estado de combate: el mouse
	# nunca se fuerza a un modo particular al entrar/salir de combate.
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# La cámara funciona SIEMPRE, tanto en exploración como congelado en
	# combate, y el mouse permanece capturado en todo momento (giro
	# infinito, sin depender de que el cursor llegue al borde de la
	# pantalla). El click sobre las cartas coexiste con esto porque Godot
	# sigue procesando la posición virtual del mouse para la UI aunque el
	# cursor esté oculto/capturado.
	if event is InputEventMouseMotion:
		_apply_look(event.relative * mouse_sensitivity)


func _apply_look(relative: Vector2) -> void:
	# Girar el cuerpo entero en horizontal (yaw).
	rotate_y(-relative.x)
	# Girar solo la cabeza en vertical (pitch), con límite para no dar vueltas completas.
	head.rotate_x(-relative.y)
	head.rotation.x = clamp(
		head.rotation.x,
		deg_to_rad(-pitch_limit_deg),
		deg_to_rad(pitch_limit_deg)
	)


func _physics_process(delta: float) -> void:
	# La cámara funciona SIEMPRE, incluso congelado en combate — por eso
	# esto va ANTES del corte por is_frozen. En PC, la mirada se procesa en
	# _unhandled_input (mouse motion); acá solo hace falta el aporte táctil
	# de Android, que no llega como evento de input normal.
	if touch_controls != null and touch_controls.visible:
		var touch_look: Vector2 = touch_controls.consume_look_delta()
		if touch_look != Vector2.ZERO:
			_apply_look(touch_look * touch_look_sensitivity)

	if is_frozen:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# Gravedad simple: mantiene al jugador pegado al piso y le permite
	# bajar si el piso desaparece debajo (no hay salto en Alpha 0.1).
	if not is_on_floor():
		velocity.y -= gravity * delta

	_update_movement_state()

	# Lee el input de movimiento (WASD, definido en el mapa de Input del proyecto)
	# y lo convierte en una dirección relativa a hacia dónde mira el CUERPO
	# (no la cabeza, para que mirar arriba/abajo no afecte el movimiento).
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Se suma el joystick virtual (Android) al input de teclado (PC).
	# En PC esto no cambia nada porque touch_controls es null.
	if touch_controls != null and touch_controls.visible:
		input_dir = (input_dir + touch_controls.move_input).limit_length(1.0)

	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var speed_mps: float = get_current_speed_mps()

	if direction:
		velocity.x = direction.x * speed_mps
		velocity.z = direction.z * speed_mps
	else:
		# Frena en seco en vez de deslizar, para que el movimiento se sienta preciso
		# dentro de pasillos angostos.
		velocity.x = move_toward(velocity.x, 0, speed_mps)
		velocity.z = move_toward(velocity.z, 0, speed_mps)

	var position_before_move := global_position
	move_and_slide()
	_record_exploration_oxygen(position_before_move)
	if global_position.distance_to(position_before_move) > NOISE_EVENT_MIN_DISPLACEMENT_M:
		RunState.record_movement_time(get_movement_state_label(), delta)
	_emit_noise_event_from_actual_movement(position_before_move, delta)


func _record_exploration_oxygen(position_before_move: Vector3) -> void:
	var displacement := global_position - position_before_move
	displacement.y = 0.0
	# La distancia se toma después de move_and_slide(): mide recorrido real,
	# incluyendo bloqueos de pared, y no consume nada al quedarse quieto.
	RunState.record_exploration_distance(displacement.length())


## El oído trabaja con eventos situados, no con una consulta tardía a la
## posición actual del Player. Solo hay evento si hubo desplazamiento real:
## quedarse quieto no revela una posición nueva.
func _emit_noise_event_from_actual_movement(position_before_move: Vector3, delta: float) -> void:
	var displacement := global_position - position_before_move
	displacement.y = 0.0
	if displacement.length() < NOISE_EVENT_MIN_DISPLACEMENT_M:
		_noise_event_elapsed_sec = 0.0
		return

	_noise_event_elapsed_sec += delta
	if _noise_event_elapsed_sec < NOISE_EVENT_INTERVAL_SEC:
		return
	_noise_event_elapsed_sec = 0.0
	EventBus.player_noise_emitted.emit(global_position, get_current_noise_radius_m(), get_current_noise_intensity())


func _update_movement_state() -> void:
	if Input.is_action_pressed("stealth"):
		movement_state = MovementState.STEALTH
	elif Input.is_action_pressed("sprint"):
		movement_state = MovementState.RUN
	elif touch_controls != null and touch_controls.visible:
		movement_state = _mobile_movement_state
	else:
		movement_state = MovementState.WALK


func _current_speed_tier() -> int:
	match movement_state:
		MovementState.RUN:
			return run_speed_tier
		MovementState.STEALTH:
			return stealth_speed_tier
		_:
			return walk_speed_tier


func get_current_speed_mps() -> float:
	var walk_speed: float = GameBalance.get_speed(walk_speed_tier)
	match movement_state:
		MovementState.RUN:
			return walk_speed * run_speed_multiplier
		MovementState.STEALTH:
			return walk_speed * stealth_speed_multiplier
		_:
			return walk_speed


func cycle_mobile_movement_mode() -> void:
	_mobile_movement_state = (_mobile_movement_state + 1) % 3
	movement_state = _mobile_movement_state
	if touch_controls != null and touch_controls.has_method("set_movement_mode_label"):
		touch_controls.set_movement_mode_label(get_movement_state_label())


## Radio de ruido actual, en metros, para que los enemigos lo comparen contra
## su rango de oído. noise_multiplier queda listo para que el ADN lo escale
## más adelante (todavía no implementado).
func get_current_noise_radius_m() -> float:
	var radius_tiles: float
	match movement_state:
		MovementState.RUN:
			radius_tiles = run_noise_radius_tiles
		MovementState.STEALTH:
			radius_tiles = stealth_noise_radius_tiles
		_:
			radius_tiles = walk_noise_radius_tiles
	return radius_tiles * noise_multiplier * GameBalance.tile_size_m


## Intensidad de ruido actual — separada conceptualmente del radio (ver
## nota arriba). Ningún sistema la consulta todavía; queda lista para
## cuando haga falta distinguir "alcance" de "qué tan fuerte" (ej. un ADN
## que reduzca el radio pero no la intensidad, o viceversa).
func get_current_noise_intensity() -> float:
	match movement_state:
		MovementState.RUN:
			return run_noise_intensity
		MovementState.STEALTH:
			return stealth_noise_intensity
		_:
			return walk_noise_intensity


## Etiqueta legible del estado de movimiento actual, para el debug del
## jugador (DebugHUD) — evita que otro script tenga que conocer el enum
## MovementState interno de Player.gd.
func get_movement_state_label() -> String:
	match movement_state:
		MovementState.RUN:
			return "RUN"
		MovementState.STEALTH:
			return "STEALTH"
		_:
			return "WALK"
