extends CharacterBody3D
class_name Enemy

## Enemy.gd
## IA genérica de enemigo. Los datos que diferencian a cada especie
## (velocidad, visión, oído, si patrulla, cómo reacciona al ruido) viven en
## un EnemyResource asignado desde el editor — este script no tiene ningún
## "if es xenomorfo" ni similar. Agregar una especie nueva es crear un
## EnemyResource (.tres) nuevo, no tocar este archivo.
##
## Estados:
##   PATROL    -> recorre patrol_points (solo si can_patrol)
##   IDLE      -> quieto, esperando detectar al jugador (solo si !can_patrol)
##   ALERT     -> escuchó un ruido, va a investigar la última posición
##   CHASE     -> vio o confirmó al jugador, lo persigue hasta quedar a
##                distancia de combate (sin combate armado todavía)
##   APPROACH  -> el encuentro ya quedó definido: CombatEncounterManager le
##                asignó una posición de combate (un ángulo respecto del
##                jugador, para no superponerse con otros enemigos) y la
##                persigue físicamente. NO hay teletransporte.
##   COMBAT    -> congelado, ya llegó a su posición de combate
##   BOSS_IDLE -> exclusivo del boss: espera a que el jugador entre a la sala

enum State { PATROL, IDLE, ALERT, CHASE, APPROACH, COMBAT, BOSS_IDLE }

const ARRIVE_THRESHOLD_M: float = 0.3
const COMBAT_SLOT_ARRIVE_THRESHOLD_M: float = 0.3
const SELF_WAYPOINT_THRESHOLD_M: float = 0.05
const PATROL_STALL_DISPLACEMENT_M: float = 0.05
const STUCK_RECOVERY_TRIGGER_SEC: float = 0.65
const STUCK_RECOVERY_PROBE_M: float = 0.55
const STUCK_RECOVERY_ARRIVE_M: float = 0.12
const WORLD_COLLISION_MASK: int = 1  # capa 1 = paredes/piso (ver DungeonTest.tscn)
const SOUND_CONTACT_MEMORY_SEC: float = 0.35
const AMBUSH_ZONE_DISTANCE_M: float = 1.0

@export var enemy_resource: EnemyResource
## Puntos de patrulla, definidos a mano en la escena (Marker3D). Se ignoran
## si el EnemyResource tiene can_patrol = false.
@export var patrol_points: Array[NodePath] = []
## Color placeholder para diferenciar especies a simple vista mientras no
## hay arte definitivo (Sección 3: la diferencia visual llega después).
@export var debug_color: Color = Color(0.6, 0.6, 0.6)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var debug_label: Label3D = $DebugStateLabel
@onready var boss_trigger_zone: Area3D = $BossTriggerZone
@onready var perception_timer: Timer = $PerceptionTimer
@onready var navigation_anchor: Node3D = $NavigationAnchor
@onready var navigation_agent: NavigationAgent3D = $NavigationAnchor/NavigationAgent3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _state: State = State.PATROL
var _patrol_targets: Array[Node3D] = []
var _patrol_index: int = 0
var _patrol_direction: int = 1

var _last_known_player_position: Vector3 = Vector3.ZERO
var _last_known_source: String = "NONE"
var _last_heard_noise_time_msec: int = -1000000
var _searching_at_last_known: bool = false
var _time_since_detection: float = 0.0
var _has_requested_encounter: bool = false
var _encounter_join_closed: bool = false
var _encounter_contact_valid: bool = false
var _current_contact_kind: String = "NONE"
var _encounter_debug_state: String = "NONE"
## Encounter sólo posee movimiento durante APPROACH/READY/COMBAT. Un
## DROPPED queda excluido de ESE encuentro, pero vuelve de inmediato a IA de
## exploración y percepción.
var _encounter_owns_enemy: bool = false
var _excluded_from_active_encounter: bool = false
var _must_lose_contact_before_reentry: bool = false
var _ambush_candidate_registered: bool = false

var _target_player: Node3D = null
var _approach_elapsed: float = 0.0
## Ángulo (grados, respecto de hacia dónde mira el jugador) que le asignó
## CombatEncounterManager para esta posición de combate. 0 = de frente.
var _combat_slot_angle_deg: float = 0.0
var _debug_combat_slot_valid: bool = true
var _debug_combat_slot_world: Vector3 = Vector3.INF
var _debug_combat_slot_navigation: Vector3 = Vector3.INF
var _debug_combat_slot_lateral_error_m: float = INF
var _debug_combat_slot_vertical_error_m: float = INF

## Segundos continuos que el jugador lleva visible (distancia+FOV+línea de
## visión, sin cortes) — independiente de _time_since_detection, que es
## para el timeout de "perder al objetivo". Se resetea apenas falla
## cualquiera de esas tres condiciones; NO se resetea por baja iluminación
## sola (la luz solo decide si ESE chequeo alcanza para identificar, no
## corta la racha de visibilidad sostenida).
var _sight_timer: float = 0.0

# --- Datos para el debug (Sección 4 del checkpoint de correcciones).
# Strings ya formateados: si un dato no se llegó a calcular este tick (ej.
# fuera de rango, nunca se evaluó FOV), queda en "N/A" en vez de inventar
# un valor o arrastrar uno viejo de un tick anterior. ---
var _debug_dist_str: String = "N/A"
var _debug_fov_str: String = "N/A"
var _debug_los_str: String = "N/A"
var _debug_light_str: String = "N/A"
var _debug_sight_str: String = "N/A"
var _debug_capability_str: String = "N/A"
var _debug_nav_str: String = "N/A"
var _debug_nav_target_str: String = "N/A"
var _debug_nav_iteration: int = 0
var _debug_next_path_distance_m: float = -1.0
var _debug_patrol_target_str: String = "N/A"
var _debug_patrol_target_distance_m: float = -1.0
var _debug_requested_speed_mps: float = 0.0
var _debug_actual_speed_mps: float = 0.0
var _debug_patrol_stall_reason: String = ""
var _debug_patrol_stall_elapsed: float = 0.0
var _last_vision_result: String = VISION_NONE
var _navigation_target: Vector3 = Vector3.INF
var _fallback_next_path_position: Vector3 = Vector3.INF
var _nav_failure_elapsed: float = 0.0
var _debug_ai_stall_elapsed: float = 0.0
var _debug_ai_stall_reason: String = ""
var _debug_physical_movement_str: String = "OK"
## Objetivo semántico entregado por la IA (patrulla, contacto o LAST KNOWN).
## _navigation_target puede apuntar temporalmente a una sonda de recuperación;
## nunca debe convertirse en la fuente de verdad de la persecución.
var _semantic_navigation_target: Vector3 = Vector3.INF
var _stuck_progress_reference_distance_m: float = INF
var _stuck_recovery_elapsed: float = 0.0
var _stuck_recovery_active: bool = false
var _stuck_recovery_target: Vector3 = Vector3.INF
var _debug_stuck_recovery_count: int = 0
var _debug_rotation_owner: String = "NONE"
var _debug_desired_heading: Vector3 = Vector3.ZERO
var _debug_physical_heading: Vector3 = Vector3.ZERO
var _debug_nav_waypoint: Vector3 = Vector3.INF
var _navigation_anchor_map: RID = RID()
var _navigation_anchor_iteration: int = -1
var _last_known_marker: MeshInstance3D = null
var _ambush_zone_marker: MeshInstance3D = null
var _player_was_in_ambush_zone: bool = false

## Hook deliberadamente sin efecto de gameplay: la futura emboscada podrá
## conectarse acá sin acoplarse al cálculo de percepción o navegación.
signal player_entered_ambush_zone(player: Node3D)


