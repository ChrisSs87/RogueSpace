extends Node

## CombatEncounterManager.gd (autoload)
## Decide qué enemigos entran juntos a un mismo combate y coordina que
## lleguen físicamente a distancia de combate antes de avisar que el
## combate empieza de verdad (Sección 10). No hay teletransporte: la
## aproximación la hace cada Enemy.gd persiguiendo al jugador.
##
## DECISIÓN DE DISEÑO (fija): los enemigos conservan su posición espacial
## REAL respecto del jugador (delante, detrás, al costado — lo que
## corresponda según por dónde lo alcanzaron). NO se los reposiciona a un
## arco frontal artificial: eso obligaba a un enemigo que venía por detrás a
## caminar rodeando al jugador para "entrar en cámara", lo cual además de
## verse mal podía trabarlo contra paredes en pasillos angostos. La única
## corrección que se aplica es una separación mínima cuando dos enemigos
## quedarían casi exactamente en el mismo ángulo (para que no se pisen entre
## sí) — nunca se los empuja hacia el frente del jugador.
##
## Localizar enemigos fuera de cámara (ej. uno atacando por la espalda)
## queda para un indicador direccional del Scanner más adelante; por ahora
## el jugador gira la cámara libremente para ubicarlos (ver Player.gd).
##
## Sección 9: solo existen el caso individual (un enemigo solo) y el caso de
## detección simultánea (cualquier otro enemigo que detecte al jugador dentro
## de join_window_sec se suma). No hay "grupos preparados" que se sumen
## automáticamente: si un enemigo no detecta al jugador por sí mismo dentro
## de la ventana, no entra al combate, sin importar dónde esté parado.
##
## LIMITACIÓN CONOCIDA DE ESTA ETAPA: solo administra UN encuentro por
## sesión de juego a la vez (no hay todavía forma de tener dos combates
## corriendo en paralelo en distintas zonas de la dungeon).

@export var join_window_sec: float = 1.5
## El diseño original (Sección 9) preveía hasta 3, pero CombatManager por
## ahora solo sabe resolver hasta 2 combatants (ver
## CombatManager.MAX_COMBATANTS_THIS_STAGE). Subir esto sin ampliar
## CombatManager dejaría a un enemigo de más congelado sin lógica de turno.
@export var max_enemies_per_combat: int = 2

## Separación angular MÍNIMA (grados) entre dos enemigos del mismo encuentro.
## Solo actúa si, por sus posiciones reales, quedarían casi superpuestos
## (dentro de este margen); en ese caso se los separa lo justo y necesario,
## simétricamente, SIN moverlos hacia el frente del jugador. Si ya están
## suficientemente separados (ej. uno adelante y otro atrás), no se toca nada.
@export var min_separation_deg: float = 30.0

## Timeout diagnóstico de APPROACH. Nunca fuerza combate: al vencer descarta
## participantes lejos/sin contacto y solo deja continuar a los válidos.
@export var global_encounter_timeout_sec: float = 10.0
## Margen pequeño para redondeo físico alrededor de combat_distance.
@export var combat_distance_tolerance_m: float = 0.35
## Banda provisional cómoda para primera persona/Cardboard. Los recursos
## siguen definiendo el objetivo ideal (hoy 2.5 m); esta banda decide READY.
@export var combat_min_distance_m: float = 2.0
@export var combat_max_distance_m: float = 3.0

## Interruptor central para pruebas de exploración/IA sin combate. Mientras
## esto sea false:
##   - la detección, ALERT/CHASE, persecución física y pérdida del jugador
##     siguen funcionando en cada Enemy.gd exactamente igual que siempre;
##   - CombatEncounterManager sigue registrando el encuentro (queda en
##     _pending_enemies) para cuando corresponda usarlo;
##   - pero NUNCA se llama a begin_combat_approach(), NUNCA se entra a
##     COMBAT, NUNCA se llama a player.freeze_for_combat() y el jugador
##     nunca pierde control de su input.
## Distancia mínima (metros) que debe mantener un enemigo AJENO a un
## combate activo si igual entra en CHASE por su cuenta (ej. patrullando
## cerca de donde ya se está peleando). Es una regla general del sistema de
## encuentros, no algo por especie: Enemy.gd la aplica en CHASE siempre que
## is_encounter_active() sea true y ese enemigo no sea parte del encuentro
## en curso (los que sí lo son ya pasaron a APPROACH/COMBAT, nunca están en
## CHASE mientras el encuentro está activo).
@export var bystander_standoff_distance_m: float = 5.0

@export var combat_transition_enabled: bool = true

const CANDIDATE_ACCEPTED: int = 0
const REJECTED_CLOSED: int = 1
const REJECTED_FULL: int = 2