func _ready() -> void:
	if enemy_resource == null:
		push_warning("Enemy '%s' no tiene EnemyResource asignado." % name)
		set_physics_process(false)
		return

	_apply_debug_color()

	boss_trigger_zone.monitoring = enemy_resource.is_boss

	if enemy_resource.is_boss:
		_state = State.BOSS_IDLE
		boss_trigger_zone.body_entered.connect(_on_boss_trigger_entered)
	else:
		_state = State.PATROL if enemy_resource.can_patrol else State.IDLE
		for path in patrol_points:
			var point: Node3D = get_node_or_null(path)
			if point != null:
				_patrol_targets.append(point)
		perception_timer.wait_time = enemy_resource.perception_interval_sec
		perception_timer.timeout.connect(_on_perception_tick)
		perception_timer.start()
		EventBus.player_noise_emitted.connect(_on_player_noise_emitted)

	_create_last_known_debug_marker()
	_create_ambush_debug_marker()

	_update_debug_label()


func _create_last_known_debug_marker() -> void:
	_last_known_marker = MeshInstance3D.new()
	_last_known_marker.name = "LastKnownDebugMarker"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.16
	mesh.height = 0.05
	_last_known_marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.55, 0.1, 0.85)
	_last_known_marker.material_override = material
	_last_known_marker.top_level = true
	_last_known_marker.visible = false
	add_child(_last_known_marker)


func _create_ambush_debug_marker() -> void:
	_ambush_zone_marker = MeshInstance3D.new()
	_ambush_zone_marker.name = "AmbushZoneDebugMarker"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.7, 0.025, 0.7)
	_ambush_zone_marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.15, 1.0, 0.25, 0.65)
	_ambush_zone_marker.material_override = material
	_ambush_zone_marker.top_level = true
	_ambush_zone_marker.visible = false
	add_child(_ambush_zone_marker)


func _apply_debug_color() -> void:
	if mesh_instance == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = debug_color
	mesh_instance.material_override = material


# --- Movimiento y patrulla -------------------------------------------------

func _physics_process(delta: float) -> void:
	_sync_navigation_anchor()
	if enemy_resource == null or enemy_resource.is_boss or _state == State.COMBAT:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	_time_since_detection += delta
	_check_lose_target_timeout()

	var position_before_move: Vector3 = global_position
	match _state:
		State.PATROL:
			_process_patrol(delta)
		State.ALERT:
			# ALERT antes de llegar todavía es viaje a LAST KNOWN. El timeout
			# solo existe después de alcanzar el punto y empezar búsqueda.
			if not _searching_at_last_known:
				_debug_requested_speed_mps = _current_speed_mps()
				var reached_alert_target := _move_toward_point(_last_known_player_position, _current_speed_mps(), delta)
				if reached_alert_target or _debug_nav_str == "NO PATH":
					_begin_last_known_search()
			else:
				velocity.x = 0.0
				velocity.z = 0.0
		State.CHASE:
			_process_chase(delta)
		State.APPROACH:
			_process_combat_approach(delta)
		State.IDLE:
			velocity.x = 0.0
			velocity.z = 0.0

	move_and_slide()
	_update_actual_motion_debug(position_before_move, delta)
	_update_exploration_stall_debug(position_before_move, delta)
	_update_stuck_recovery(position_before_move, delta)
	_update_ambush_zone_debug()
	_update_debug_label()


## NavigationAgent3D calcula su ruta usando la posición de su Node3D padre.
## El centro del CharacterBody/cápsula puede estar por encima del plano que
## representa la NavigationMesh (pies/suelo). Sin este ancla, el agente puede
## conservar indefinidamente su primer waypoint por una diferencia sólo en Y.
## Se sincroniza por iteración del mapa, no cada frame, para soportar pisos a
## distintas alturas sin hardcodear una separación vertical.
func _sync_navigation_anchor() -> void:
	if navigation_anchor == null:
		return
	var navigation_map: RID = get_world_3d().get_navigation_map()
	var iteration := NavigationServer3D.map_get_iteration_id(navigation_map)
	if iteration == 0:
		return
	if navigation_map == _navigation_anchor_map and iteration == _navigation_anchor_iteration:
		return
	var projected := NavigationServer3D.map_get_closest_point(navigation_map, global_position)
	navigation_anchor.position.y = projected.y - global_position.y
	_navigation_anchor_map = navigation_map
	_navigation_anchor_iteration = iteration


func _process_patrol(delta: float) -> void:
	if _patrol_targets.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var target: Node3D = _patrol_targets[_patrol_index]
	_debug_patrol_target_str = "%d -> %s" % [_patrol_index, target.name]
	var flat_target_delta := target.global_position - global_position
	flat_target_delta.y = 0.0
	_debug_patrol_target_distance_m = flat_target_delta.length()
	var requested_speed := _current_speed_mps()
	_debug_requested_speed_mps = requested_speed
	var reached: bool = _move_toward_point(target.global_position, requested_speed, delta)

	if reached:
		_nav_failure_elapsed = 0.0
		_advance_patrol_index()
	elif _debug_nav_str == "NO PATH":
		_nav_failure_elapsed += delta
		# Recuperación acotada: el mapa puede estar sincronizándose al inicio
		# o un marker puede quedar transitoriamente sin ruta. No insistir contra
		# una pared ni congelar PATROL de forma permanente.
		if _nav_failure_elapsed >= 1.0:
			_nav_failure_elapsed = 0.0
			_advance_patrol_index()


func _advance_patrol_index() -> void:
	if _patrol_targets.size() < 2:
		return
	_patrol_index += _patrol_direction
	if _patrol_index >= _patrol_targets.size():
		_patrol_index = _patrol_targets.size() - 2
		_patrol_direction = -1
	elif _patrol_index < 0:
		_patrol_index = 1
		_patrol_direction = 1


## Mueve al enemigo en línea recta hacia target_pos, deteniéndose a
## arrival_threshold metros. Devuelve true si ya está dentro del umbral.
## Nota de arquitectura: esto es movimiento directo (sin pathfinding),
## suficiente para la dungeon semi-fija de prueba. Si en el futuro los
## niveles tienen esquinas más complejas, esta es la única función que
## habría que reemplazar por NavigationAgent3D — el resto de la máquina de
## estados no cambia.
func _move_toward_point(target_pos: Vector3, speed_mps: float, delta: float, arrival_threshold: float = ARRIVE_THRESHOLD_M) -> bool:
	# Conserva el objetivo que tiene significado para la IA aunque una
	# recuperación física use una sonda lateral durante unos ticks. Una nueva
	# percepción (VISION/SOUND) reemplaza este valor y descarta la sonda vieja.
	if _semantic_navigation_target == Vector3.INF or _semantic_navigation_target.distance_to(target_pos) > 0.1:
		_semantic_navigation_target = target_pos
		_stuck_progress_reference_distance_m = INF
		if _stuck_recovery_active:
			_clear_stuck_recovery()
	var flat_final_target := target_pos - global_position
	flat_final_target.y = 0.0
	if flat_final_target.length() <= arrival_threshold:
		_clear_stuck_recovery()
		velocity.x = 0.0
		velocity.z = 0.0
		return true

	var navigation_goal := target_pos
	if _stuck_recovery_active:
		var to_recovery := _stuck_recovery_target - global_position
		to_recovery.y = 0.0
		if to_recovery.length() <= STUCK_RECOVERY_ARRIVE_M:
			_clear_stuck_recovery()
		else:
			navigation_goal = _stuck_recovery_target

	if not _update_navigation_target(navigation_goal):
		velocity.x = 0.0
		velocity.z = 0.0
		return false

	# Llegar al objetivo final no es lo mismo que estar sobre el primer
	# waypoint. NavigationAgent3D puede devolver inicialmente la propia
	# posición del agente; tratar ese punto como "arrived" alternaba A/B cada
	# frame y dejaba todas las patrullas inmóviles.

	var next_path_pos: Vector3 = _fallback_next_path_position if _fallback_next_path_position != Vector3.INF else navigation_agent.get_next_path_position()
	_debug_nav_waypoint = next_path_pos
	var to_target: Vector3 = next_path_pos - global_position
	to_target.y = 0.0
	var distance: float = to_target.length()
	_debug_next_path_distance_m = distance

	if distance <= SELF_WAYPOINT_THRESHOLD_M:
		_debug_patrol_stall_reason = "NEXT WAYPOINT == SELF"
		velocity.x = 0.0
		velocity.z = 0.0
		return false

	var direction: Vector3 = to_target / distance
	# Para PATROL el umbral de llegada sólo aplica al objetivo FINAL (ver
	# chequeo previo). Un NavigationAgent puede entregar puntos intermedios a
	# exactamente 0.30 m; restar aquí ARRIVE_THRESHOLD_M dejaba velocidad 0 y
	# PATROL se congelaba con NAV: OK. Se limita al waypoint real sin alterar
	# las reglas ya validadas de APPROACH/CHASE.
	# arrival_threshold se evalúa arriba contra el objetivo FINAL. Restarlo
	# también a un waypoint intermedio detiene ALERT/CHASE cuando Navigation
	# entrega un segmento de ~0.30 m: LAST KNOWN queda lejos pero velocity=0.
	var waypoint_remaining_distance: float = distance
	var capped_speed_mps: float = minf(speed_mps, waypoint_remaining_distance / maxf(delta, 0.0001))
	velocity.x = direction.x * capped_speed_mps
	velocity.z = direction.z * capped_speed_mps
	_debug_desired_heading = direction
	return false


## Si no hay ruta válida, se detiene en vez de insistir contra una pared.
## En el siguiente tick vuelve a consultar por si el mapa se actualizó.
func _update_navigation_target(target_pos: Vector3) -> bool:
	if navigation_agent == null:
		_debug_nav_str = "NO PATH"
		_debug_patrol_stall_reason = "NO NAVIGATION AGENT"
		return false

	# Los Marker3D de patrulla están sobre el piso (Y=0), mientras la
	# NavigationMesh y el CharacterBody viven a Y=1. La consulta al agente
	# debe usar el plano navegable para no transformar una ruta existente en
	# un falso NO PATH por una diferencia vertical decorativa.
	var navigation_target := Vector3(target_pos.x, global_position.y, target_pos.z)
	var navigation_map: RID = get_world_3d().get_navigation_map()
	_debug_nav_iteration = NavigationServer3D.map_get_iteration_id(navigation_map)
	if _debug_nav_iteration == 0:
		_debug_nav_str = "WAIT"
		_debug_nav_target_str = "sync"
		_debug_patrol_stall_reason = "WAIT"
		return false
	var projected_target: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, navigation_target)
	if projected_target != Vector3.ZERO:
		navigation_target = projected_target

	if _navigation_target == Vector3.INF or _navigation_target.distance_to(navigation_target) > 0.1:
		navigation_agent.target_position = navigation_target
		_navigation_target = navigation_target

	var is_reachable: bool = navigation_agent.is_target_reachable()
	var agent_reported_reachable: bool = is_reachable
	_fallback_next_path_position = Vector3.INF
	var agent_next_path_position := navigation_agent.get_next_path_position()
	var agent_next_delta := agent_next_path_position - global_position
	agent_next_delta.y = 0.0
	# Android puede informar que el target es alcanzable y, aun así, devolver
	# el propio punto como siguiente waypoint. En ambos casos (NO PATH o
	# waypoint propio), consultamos la ruta completa y elegimos el primer
	# punto horizontalmente significativo; nunca se pasa a movimiento directo.
	if not is_reachable or agent_next_delta.length() <= SELF_WAYPOINT_THRESHOLD_M:
		var fallback_waypoint := _get_significant_navigation_waypoint(navigation_map, navigation_target)
		if fallback_waypoint != Vector3.INF:
			_fallback_next_path_position = fallback_waypoint
			is_reachable = true
			_debug_patrol_stall_reason = "" if agent_next_delta.length() > SELF_WAYPOINT_THRESHOLD_M else "AGENT SELF -> MAP PATH"
		else:
			is_reachable = false
			_debug_patrol_stall_reason = "NEXT WAYPOINT == SELF" if agent_reported_reachable else "NO PATH"
	_debug_nav_str = "OK" if is_reachable else "NO PATH"
	_debug_nav_target_str = "%.1f, %.1f" % [target_pos.x, target_pos.z]
	return is_reachable


## Retorna el primer waypoint de la ruta completa que no sea, en la práctica,
## la posición actual. No se asume que path[1] sea útil: algunas plataformas
## incluyen un punto inicial casi idéntico al CharacterBody.
func _get_significant_navigation_waypoint(navigation_map: RID, navigation_target: Vector3) -> Vector3:
	var projected_start := NavigationServer3D.map_get_closest_point(navigation_map, global_position)
	var fallback_path := NavigationServer3D.map_get_path(navigation_map, projected_start, navigation_target, true)
	for waypoint in fallback_path:
		var horizontal_delta: Vector3 = waypoint - global_position
		horizontal_delta.y = 0.0
		if horizontal_delta.length() > SELF_WAYPOINT_THRESHOLD_M:
			return waypoint
	return Vector3.INF


func _update_actual_motion_debug(position_before_move: Vector3, delta: float) -> void:
	var horizontal_displacement := global_position - position_before_move
	horizontal_displacement.y = 0.0
	_debug_actual_speed_mps = horizontal_displacement.length() / maxf(delta, 0.0001)
	if horizontal_displacement.length() > 0.001:
		_debug_physical_heading = horizontal_displacement.normalized()
		# Exploración tiene una única autoridad de orientación: el movimiento
		# físico que move_and_slide realmente consiguió. El waypoint sólo decide
		# velocidad; nunca puede alternar el FOV si el cuerpo no se desplazó.
		if not _encounter_owns_enemy and not _searching_at_last_known:
			look_at(global_position + _debug_physical_heading, Vector3.UP)
			_debug_rotation_owner = "EXPLORATION PHYSICAL"

	if _state != State.PATROL:
		_debug_patrol_stall_elapsed = 0.0
		return

	var should_be_patrolling: bool = _debug_patrol_target_distance_m > ARRIVE_THRESHOLD_M and _debug_requested_speed_mps > 0.0
	if should_be_patrolling and horizontal_displacement.length() < PATROL_STALL_DISPLACEMENT_M * delta:
		_debug_patrol_stall_elapsed += delta
		if _debug_patrol_stall_reason.is_empty():
			_debug_patrol_stall_reason = "MOVE_AND_SLIDE NO DISPLACEMENT" if velocity.length() > 0.01 else "VELOCITY == 0"
	else:
		_debug_patrol_stall_elapsed = 0.0
		if _debug_nav_str == "OK":
			_debug_patrol_stall_reason = ""


func _update_exploration_stall_debug(position_before_move: Vector3, delta: float) -> void:
	if _encounter_owns_enemy or _state == State.PATROL or _state == State.IDLE or _state == State.COMBAT:
		_debug_ai_stall_elapsed = 0.0
		return
	var pending_last_known := not _searching_at_last_known and _last_known_source != "NONE" and global_position.distance_to(_last_known_player_position) > ARRIVE_THRESHOLD_M
	if not pending_last_known:
		_debug_ai_stall_elapsed = 0.0
		return
	var displacement := global_position - position_before_move
	displacement.y = 0.0
	if _debug_nav_str == "OK" and _debug_requested_speed_mps > 0.0 and displacement.length() < PATROL_STALL_DISPLACEMENT_M * delta:
		_debug_ai_stall_elapsed += delta
		if velocity.length() < 0.01:
			_debug_ai_stall_reason = "ZERO VELOCITY"
		elif _debug_next_path_distance_m <= SELF_WAYPOINT_THRESHOLD_M:
			_debug_ai_stall_reason = "NEXT WAYPOINT SELF"
		else:
			_debug_ai_stall_reason = "MOVE_AND_SLIDE NO DISPLACEMENT"
	else:
		_debug_ai_stall_elapsed = 0.0
		_debug_ai_stall_reason = ""