var _pending_enemies: Array = []
var _window_timer: float = -1.0
var _encounter_locked: bool = false
var _enemies_in_position: Array = []
var _approach_timer: float = -1.0
## Participantes iniciados por emboscada: no requieren contacto sensorial al
## cerrar la ventana, porque Ambush es su propia ruta legítima a Encounter.
var _ambush_candidates: Array = []


## true desde que se cierra la ventana de detección hasta que termina el
## combate (aproximación + pelea entera) — cubre exactamente el período en
## el que NINGÚN otro enemigo debería poder sumarse ni acercarse de más.
func is_encounter_active() -> bool:
	return _encounter_locked


func _process(delta: float) -> void:
	if _window_timer >= 0.0:
		_window_timer -= delta
		if _window_timer <= 0.0:
			_lock_encounter()

	if _approach_timer >= 0.0:
		_approach_timer += delta
		_validate_approach_participants()
		if _approach_timer >= global_encounter_timeout_sec:
			_resolve_approach_timeout()


## Llamado por un Enemy.gd apenas confirma al jugador (entra en CHASE).
## Devuelve un resultado explícito: solo las detecciones dentro de la ventana
## abierta pueden sumarse. Un rechazo evita que el enemigo haga cola para el
## siguiente combate sin haber perdido y vuelto a detectar al jugador.
func request_encounter_candidate(enemy: Node3D, from_ambush: bool = false) -> int:
	if enemy in _pending_enemies:
		return CANDIDATE_ACCEPTED
	if _encounter_locked:
		return REJECTED_CLOSED
	if _pending_enemies.size() >= max_enemies_per_combat:
		return REJECTED_FULL

	_pending_enemies.append(enemy)
	if from_ambush:
		_ambush_candidates.append(enemy)

	# Ventana de detección simultánea: cualquier otro enemigo que detecte al
	# jugador por su cuenta dentro de este tiempo se suma al mismo combate.
	if _window_timer < 0.0:
		_window_timer = join_window_sec

	return CANDIDATE_ACCEPTED


## Un candidato que ya perdió visión/oído antes del lock deja de reservar una
## plaza. Si era el último, se cancela la ventana en ese mismo momento.
func withdraw_encounter_candidate(enemy: Node3D) -> void:
	if _encounter_locked or enemy not in _pending_enemies:
		return
	_pending_enemies.erase(enemy)
	if enemy.has_method("release_encounter_candidate"):
		enemy.release_encounter_candidate()
	if _pending_enemies.is_empty():
		_cancel_pending_encounter()


## Consulta read-only para Enemy.gd: Ambush es una ruta propia a Encounter y
## puede permanecer pendiente sin contacto VISION/SOUND hasta el lock.
func is_ambush_candidate_pending(enemy: Node3D) -> bool:
	return not _encounter_locked and enemy in _pending_enemies and enemy in _ambush_candidates


## Se cierra la ventana: queda definido quiénes participan. Acá se calcula
## el ángulo de posición de combate NATURAL de cada uno (dónde ya está
## respecto del jugador) y arranca el timeout global de seguridad. Si
## combat_transition_enabled es false, el encuentro queda "registrado" pero
## no se dispara ninguna transición real.
func _lock_encounter() -> void:
	_window_timer = -1.0
	var valid_enemies: Array = _pending_enemies.filter(func(e): return _is_valid_candidate(e))
	if valid_enemies.is_empty():
		_cancel_pending_encounter()
		return

	_pending_enemies = valid_enemies
	_encounter_locked = true

	if not combat_transition_enabled:
		return

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		_cancel_pending_encounter()
		return

	_approach_timer = 0.0

	var angles: Array = _compute_natural_angles(valid_enemies, player)

	for i in valid_enemies.size():
		valid_enemies[i].mark_encounter_joined()
		valid_enemies[i].begin_combat_approach(player, angles[i])


func _is_valid_candidate(enemy: Node) -> bool:
	# Se vuelve a consultar al enemigo justo al cerrar la ventana: el último
	# tick de percepción puede tener hasta perception_interval_sec de antigüedad.
	# Así, cortar FOV/LOS o el ruido antes del lock realmente cancela el
	# encuentro, en vez de depender de un valor de debug o de un estado viejo.
	return is_instance_valid(enemy) and (enemy in _ambush_candidates or (enemy.has_method("refresh_encounter_contact_valid") and enemy.refresh_encounter_contact_valid()))


func _cancel_pending_encounter() -> void:
	for enemy in _pending_enemies:
		if is_instance_valid(enemy) and enemy.has_method("release_encounter_candidate"):
			enemy.release_encounter_candidate()
	_pending_enemies = []
	_ambush_candidates = []
	_encounter_locked = false
	_enemies_in_position = []
	_approach_timer = -1.0


func get_debug_join_window_remaining() -> float:
	return maxf(_window_timer, 0.0)


func get_debug_pending_count() -> int:
	return _pending_enemies.size()