## Recuperación física acotada. Conserva el destino semántico que el estado
## actual vuelve a entregar cada tick; sólo introduce un breve punto navegable
## para separarse de una pared antes de reanudar la ruta normal.
func _update_stuck_recovery(position_before_move: Vector3, delta: float) -> void:
	if _encounter_owns_enemy or _state == State.IDLE or _state == State.COMBAT or _searching_at_last_known:
		_stuck_recovery_elapsed = 0.0
		return
	var final_target := _semantic_navigation_target if _semantic_navigation_target != Vector3.INF else Vector3.INF
	if final_target == Vector3.INF:
		_stuck_recovery_elapsed = 0.0
		return
	var remaining := final_target - global_position
	remaining.y = 0.0
	var displacement := global_position - position_before_move
	displacement.y = 0.0
	var has_requested_movement := _debug_nav_str == "OK" and _debug_requested_speed_mps > 0.05 and remaining.length() > ARRIVE_THRESHOLD_M
	if not has_requested_movement:
		_stuck_recovery_elapsed = 0.0
		_stuck_progress_reference_distance_m = INF
		if not _stuck_recovery_active:
			_debug_physical_movement_str = "OK"
		return
	if _stuck_progress_reference_distance_m == INF:
		_stuck_progress_reference_distance_m = remaining.length()
	var made_meaningful_progress := remaining.length() <= _stuck_progress_reference_distance_m - 0.02
	if made_meaningful_progress:
		_stuck_progress_reference_distance_m = remaining.length()
		_stuck_recovery_elapsed = 0.0
		if not _stuck_recovery_active:
			_debug_physical_movement_str = "OK"
		return
	# Un roce contra una pared puede producir desplazamientos minúsculos o
	# laterales. Si no reduce el objetivo semántico durante la ventana, es un
	# bloqueo físico aunque NavigationAgent siga respondiendo NAV: OK.
	var physically_blocked := displacement.length() < PATROL_STALL_DISPLACEMENT_M * delta or not made_meaningful_progress
	if not physically_blocked:
		_stuck_recovery_elapsed = 0.0
		return
	_stuck_recovery_elapsed += delta
	_debug_physical_movement_str = "BLOCKED"
	if _stuck_recovery_elapsed >= STUCK_RECOVERY_TRIGGER_SEC:
		_begin_stuck_recovery(final_target)


func _begin_stuck_recovery(semantic_target: Vector3) -> void:
	_debug_stuck_recovery_count += 1
	_stuck_recovery_elapsed = 0.0
	_navigation_target = Vector3.INF
	_fallback_next_path_position = Vector3.INF
	var navigation_map: RID = get_world_3d().get_navigation_map()
	var projected_start := NavigationServer3D.map_get_closest_point(navigation_map, global_position)
	var projected_final := NavigationServer3D.map_get_closest_point(navigation_map, semantic_target)
	var desired_direction := projected_final - projected_start
	desired_direction.y = 0.0
	if desired_direction.length() <= 0.01:
		_stuck_recovery_active = false
		_debug_physical_movement_str = "STUCK RECOVERY: REPLAN"
		return
	desired_direction = desired_direction.normalized()
	var lateral := Vector3(-desired_direction.z, 0.0, desired_direction.x)
	# Primero se prueba un paso lateral: ante un obstáculo que la NavigationMesh
	# todavía no conoce, retroceder y retomar la misma recta volvería a chocar.
	var probe_directions := [lateral, -lateral, -desired_direction, (-desired_direction + lateral).normalized(), (-desired_direction - lateral).normalized()]
	for probe_direction: Vector3 in probe_directions:
		var probe: Vector3 = projected_start + probe_direction * STUCK_RECOVERY_PROBE_M
		var candidate: Vector3 = NavigationServer3D.map_get_closest_point(navigation_map, probe)
		var candidate_delta: Vector3 = candidate - global_position
		candidate_delta.y = 0.0
		if candidate_delta.length() < STUCK_RECOVERY_ARRIVE_M or test_move(global_transform, candidate_delta):
			continue
		var onward_path := NavigationServer3D.map_get_path(navigation_map, candidate, projected_final, true)
		if onward_path.size() >= 2:
			_stuck_recovery_target = candidate
			_stuck_recovery_active = true
			_debug_physical_movement_str = "STUCK RECOVERY"
			return
	_stuck_recovery_active = false
	_debug_physical_movement_str = "STUCK RECOVERY: REPLAN"


func _clear_stuck_recovery() -> void:
	_stuck_recovery_active = false
	_stuck_recovery_target = Vector3.INF
	_stuck_recovery_elapsed = 0.0
	_stuck_progress_reference_distance_m = INF


func get_patrol_runtime_debug() -> Dictionary:
	return {
		"patrol_index": _patrol_index,
		"patrol_target": _debug_patrol_target_str,
		"target_distance_m": _debug_patrol_target_distance_m,
		"requested_speed_mps": _debug_requested_speed_mps,
		"velocity_mps": Vector2(velocity.x, velocity.z).length(),
		"actual_speed_mps": _debug_actual_speed_mps,
		"nav_iteration": _debug_nav_iteration,
		"nav_state": _debug_nav_str,
		"next_path_distance_m": _debug_next_path_distance_m,
		"stall_elapsed_sec": _debug_patrol_stall_elapsed,
		"stall_reason": _debug_patrol_stall_reason,
	}


func _current_speed_mps() -> float:
	var chasing: bool = _state == State.ALERT or _state == State.CHASE or _state == State.APPROACH
	var tier: int = enemy_resource.chase_speed_tier if chasing else enemy_resource.patrol_speed_tier
	return GameBalance.get_speed(tier)


# --- Percepción: visión y oído ---------------------------------------------

## Valores devueltos por _evaluate_vision(): "none" (no cumple lo básico),
## "alert" (lo vio pero no lo suficiente para identificarlo del todo) o
## "chase" (identificación confirmada: tiempo sostenido + luz suficiente,
## o el override de proximidad).
const VISION_NONE: String = "none"
const VISION_ALERT: String = "alert"
const VISION_CHASE: String = "chase"


func _on_perception_tick() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	var vision_result: String = _evaluate_vision(player)
	_last_vision_result = vision_result
	var heard_player: bool = vision_result == VISION_NONE and _has_recent_sound_contact()
	_encounter_contact_valid = vision_result != VISION_NONE or heard_player
	_current_contact_kind = "VISION" if vision_result != VISION_NONE else ("SOUND" if heard_player else "NONE")

	if vision_result == VISION_CHASE:
		_on_player_seen(player.global_position, true)
	elif vision_result == VISION_ALERT:
		_on_player_seen(player.global_position, false)
	# El oído ya actualizó la posición en _on_player_noise_emitted(), con la
	# coordenada del evento. Nunca reemplazarla acá por player.global_position.

	if _encounter_contact_valid:
		_try_register_encounter_candidate()
	elif _must_lose_contact_before_reentry:
		# Un DROPPED debe perder el rastro y obtener una percepción NUEVA antes
		# de poder abrir otro encuentro; evita una cola automática al reset.
		_must_lose_contact_before_reentry = false
	elif _has_requested_encounter and not CombatEncounterManager.is_ambush_candidate_pending(self):
		# Retira de inmediato un candidato que ya no percibe al jugador. Esto
		# conserva la regla 5E: nunca se bloquea un combate por un contacto
		# extinguido mientras estaba abierta la ventana. Ambush es la excepción:
		# su candidato legítimo llega al lock con contacto NONE.
		CombatEncounterManager.withdraw_encounter_candidate(self)

	_update_debug_label()


## Evalúa distancia + FOV + línea de visión (igual que siempre: la luz NO
## participa acá, nunca es una barrera). Si eso falla, corta la racha de
## visibilidad sostenida y no hay nada más que evaluar.
##
## Si pasa, la luz de LA POSICIÓN DEL JUGADOR (no la del enemigo) modula la
## VELOCIDAD con la que se acumula _sight_timer hacia detection_time — no
## es un portón que bloquea la identificación por debajo de cierto valor.
## Con luz baja tarda más en confirmar CHASE; con capacidad 0.0 (curva en
## 0, luz total) nunca llega a acumular nada y el enemigo queda en ALERT
## indefinido mientras lo tenga a la vista — coherente con "imposible según
## enemigo" de la spec, sin necesitar un umbral aparte. Nunca hace una
## tirada de probabilidad: la decisión es determinística en cada chequeo,
## así se evita el parpadeo CHASE/NONE/CHASE de frames seguidos.
func _evaluate_vision(player: Node3D) -> String:
	if not _passes_vision_baseline(player):
		_sight_timer = 0.0
		_debug_light_str = "N/A"
		_debug_sight_str = "N/A"
		_debug_capability_str = "N/A"
		return VISION_NONE

	var light_level: int = LightingManager.get_light_level_at(player.global_position)
	_debug_light_str = "%d / 5" % light_level

	var capability: float = _get_light_detection_capability(light_level)
	if _is_within_proximity_override(player):
		capability = 1.0
	_debug_capability_str = "%.0f%%" % (capability * 100.0)

	_sight_timer += enemy_resource.perception_interval_sec * capability
	_debug_sight_str = "%.1f / %.1fs" % [_sight_timer, enemy_resource.detection_time_sec]

	if _sight_timer >= enemy_resource.detection_time_sec:
		return VISION_CHASE

	return VISION_ALERT