## Ángulo de cada enemigo respecto de hacia dónde mira el jugador, tal como
## están parados AHORA (posición espacial real, no un arco artificial). Si
## dos quedan casi superpuestos, se separan lo mínimo indispensable de forma
## simétrica — nunca se los acerca al frente.
func _compute_natural_angles(enemies: Array, player: Node3D) -> Array:
	var forward: Vector3 = -player.global_transform.basis.z
	var flat_forward: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()

	var angles: Array = []
	for enemy in enemies:
		var to_enemy: Vector3 = enemy.global_position - player.global_position
		var flat_to_enemy: Vector3 = Vector3(to_enemy.x, 0.0, to_enemy.z)
		var angle_deg: float = 0.0
		if flat_to_enemy.length() > 0.01:
			angle_deg = rad_to_deg(flat_forward.signed_angle_to(flat_to_enemy.normalized(), Vector3.UP))
		angles.append(angle_deg)

	if angles.size() == 2:
		var diff: float = wrapf(angles[1] - angles[0], -180.0, 180.0)
		if absf(diff) < min_separation_deg:
			var mid: float = angles[0] + diff / 2.0
			var half: float = min_separation_deg / 2.0
			if diff >= 0.0:
				angles[0] = mid - half
				angles[1] = mid + half
			else:
				angles[0] = mid + half
				angles[1] = mid - half

	return angles


## Llamado por cada Enemy.gd cuando llega a su posición de combate asignada
## (o se le agota su propio timeout de aproximación). Recién cuando TODOS
## los enemigos del encuentro están en posición se arranca el combate.
func notify_enemy_in_position(enemy: Node3D) -> void:
	if not combat_transition_enabled:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null or not _is_combat_ready(enemy, player):
		return
	if enemy in _enemies_in_position:
		return
	_enemies_in_position.append(enemy)

	if _enemies_in_position.size() < _pending_enemies.size():
		return

	_start_combat_now()


## Red de seguridad de encuentro completo: si el timeout global se cumple
## antes de que todos hayan avisado individualmente, se fuerza a los que
## faltan a quedar congelados donde estén (sin seguir caminando durante el
## combate) y se arranca igual.
func _force_start_combat() -> void:
	_resolve_approach_timeout()


func _validate_approach_participants() -> void:
	if not _encounter_locked:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		_cancel_pending_encounter()
		return
	var retained: Array = []
	for enemy in _pending_enemies:
		if is_instance_valid(enemy) and _is_encounter_viable(enemy, player):
			retained.append(enemy)
		elif is_instance_valid(enemy) and enemy.has_method("abort_combat_approach"):
			enemy.abort_combat_approach()
	_pending_enemies = retained
	_enemies_in_position = _enemies_in_position.filter(func(enemy): return enemy in _pending_enemies)
	if _pending_enemies.is_empty():
		_cancel_pending_encounter()


func _resolve_approach_timeout() -> void:
	push_warning("CombatEncounterManager: timeout de APPROACH; verificando posiciones, sin forzar combate.")
	_validate_approach_participants()
	if not _encounter_locked:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var ready: Array = _pending_enemies.filter(func(enemy): return _is_combat_ready(enemy, player))
	for enemy in _pending_enemies:
		if enemy not in ready and is_instance_valid(enemy) and enemy.has_method("abort_combat_approach"):
			enemy.abort_combat_approach()
	_pending_enemies = ready
	_enemies_in_position = ready
	if ready.is_empty():
		_cancel_pending_encounter()
		return
	_start_combat_now()


func _is_encounter_viable(enemy: Node, player: Node3D) -> bool:
	return is_instance_valid(enemy) and enemy.has_method("is_encounter_still_viable") and enemy.is_encounter_still_viable(player, combat_distance_tolerance_m)


func _is_combat_ready(enemy: Node, player: Node3D) -> bool:
	return is_instance_valid(enemy) and enemy.has_method("is_combat_position_valid") and enemy.is_combat_position_valid(player, combat_distance_tolerance_m)


func _start_combat_now() -> void:
	_approach_timer = -1.0

	var player: Node3D = get_tree().get_first_node_in_group("player")
	var valid_enemies: Array = _pending_enemies.filter(func(enemy): return _is_combat_ready(enemy, player))
	if valid_enemies.is_empty():
		_cancel_pending_encounter()
		return
	_pending_enemies = valid_enemies
	for enemy in valid_enemies:
		if enemy.has_method("mark_combat_started"):
			enemy.mark_combat_started()
	if player != null and player.has_method("freeze_for_combat"):
		player.freeze_for_combat()

	EventBus.combat_ready.emit(player, valid_enemies)


## Llamado por CombatManager cuando un combate termina (victoria). Sin esto,
## el manager quedaría bloqueado para siempre después del primer encuentro.
func reset() -> void:
	_pending_enemies = []
	_window_timer = -1.0
	_encounter_locked = false
	_enemies_in_position = []
	_approach_timer = -1.0
	_ambush_candidates = []