## Datos de la misma fuente que usa _passes_vision_baseline(), expuestos solo
## para que EnemyFovDebug dibuje el cono lógico real, no una versión decorativa.
func get_debug_fov_range_m() -> float:
	return enemy_resource.vision_range_tiles * GameBalance.tile_size_m if enemy_resource != null else 0.0


func get_debug_fov_angle_deg() -> float:
	return enemy_resource.vision_angle_deg if enemy_resource != null else 0.0


func get_debug_fov_color() -> Color:
	if _state == State.CHASE or _state == State.APPROACH or _state == State.COMBAT:
		return Color(1.0, 0.2, 0.2, 0.22)
	match _last_vision_result:
		VISION_ALERT:
			return Color(1.0, 0.8, 0.15, 0.18)
		_:
			return Color(0.2, 0.65, 1.0, 0.12)


## Distancia + FOV + línea de visión, SIN considerar iluminación — esto es
## lo único que puede hacer que "no vea nada" (junto con una pared en el
## camino). Una zona oscura nunca hace fallar esto. Cada etapa deja su
## propio dato de debug en N/A si no llegó a evaluarse (nunca inventa ni
## arrastra un valor viejo).
func _passes_vision_baseline(player: Node3D) -> bool:
	var eye_pos: Vector3 = global_position + Vector3.UP * 1.5
	var target_pos: Vector3 = player.global_position + Vector3.UP * 1.0

	var to_target: Vector3 = target_pos - eye_pos
	var flat_to_target: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
	var distance: float = flat_to_target.length()
	_debug_dist_str = "%.1f m" % distance

	var max_distance: float = enemy_resource.vision_range_tiles * GameBalance.tile_size_m
	if distance > max_distance or distance <= 0.001:
		_debug_fov_str = "N/A"
		_debug_los_str = "N/A"
		return false

	var forward: Vector3 = -global_transform.basis.z
	var flat_forward: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
	var angle_deg: float = rad_to_deg(flat_forward.angle_to(flat_to_target.normalized()))
	var in_fov: bool = angle_deg <= enemy_resource.vision_angle_deg / 2.0
	_debug_fov_str = "YES" if in_fov else "NO"
	if not in_fov:
		_debug_los_str = "N/A"
		return false

	# Una pared (o una puerta cerrada, el día que existan puertas como
	# geometría real) bloquea la visión: si el rayo choca contra algo antes
	# de llegar al jugador, no hay línea de visión.
	var has_los: bool = _has_clear_line(eye_pos, target_pos)
	_debug_los_str = "YES" if has_los else "NO"
	return has_los


## Capacidad de detección (0.0-1.0) según la tabla configurable del
## EnemyResource — ver EnemyResource.light_detection_curve.
func _get_light_detection_capability(light_level: int) -> float:
	var curve: Array = enemy_resource.light_detection_curve
	if curve.is_empty():
		return 1.0
	var index: int = clampi(light_level, 0, curve.size() - 1)
	return curve[index]


## Sección 7 de la spec: a distancia muy corta, con FOV y línea de visión
## ya confirmados por _passes_vision_baseline, la detección se fuerza a
## capacidad total sin importar la luz — nunca "estaba a medio metro
## mirándolo y no lo vio" por una tabla desfavorable.
func _is_within_proximity_override(player: Node3D) -> bool:
	var distance: float = global_position.distance_to(player.global_position)
	var override_distance_m: float = enemy_resource.proximity_override_tiles * GameBalance.tile_size_m
	return distance <= override_distance_m


func _can_hear_noise_event(noise_position: Vector3, noise_radius_m: float) -> bool:
	var distance: float = global_position.distance_to(noise_position)
	var hearing_range_m: float = enemy_resource.hearing_range_tiles * GameBalance.tile_size_m
	var effective_radius_m: float = max(noise_radius_m - _compute_door_attenuation_m(noise_position, global_position), 0.0)
	return distance <= min(hearing_range_m, effective_radius_m)


func _has_recent_sound_contact() -> bool:
	return Time.get_ticks_msec() - _last_heard_noise_time_msec <= int(SOUND_CONTACT_MEMORY_SEC * 1000.0)


## El EventBus entrega la posición del ruido en el instante en que el Player
## se movió. Este handler es la única entrada auditiva: no consulta al Player
## y no comparte la ruta de la visión incompleta.
func _on_player_noise_emitted(noise_position: Vector3, noise_radius_m: float, _intensity: float) -> void:
	if enemy_resource == null or enemy_resource.is_boss:
		return
	if not _can_hear_noise_event(noise_position, noise_radius_m):
		return
	_last_heard_noise_time_msec = Time.get_ticks_msec()
	_on_player_heard(noise_position)
	_encounter_contact_valid = true
	_current_contact_kind = "SOUND"
	_try_register_encounter_candidate()


## Cuánto reduce el alcance del ruido cualquier puerta cerrada entre el
## jugador y el enemigo (Sección 9 de la spec: "aproximadamente 1 unidad").
## Placeholder: hoy no existe ningún sistema de puertas en el proyecto, así
## que esto siempre da 0 — queda listo para sumar la atenuación real el día
## que haya puertas como nodos consultables en el mundo, sin tener que
## tocar _can_hear_player().
func _compute_door_attenuation_m(_from_pos: Vector3, _to_pos: Vector3) -> float:
	return 0.0


func _has_clear_line(from_pos: Vector3, to_pos: Vector3) -> bool:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos, WORLD_COLLISION_MASK)
	var result := space_state.intersect_ray(query)
	return result.is_empty()


# --- Máquina de estados ------------------------------------------------------

## La visión y el oído entran por funciones separadas a propósito. Una
## observación visual incompleta siempre queda en ALERT: noise_response_mode
## solo se consulta en _on_player_heard().
func _on_player_seen(position: Vector3, is_confirmed: bool) -> void:
	_last_known_player_position = position
	_last_known_source = "VISION"
	_searching_at_last_known = false
	_time_since_detection = 0.0

	match _state:
		State.PATROL, State.IDLE:
			if is_confirmed:
				_enter_chase()
			else:
				_state = State.ALERT
		State.ALERT:
			if is_confirmed:
				_enter_chase()
		State.CHASE:
			pass  # ya persiguiendo; la posición ya se actualizó arriba


## El modo de respuesta se aplica exclusivamente a un ruido confirmado.
func _on_player_heard(position: Vector3) -> void:
	_last_known_player_position = position
	_last_known_source = "SOUND"
	_searching_at_last_known = false
	_time_since_detection = 0.0

	match _state:
		State.PATROL, State.IDLE, State.ALERT:
			if enemy_resource.noise_response_mode == "chase_directly":
				_enter_chase()
			else:
				_state = State.ALERT
		State.CHASE:
			pass  # ya persiguiendo; la posición ya se actualizó arriba


## Confirma al jugador y avisa que lo detectó (evento separado de "entrando
## en combate": ver EventBus.enemy_detected) y pide entrar a un encuentro.
## Esto NO congela nada todavía: el enemigo sigue persiguiendo con
## movimiento normal hasta que CombatEncounterManager cierre la ventana y
## llame a begin_combat_approach().
func _enter_chase() -> void:
	_state = State.CHASE
	EventBus.enemy_detected.emit(self)
	_try_register_encounter_candidate()


## Un enemigo que llega tarde a un encuentro cerrado o completo no reintenta
## automáticamente después de CombatEncounterManager.reset(); debe perder el
## rastro y detectar de nuevo para abrir/entrar a otro encuentro válido.
func _try_register_encounter_candidate() -> void:
	# Un DROP sólo bloquea reingreso mientras siga vivo el mismo encuentro;
	# al terminarlo el próximo contacto vuelve a habilitar admisión normal.
	if not CombatEncounterManager.is_encounter_active() and _excluded_from_active_encounter:
		_excluded_from_active_encounter = false
		_encounter_join_closed = false
		if _encounter_debug_state == "DROPPED":
			_encounter_debug_state = "NONE"
	if _excluded_from_active_encounter:
		return
	if _must_lose_contact_before_reentry:
		return
	if _has_requested_encounter or _encounter_join_closed:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if _is_ambush_valid(player):
		_start_ambush_encounter(player)
		return

	var join_result: int = CombatEncounterManager.request_encounter_candidate(self)
	if join_result == CombatEncounterManager.CANDIDATE_ACCEPTED:
		_has_requested_encounter = true
		_encounter_debug_state = "CANDIDATE"
	else:
		_encounter_join_closed = true
		# Un rechazo pertenece al encounter activo/cerrado, igual que DROPPED:
		# mientras viva no puede reencolarse, pero reset() le devuelve
		# elegibilidad sin exigir un timeout artificial de pérdida de contacto.
		_excluded_from_active_encounter = CombatEncounterManager.is_encounter_active()
		_encounter_debug_state = "REJECTED"


func _start_ambush_encounter(player: Node3D) -> void:
	if player == null or _has_requested_encounter or _encounter_join_closed or _excluded_from_active_encounter:
		return
	var result := CombatEncounterManager.request_encounter_candidate(self, true)
	if result == CombatEncounterManager.CANDIDATE_ACCEPTED:
		_has_requested_encounter = true
		_ambush_candidate_registered = true
		_encounter_debug_state = "CANDIDATE"
		EventBus.ambush_ready.emit(self, player)
	else:
		_encounter_join_closed = true
		_excluded_from_active_encounter = CombatEncounterManager.is_encounter_active()
		_encounter_debug_state = "REJECTED"


func _is_ambush_valid(player: Node3D) -> bool:
	if player == null or not player.has_method("get_movement_state_label") or player.get_movement_state_label() != "STEALTH":
		return false
	if _current_contact_kind != "NONE" or _state not in [State.PATROL, State.IDLE, State.ALERT] or _has_requested_encounter or _encounter_join_closed or _excluded_from_active_encounter:
		return false
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return false
	var zone_center := global_position - forward.normalized() * AMBUSH_ZONE_DISTANCE_M
	var relative := player.global_position - zone_center
	relative.y = 0.0
	return relative.length() <= 0.5


func get_debug_ambush_candidate_registered() -> bool:
	return _ambush_candidate_registered


func get_debug_ambush_conditions(player: Node3D) -> Dictionary:
	var stealth: bool = player != null and player.has_method("get_movement_state_label") and player.get_movement_state_label() == "STEALTH"
	var zone_distance := INF
	if player != null:
		var forward := -global_transform.basis.z
		forward.y = 0.0
		if forward.length_squared() > 0.001:
			var relative := player.global_position - (global_position - forward.normalized() * AMBUSH_ZONE_DISTANCE_M)
			relative.y = 0.0
			zone_distance = relative.length()
	return {"stealth":stealth, "zone_distance":zone_distance, "in_zone":zone_distance <= 0.5, "contact":_current_contact_kind, "state":State.keys()[_state], "requested":_has_requested_encounter, "join_closed":_encounter_join_closed, "excluded":_excluded_from_active_encounter, "valid":_is_ambush_valid(player)}


func is_encounter_contact_valid() -> bool:
	return _encounter_contact_valid


## Consulta puntual usada al cerrar la ventana de encuentro. No avanza el
## sight_timer ni cambia de estado: solo verifica el contacto geométrico o
## auditivo vigente, para que la decisión de lock no use un tick anterior.
func refresh_encounter_contact_valid() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		_encounter_contact_valid = false
		return false

	var has_visual_baseline: bool = _passes_vision_baseline(player)
	var has_hearing_contact: bool = not has_visual_baseline and _has_recent_sound_contact()
	_encounter_contact_valid = has_visual_baseline or has_hearing_contact
	return _encounter_contact_valid


func mark_encounter_joined() -> void:
	_encounter_debug_state = "JOINED"


func release_encounter_candidate() -> void:
	_has_requested_encounter = false
	_encounter_contact_valid = false
	_encounter_debug_state = "NONE"
	_encounter_owns_enemy = false


func get_debug_state_name() -> String:
	return State.keys()[_state]


func get_debug_last_known_position() -> Vector3:
	return _last_known_player_position


func get_debug_last_known_source() -> String:
	return _last_known_source


func get_debug_ai_owner() -> String:
	return "COMBAT" if _state == State.COMBAT else ("ENCOUNTER" if _encounter_owns_enemy else "EXPLORATION")


func get_debug_movement_source() -> String:
	if _encounter_owns_enemy and _state == State.APPROACH:
		return "COMBAT POSITIONING"
	if _state == State.PATROL:
		return "PATROL"
	if _encounter_contact_valid:
		return "LIVE CHASE"
	if _searching_at_last_known:
		return "SEARCH"
	return "LAST KNOWN" if _last_known_source != "NONE" else "NONE"


func get_debug_ai_stalled() -> bool:
	return _debug_ai_stall_elapsed >= 1.0


func get_debug_physical_movement_state() -> String:
	return _debug_physical_movement_str


func get_debug_rotation_owner() -> String:
	return _debug_rotation_owner


func get_debug_desired_heading() -> Vector3:
	return _debug_desired_heading


func get_debug_physical_heading() -> Vector3:
	return _debug_physical_heading


func get_debug_navigation_waypoint() -> Vector3:
	return _debug_nav_waypoint


func get_debug_stuck_recovery_count() -> int:
	return _debug_stuck_recovery_count


func get_debug_encounter_state() -> String:
	return _encounter_debug_state


func get_debug_has_combat_positioning() -> bool:
	return _encounter_owns_enemy or _target_player != null


func _check_lose_target_timeout() -> void:
	if _state != State.ALERT or not _searching_at_last_known:
		return
	if _time_since_detection < enemy_resource.lose_target_timeout_sec:
		return

	_state = State.PATROL if enemy_resource.can_patrol else State.IDLE
	_has_requested_encounter = false
	_encounter_join_closed = false
	_encounter_contact_valid = false


## CHASE significa que el enemigo tiene percepción actual; al perderla,
## corre hasta la última coordenada obtenida y pasa a ALERT en cuanto llega.
## La persistencia se expresa con lose_target_timeout_sec durante ALERT, no
## manteniendo un CHASE quieto con información obsoleta.
func _process_chase(delta: float) -> void:
	_debug_requested_speed_mps = _current_speed_mps()
	if _encounter_contact_valid:
		# Sólo VISION actual usa distancia de parada para encuentro. SOUND es
		# información situada: debe investigar físicamente el evento y reemplazar
		# cualquier ruta previa, sin convertir oído en posición de combate.
		if _current_contact_kind == "VISION":
			var stop_distance_m: float = enemy_resource.combat_distance_tiles * GameBalance.tile_size_m
			if CombatEncounterManager.is_encounter_active() and not _excluded_from_active_encounter:
				stop_distance_m = max(stop_distance_m, CombatEncounterManager.bystander_standoff_distance_m)
			_move_toward_point(_last_known_player_position, _current_speed_mps(), delta, stop_distance_m)
		else:
			_move_toward_point(_last_known_player_position, _current_speed_mps(), delta)
		return

	var reached_last_known: bool = _move_toward_point(_last_known_player_position, _current_speed_mps(), delta)
	if reached_last_known or _debug_nav_str == "NO PATH":
		_begin_last_known_search()


func _begin_last_known_search() -> void:
	_state = State.ALERT
	_searching_at_last_known = true
	# A partir de acá el timeout mide búsqueda en ALERT, no el tiempo que
	# demoró el desplazamiento hasta la posición conocida.
	_time_since_detection = 0.0
	_has_requested_encounter = false
	_encounter_contact_valid = false


# --- Boss --------------------------------------------------------------------

func _on_boss_trigger_entered(body: Node3D) -> void:
	if _state != State.BOSS_IDLE:
		return
	if not body.is_in_group("player"):
		return
	_encounter_contact_valid = true
	_try_register_encounter_candidate()


# --- Interfaz usada por CombatEncounterManager -------------------------------

## Llamado por CombatEncounterManager cuando el encuentro ya quedó definido
## (se cerró la ventana de detección simultánea). slot_angle_deg es la
## posición que le tocó respecto de hacia dónde mira el jugador (0 = de
## frente; con 2 enemigos, uno a cada lado) — así, con más de un enemigo,
## cada uno persigue un punto distinto en vez de converger todos al mismo
## lugar. A partir de acá el enemigo persigue físicamente la posición EN
## VIVO del jugador (recalculada cada frame). Nada se teletransporta.
func begin_combat_approach(player: Node3D, slot_angle_deg: float = 0.0) -> void:
	_target_player = player
	_combat_slot_angle_deg = slot_angle_deg
	_encounter_owns_enemy = true
	_excluded_from_active_encounter = false

	if enemy_resource.is_boss:
		# El boss todavía no tiene movimiento propio (Sección 3): ya está
		# parado en su sala, así que cuenta como "en posición" de inmediato.
		_finish_combat_approach()
		return

	_state = State.APPROACH
	_encounter_debug_state = "APPROACH"
	_approach_elapsed = 0.0
	_update_debug_label()


func _process_combat_approach(delta: float) -> void:
	if _target_player == null:
		_finish_combat_approach()
		return
	# El slot guía la aproximación, pero READY se decide por la banda física
	# de combate. No obligar a cruzar un píxel de coordenada de slot cuando
	# ya está navegable, separado y a combat_distance razonable.
	if is_combat_position_valid(_target_player, CombatEncounterManager.combat_distance_tolerance_m):
		_finish_combat_approach()
		return

	_approach_elapsed += delta
	var slot_target: Vector3 = _compute_slot_target_position()
	if not _debug_combat_slot_valid:
		# No se fuerza un slot dentro de una pared. El timeout existente del
		# encounter conserva su fallback explícito DROPPED en vez de dejar una
		# navegación falsa contra geometría.
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var arrived: bool = _move_toward_point(slot_target, _current_speed_mps(), delta, COMBAT_SLOT_ARRIVE_THRESHOLD_M)

	# Orientarse hacia el JUGADOR (no hacia el punto de acceso, que puede
	# quedar a un costado si hay más de un enemigo) — así termina mirando
	# de frente, no mirando para el costado por donde entró.
	var to_player: Vector3 = _target_player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.05:
		look_at(global_position + to_player.normalized(), Vector3.UP)
		_debug_rotation_owner = "APPROACH PLAYER"

	if arrived and is_combat_position_valid(_target_player, CombatEncounterManager.combat_distance_tolerance_m):
		_finish_combat_approach()


## Calcula el punto al que este enemigo tiene que caminar: a
## combat_distance_tiles del jugador, en el ángulo asignado respecto de
## hacia dónde mira el jugador (recalculado cada frame, siguiendo al
## jugador en vivo). Si ese punto queda del otro lado de una pared, prueba
## ángulos progresivamente más cercanos al frente hasta encontrar uno
## despejado — nunca se teletransporta, esto solo decide HACIA DÓNDE
## caminar; el desplazamiento sigue siendo move_and_slide() cuadro a cuadro.
func _compute_slot_target_position() -> Vector3:
	var player_pos: Vector3 = _target_player.global_position
	var player_forward: Vector3 = -_target_player.global_transform.basis.z
	var flat_forward: Vector3 = Vector3(player_forward.x, 0.0, player_forward.z)
	if flat_forward.length() < 0.01:
		flat_forward = Vector3(0.0, 0.0, -1.0)
	else:
		flat_forward = flat_forward.normalized()

	var desired_distance: float = enemy_resource.combat_distance_tiles * GameBalance.tile_size_m

	# El slot natural se prueba primero. Si toca una pared, se exploran offsets
	# simétricos y acotados: no se reubica artificialmente frente a la cámara.
	var offsets := [0.0, 20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0, 180.0]
	for offset_deg in offsets:
		var angle_deg: float = _combat_slot_angle_deg + offset_deg
		var candidate: Vector3 = player_pos + flat_forward.rotated(Vector3.UP, deg_to_rad(angle_deg)) * desired_distance
		candidate.y = global_position.y
		if _is_valid_combat_slot(candidate, player_pos):
			_debug_combat_slot_valid = true
			return candidate

	_debug_combat_slot_valid = false
	return global_position


func _is_valid_combat_slot(candidate: Vector3, player_pos: Vector3) -> bool:
	var map := get_world_3d().get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var projected := NavigationServer3D.map_get_closest_point(map, candidate)
	_debug_combat_slot_world = candidate
	_debug_combat_slot_navigation = projected
	_debug_combat_slot_lateral_error_m = Vector2(candidate.x, candidate.z).distance_to(Vector2(projected.x, projected.z))
	_debug_combat_slot_vertical_error_m = absf(candidate.y - projected.y)
	# No se acepta una proyección que esconda un slot inválido detrás de una
	# pared/esquina. La NavigationMesh puede vivir a otra Y que el origen del
	# CharacterBody (pies/superficie navegable frente al centro de cápsula),
	# así que sólo el desplazamiento lateral indica que la proyección saltó a
	# otra zona o atravesó una pared. El path usa `projected` más abajo y la
	# ocupación física continúa validándose con `candidate` en world space.
	if _debug_combat_slot_lateral_error_m > 0.12:
		return false
	var path := NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, global_position), projected, true)
	if path.size() < 2:
		return false
	if candidate.distance_to(player_pos) < CombatEncounterManager.combat_min_distance_m or candidate.distance_to(player_pos) > CombatEncounterManager.combat_max_distance_m:
		return false
	if not _has_clear_line(candidate + Vector3.UP, player_pos + Vector3.UP):
		return false
	return _has_capsule_clearance(candidate)


func _has_capsule_clearance(position: Vector3) -> bool:
	if collision_shape == null or collision_shape.shape == null:
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = Transform3D(global_transform.basis, position)
	query.collision_mask = WORLD_COLLISION_MASK
	query.exclude = [get_rid()]
	var overlaps := get_world_3d().direct_space_state.intersect_shape(query, 16)
	for overlap in overlaps:
		var collider: Object = overlap.get("collider")
		# Los pisos CSG son cuerpos de layer 1, pero tocar el suelo es necesario
		# para el CharacterBody y no invalida el clearance lateral del slot.
		if collider is CSGBox3D and (collider as CSGBox3D).size.y <= 0.5:
			continue
		return false
	return true


## Deja de perseguir/acercarse y queda en COMBAT ahí donde esté, sin
## avisarle de nuevo a CombatEncounterManager. Uso normal: llamado
## internamente por _finish_combat_approach(). Uso de emergencia: llamado
## DIRECTAMENTE por CombatEncounterManager como red de seguridad (timeout
## global del encuentro), en cuyo caso es el propio manager el que ya sabe
## que este enemigo quedó "en posición" y no hace falta notificarle de nuevo.
func force_finish_combat_approach() -> void:
	# Ya no se usa para convertir un timeout/navegación rota en combate.
	# El manager decide cancelar o soltar participantes inválidos.
	pass


func _finish_combat_approach() -> void:
	if _target_player == null or not is_combat_position_valid(_target_player, CombatEncounterManager.combat_distance_tolerance_m):
		return
	_apply_combat_freeze()
	CombatEncounterManager.notify_enemy_in_position(self)


func is_combat_position_valid(player: Node3D, tolerance_m: float) -> bool:
	if player == null or enemy_resource == null:
		return false
	var distance := global_position.distance_to(player.global_position)
	return distance >= CombatEncounterManager.combat_min_distance_m and distance <= CombatEncounterManager.combat_max_distance_m


func is_encounter_still_viable(player: Node3D, tolerance_m: float) -> bool:
	# Un participante demasiado cerca sigue siendo recuperable: debe poder
	# retroceder a la banda. Uno lejos y sin contacto mantiene la regla de
	# escape y puede ser descartado por el manager.
	if player == null:
		return false
	return _encounter_contact_valid or global_position.distance_to(player.global_position) <= CombatEncounterManager.combat_max_distance_m


func abort_combat_approach() -> void:
	# Separa definitivamente el estado exclusivo de positioning de la IA de
	# exploración. NO borra LAST KNOWN ni contacto: ambos siguen siendo datos
	# sensoriales válidos de este Enemy.
	_target_player = null
	velocity = Vector3.ZERO
	_combat_slot_angle_deg = 0.0
	_approach_elapsed = 0.0
	_encounter_owns_enemy = false
	_excluded_from_active_encounter = CombatEncounterManager.is_encounter_active()
	_must_lose_contact_before_reentry = true
	_has_requested_encounter = false
	_encounter_join_closed = _excluded_from_active_encounter
	_encounter_debug_state = "DROPPED"
	if _encounter_contact_valid:
		_state = State.CHASE
		_searching_at_last_known = false
	elif _last_known_source != "NONE" and global_position.distance_to(_last_known_player_position) > ARRIVE_THRESHOLD_M:
		# Un APPROACH cancelado no autoriza empezar SEARCH a distancia. Mantiene
		# la invariante: LAST KNOWN pendiente implica objetivo de navegación.
		_state = State.CHASE
		_searching_at_last_known = false
	else:
		_begin_last_known_search()


func _apply_combat_freeze() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	if _target_player != null:
		look_at(Vector3(_target_player.global_position.x, global_position.y, _target_player.global_position.z), Vector3.UP)
		_debug_rotation_owner = "COMBAT PLAYER"
		_state = State.COMBAT
		_encounter_owns_enemy = true
		_encounter_debug_state = "READY"
	_update_debug_label()


func mark_combat_started() -> void:
	_encounter_debug_state = "COMBAT"
	_update_debug_label()


func _update_debug_label() -> void:
	_update_last_known_debug_marker()
	if debug_label == null:
		return

	var text: String = "STATE: %s" % State.keys()[_state]

	if DebugConfig.perception_debug_enabled and enemy_resource != null and not enemy_resource.is_boss:
		text += "\nDIST: %s" % _debug_dist_str
		text += "\nFOV: %s   LOS: %s" % [_debug_fov_str, _debug_los_str]
		text += "\nPLAYER LIGHT: %s" % _debug_light_str
		text += "\nSIGHT: %s" % _debug_sight_str
		text += "\nCAPABILITY: %s" % _debug_capability_str
		var contact_text := _last_known_source if _encounter_contact_valid else "NONE"
		var pursuit_text := "LIVE CONTACT" if _encounter_contact_valid else ("SEARCHING" if _searching_at_last_known else "TO LAST KNOWN")
		var owner_text := "COMBAT" if _state == State.COMBAT else ("ENCOUNTER" if _encounter_owns_enemy else "EXPLORATION")
		var movement_source := "COMBAT POSITIONING" if _encounter_owns_enemy and _state == State.APPROACH else ("PATROL" if _state == State.PATROL else ("LIVE CHASE" if _encounter_contact_valid else ("SEARCH" if _searching_at_last_known else ("LAST KNOWN" if _last_known_source != "NONE" else "NONE"))))
		text += "\nCONTACT: %s" % contact_text
		text += "\nLAST KNOWN: %s" % _last_known_source
		text += "\nLAST KNOWN DIST: %.1f" % global_position.distance_to(_last_known_player_position)
		text += "\nPURSUIT: %s" % pursuit_text
		text += "\nAI OWNER: %s" % owner_text
		text += "\nENCOUNTER: %s" % _encounter_debug_state
		text += "\nMOVEMENT SOURCE: %s" % movement_source
		if _encounter_owns_enemy and _state == State.APPROACH and _target_player != null:
			var combat_distance := global_position.distance_to(_target_player.global_position)
			var positioning := "VALID" if combat_distance >= CombatEncounterManager.combat_min_distance_m and combat_distance <= CombatEncounterManager.combat_max_distance_m else ("TOO CLOSE" if combat_distance < CombatEncounterManager.combat_min_distance_m else "TOO FAR")
			text += "\nCOMBAT DIST: %.1f" % combat_distance
			text += "\nVALID BAND: %.1f-%.1f" % [CombatEncounterManager.combat_min_distance_m, CombatEncounterManager.combat_max_distance_m]
			text += "\nPOSITIONING: %s" % positioning
		text += "\nNAV: %s" % _debug_nav_str
		text += "\nNAV TARGET: %s" % _debug_nav_target_str
		text += "\nPHYSICAL MOVEMENT: %s" % _debug_physical_movement_str
		if _debug_stuck_recovery_count > 0:
			text += "\nSTUCK RECOVERY COUNT: %d" % _debug_stuck_recovery_count
		text += "\nROTATION OWNER: %s" % _debug_rotation_owner
		text += "\nDESIRED HEADING: %.1f, %.1f" % [_debug_desired_heading.x, _debug_desired_heading.z]
		text += "\nPHYSICAL HEADING: %.1f, %.1f" % [_debug_physical_heading.x, _debug_physical_heading.z]
		if _debug_nav_waypoint != Vector3.INF:
			text += "\nNAV WAYPOINT: %.1f, %.1f" % [_debug_nav_waypoint.x, _debug_nav_waypoint.z]
		if _state == State.PATROL:
			text += "\nPATROL: %s" % _debug_patrol_target_str
			text += "\nTARGET DIST: %.2f" % _debug_patrol_target_distance_m
			text += "\nREQ SPEED: %.2f" % _debug_requested_speed_mps
			text += "\nVELOCITY: %.2f" % Vector2(velocity.x, velocity.z).length()
			text += "\nACTUAL SPEED: %.2f" % _debug_actual_speed_mps
			text += "\nNAV ITER: %d" % _debug_nav_iteration
			text += "\nNEXT: %.2f" % _debug_next_path_distance_m
			if _debug_patrol_stall_elapsed >= 1.0:
				text += "\nPATROL STALLED: %s" % _debug_patrol_stall_reason
		if _debug_ai_stall_elapsed >= 1.0:
			text += "\nAI STALLED: %s" % _debug_ai_stall_reason

	debug_label.text = text


func _update_last_known_debug_marker() -> void:
	if _last_known_marker == null:
		return
	var visible_marker := DebugConfig.perception_debug_enabled and _last_known_source != "NONE"
	_last_known_marker.visible = visible_marker
	if not visible_marker:
		return
	_last_known_marker.global_position = Vector3(_last_known_player_position.x, 0.04, _last_known_player_position.z)
	var material := _last_known_marker.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = Color(0.3, 0.75, 1.0, 0.85) if _last_known_source == "VISION" else Color(1.0, 0.55, 0.1, 0.85)


func _update_ambush_zone_debug() -> void:
	if _ambush_zone_marker == null:
		return
	var forward: Vector3 = -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		return
	forward = forward.normalized()
	_ambush_zone_marker.visible = DebugConfig.perception_debug_enabled
	_ambush_zone_marker.global_position = global_position - forward * AMBUSH_ZONE_DISTANCE_M + Vector3.UP * 0.03
	_ambush_zone_marker.global_rotation.y = atan2(forward.x, forward.z)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var relative: Vector3 = player.global_position - _ambush_zone_marker.global_position
	relative.y = 0.0
	var in_zone := relative.length() <= 0.5
	if in_zone and not _player_was_in_ambush_zone:
		player_entered_ambush_zone.emit(player)
		# Sólo puede armarse antes de que este enemigo haya adquirido al Player.
		if _is_ambush_valid(player):
			_start_ambush_encounter(player)
	_player_was_in_ambush_zone = in_zone
