# RogueSpace — CURRENT STATE / IMPLEMENTATION CHECKPOINT

Version: 0.2 — September 20, 2026

## How to use this file

This is the current implementation checkpoint, not the design constitution.

- `RogueSpace_CORE_Design_UPDATED.md` = stable/non-negotiable design rules.
- `RogueSpace_CURRENT_State_UPDATED.md` = what is currently implemented, what is provisional, and what remains to be tested.
- If code and this file disagree, report the discrepancy rather than silently assuming one is correct.

## Current development strategy

The immediate priority is to stabilize exploration perception and logical lighting before adding advanced stealth, visual lighting synchronization or other systems.

Current sequence:

1. Stabilize perception + logical lighting.
2. Run manual Godot tests.
3. Adjust balance based on observed behavior.
4. Freeze perception/lighting for the demo.
5. Continue with the next gameplay milestone.
6. Implement later stealth/ambush and visual-lighting refinements only after the foundation feels correct.

The first demo remains intentionally small: Orc fortress → xenomorph cave → giant xenomorph boss room.

## Etapa 6A.3 — navegación productiva B+C de Fortress6A

Fortress6A usa una única navegación productiva bakeada en runtime. Los
`CSGBox3D` arquitectónicos siguen siendo la fuente geométrica de verdad:

`CSGBox3D → proxy StaticBody3D/CollisionShape3D → bake global → NavigationRegion3D → NavigationAgent3D`.

`Fortress6A.gd` genera automáticamente 43 proxies a partir de transform,
tamaño y orientación reales de los CSG. Los proxies se agrupan como fuente
explícita de bake y usan layer 32 / mask 0: son parseables por
`STATIC_COLLIDERS`, pero no intervienen en Player, Enemy, raycasts de visión,
percepción ni combate. La configuración vigente es `agent_radius=0.55`,
`agent_height=1.80`, `agent_max_climb=0.20`, `agent_max_slope=1.0°`,
`cell_size=0.05`, `cell_height=0.10` y filtrado de spans bajos. El bake
validado produce 116 vértices y 116 polígonos navegables a partir de 3096
vértices / 1548 índices fuente.

Las regiones y puentes manuales anteriores están retirados de la escena
productiva; no existe una segunda región superpuesta. Las mallas manuales
históricas permanecen únicamente como subrecursos sin nodos activos y no
participan del NavigationMap.

Cada Enemy tiene un `NavigationAnchor` padre de su `NavigationAgent3D`. Una
vez sincronizado el NavigationMap, el ancla deriva su offset vertical desde el
`closest_point` real del mapa. Esto separa correctamente la altura world del
CharacterBody de la superficie de navegación: no mueve collider, cuerpo ni
visual, y evita que un waypoint con el mismo XZ pero Y de NavMesh quede sin
consumirse. Los slots de combate conservan `candidate_world` para distancia,
LOS y clearance físico; usan `projected_nav` para navegar y validan el error
de proyección sólo en XZ (máximo 0.12 m), nunca aceptando una pared por la
diferencia vertical normal.

La matriz física B+C de x=9, x=17, x=41 norte, x=41 sur, x=49, x=58 y x=66
es CLEAN en ambos sentidos, con clearance mínimo de 0.500 m y zero stuck
recovery. Spawn→Well y Well→Spawn también son CLEAN (0.536 m y 0.530 m). Los
harnesses validan soporte físico y proyección de cada endpoint, y clasifican
un punto inválido como entrada de test inválida, no como un fallo de esquina.

La deuda para dungeons futuras es conservar este pipeline para módulos
ensamblados: módulos → proxies derivados → bake global → navegación. No hay
generación procedural implementada todavía.

## Etapa 6A.1 — Fortaleza Orca greybox

`scenes/MainFortress6A.tscn` is now the temporary main scene for gameplay
testing. It uses the existing Player, Android/PC controls, combat UI, rewards,
and debug tools while leaving `DungeonSandbox` intact as the technical
regression sandbox.

`scenes/dungeon/Fortress6A.tscn` is a hand-authored greybox first floor:
safe entry → initial corridor → crossroads → dark Storage / lit Barracks →
convergence → final guard corridor → antechamber → Well placeholder. It has
four Orcs: initial Melee, Storage Rogue, Barracks Melee, and final Rogue. The
branch patrols converge near the final guard corridor, allowing a potential
two-enemy encounter through normal independent perception.

The floor has one continuous `NavigationRegion3D` / NavigationMesh for rooms,
branches, corridors, patrols, CHASE, ALERT, and APPROACH. Its greybox uses the
reusable `RoomMedium`, `RoomSmall`, and `CorridorStraight` modules, plus
scene-level walls and branch connectors. Logical lighting is deliberate:
low/moderate entry, readable crossroads, unlit Storage, brighter Barracks,
dangerous final corridor, and a distinctive Well torch. It uses existing
`LightingManager` + `LightSource`; visual/logical light synchronization is
still deferred.

The Well is a temporary end trigger: it shows `FIN FORTALEZA 6A` and a
`REINICIAR PRUEBA` action. It does not descend, transition scenes, or spawn
Xenomorph content.

`fortress6a_validation` passed: safe Player spawn (no initial enemy contact),
spawn-to-Well route, all four A/B patrol routes, ten seconds of real patrol,
and the end trigger. Oxígeno is explicitly deferred to 6A.2 so its consumption
can be designed from real traversal data.

## Etapa 6A.1b — Last Known multisensorial + seguridad greybox

`_last_known_player_position` representa ahora la última posición obtenida
por cualquier sentido válido, con una única prioridad cronológica: una visión
válida guarda la posición visual y un ruido audible guarda la posición exacta
del evento de ruido. `Player.gd` emite `EventBus.player_noise_emitted` solo
cuando hubo desplazamiento real; el evento transporta posición, radio efectivo
e intensidad. `Enemy.gd` compara esa posición de evento contra hearing/radio
efectivos y nunca vuelve a consultar la posición actual del Player para
reinterpretar un ruido viejo.

Visión y oído siguen siendo rutas separadas: `noise_response_mode` solo se
consulta para un evento auditivo real, por lo que una ALERT visual no puede
convertirse erróneamente en CHASE. Después de perder visión/sonido, CHASE
navega a la última posición registrada; si no recibe otro evento audible, un
Player que continúe fuera de hearing no actualiza el objetivo. El debug de
percepción muestra `LAST KNOWN: VISION` o `SOUND` y un marcador de suelo
azul/naranja en esa posición, solo con `perception_debug_enabled`.

`stage6a1b_multisensory_validation` pasa la secuencia de integración
visión A → ruido B → silencio/fuera de hearing C con un Orco: B reemplaza A,
el Orco navega hacia B y C no se filtra como información nueva.

Se cerraron cuatro franjas sin suelo físico en los laterales del Cross y la
Convergence de Fortress6A. Coincidían con superficie navegable y podían causar
caídas/soft-lock accidentales; ahora tienen suelo y colisión greybox sin
cambiar layout, navegación ni introducir una mecánica de caída.

La batería obligatoria de Etapa 5 sigue siendo regresión requerida para cambios
en Enemy, Navigation, Perception o CombatEncounterManager: navegación, patrol,
escape, double encounter, drop/fallback y DungeonSandbox runtime patrol. Tras
6A.1b los seis tests, `fortress6a_validation` y
`stage6a1b_multisensory_validation` pasaron en Godot 4.7.2 headless. El flujo
TEST MOBILE se mantiene: validar → empaquetar proyecto importable desde la raíz
del ZIP → verificar que no incluya `.godot` ni otro TEST MOBILE.

## Etapa 6A.2 — Oxígeno, cache y HUD jugable

El estado de oxígeno pertenece a `RunState` como fuente única de verdad:
`oxygen_max = 100.0`, `oxygen_current`, `consume_oxygen()`,
`restore_oxygen()` y `reset_oxygen()`. Para esta medición inicial,
`GameBalance.oxygen_cost_per_meter = 0.10`; Player reporta solamente la
distancia horizontal real recorrida después de `move_and_slide()`. Estar quieto
no consume oxígeno. La telemetría de RunState registra distancia, coste de
movimiento, coste de combate y gasto total.

Al emitirse `EventBus.combat_ready` (COMBAT real, nunca ALERT/CHASE/candidate/
APPROACH), RunState descuenta una sola vez
`GameBalance.normal_combat_oxygen_cost = 3.0`. Un encuentro doble sigue siendo
un único coste de 3. Con O2 en cero se limita a cero y el HUD avisa
`OXÍGENO AGOTADO`; todavía no existe asfixia, daño ni game over.

`GameplayHUD` es independiente de DebugHUD y muestra siempre HP y O2. El
overlay DebugHUD conserva los datos técnicos e incorpora DISTANCE TRAVELLED,
O2 MOVE COST, O2 COMBAT COST y O2 TOTAL SPENT. La cache opcional del almacén
(`StorageOxygenCache`) restaura +10, se elimina tras usarla y reaparece al
reiniciar la prueba, sin inventario ni persistencia.

`stage6a2_oxygen_validation` pasó: O2 inicial/quieto, distancia y coste real,
combate individual, combate doble, escape sin coste de combate, cache única y
reset. El reset de WellTrigger invoca `RunState.reset_run()` antes de recargar
Fortress6A.

### Perception balance pending

La prueba manual indica que los rangos/FOV/detection actuales pueden sentirse
demasiado permisivos o cortos durante gameplay real. Es un ajuste de balance
pendiente: en 6A.2 no se modificaron vision_range, FOV, hearing, curvas de luz,
detection_time ni velocidades.

## Etapa 6A.3 — Identidad Orca

Orco Melee conserva 40 HP con Ataque Básico (8), Defensa (5) y Ataque
Especial (12). Orco Pícaro tiene 30 HP con Quick Strike (7), Double Strike
equivalente provisional de 10 daño total y Evade (3 bloqueo). Cada uno usa
su propio EnemyResource/combat_deck, por lo que un combate doble conserva
intenciones independientes. Double Strike no introduce multihit genérico.
Enemy.tscn ya mantiene el MeshInstance3D visual separado de AI/collider,
por lo que puede reemplazarse por Sprite3D/AnimatedSprite3D sin reescribir IA.

## Etapa 6A.2b — LAST KNOWN y posicionamiento de combate

Tras perder contacto, Enemy mantiene CHASE como viaje obligatorio hasta
`LAST KNOWN`; `lose_target_timeout_sec` ya no puede llevarlo a PATROL a mitad
de ruta. El timer de búsqueda empieza únicamente al alcanzar LAST KNOWN dentro
del umbral de llegada de navegación (`ARRIVE_THRESHOLD_M = 0.3 m`) o cuando la
navegación informa de forma fiable `NO PATH`. En ese momento pasa a ALERT/
SEARCH; una nueva visión o un nuevo evento auditivo sustituye LAST KNOWN y
reinicia el viaje hacia la información más reciente.

La posición de COMBAT usa ahora una banda provisional centralizada en
CombatEncounterManager: mínimo 2.0 m y máximo 3.0 m, con el ideal de recursos
actual (2.5 m). APPROACH demasiado lejos sigue yendo al slot; demasiado cerca
se reposiciona físicamente hacia el slot navegable a distancia ideal. READY
requiere estar dentro de 2.0–3.0 m. El timeout conserva el comportamiento
seguro: descarta participantes que no logran una posición válida, sin forzar
combate a distancia. La cámara y el Player no se mueven ni rotan.

## Current project structure relevant to this checkpoint

Important current files include:

- `scripts/enemies/Enemy.gd`
- `resources/enemies/EnemyResource.gd`
- `resources/enemies/*.tres`
- `autoloads/LightingManager.gd`
- `autoloads/LightingManager.tscn`
- `scripts/world/LightSource.gd`
- `scripts/player/Player.gd`
- `scripts/ui/DebugHUD.gd`
- `scripts/ui/DebugHUD.tscn`
- `autoloads/DebugConfig.gd`
- `autoloads/DebugConfig.tscn`

Combat-related systems are separate and should not be changed during perception/lighting work unless explicitly requested.

## Combat status

Already implemented/tested or established:

- Card combat.
- `CombatManager` supports up to 2 combatants.
- `CombatUI` has manual and gaze targeting.
- Manual target temporarily overrides gaze.
- Camera remains free during combat; no automatic rotation.
- PC camera remains controllable during combat after the mouse-filter fix.
- Android right-side drag controls camera; card buttons remain separate.
- Movement joystick is disabled during combat.
- PC cards use keys 1–4 provisionally.
- Auto-end-turn at 0 stamina works.
- Reward/DNA flow works.
- Rewards are processed after the entire encounter.
- V.A.T.S.-style time scaling is planned but not implemented.

Combat files are out of scope for the current perception/lighting correction.

## Current player exploration settings

Current noise radius:

- STEALTH = 1 tile.
- WALK = 3 tiles.
- RUN = 5 tiles.

Player debug exposes:

- `PLAYER`
- `LIGHT: X/5`
- `MOVEMENT: STEALTH / WALK / RUN`
- `NOISE RADIUS: X m`
- `NOISE INTENSITY: X`

When `DebugConfig.perception_debug_enabled` is enabled, `NoiseRadiusDebug.gd`
also renders a low-cost horizontal ring around the player. It obtains its radius
directly from `Player.get_current_noise_radius_m()`, the same effective value
used by enemy hearing; it has no collision or gameplay effect.

The player debug light is obtained from the same `LightingManager.get_light_level_at()` used by enemy perception.

Movement speed and noise are separate concepts and remain configurable.

## Current perception implementation

`Enemy.gd` now has a deterministic vision model based on:

1. Distance.
2. FOV.
3. LOS.
4. Player's local logical light.
5. Sustained exposure.

The light does NOT block FOV or LOS.

### Current enemy perception values

### Orcs

Provisional current values:

- Vision range = 5 m/tiles.
- FOV = 100°.
- Detection time = 1.0 s.
- Hearing = 3.
- Patrol speed = 2.
- Chase speed = 2 (reduced from 3 in 5C; patrol remains 2).
- Combat distance ≈ 2–2.5.
- Patrol distance ≈ 8–15.
- After losing useful information, ALERT/search behavior lasts about 7 seconds before returning to patrol.
- Current detection behavior is configurable through `EnemyResource`.

### Xenomorph

Current values:

- Vision range = 12.
- FOV = 150°.
- Hearing = 7.
- Chase speed = 4.
- Detection time = 1.0 s.
- Proximity override ≈ 1.5 m.
- Static/ambush behavior; no normal patrol.
- Intended to be difficult to escape.

## Vision and hearing separation — implemented in 5B

Visual and audible detections now enter explicit separate handlers in `Enemy.gd`:

- Incomplete vision remains `ALERT` while `sight_timer` continues accumulating.
- Confirmed vision enters `CHASE`.
- Only heard noise consults `noise_response_mode`: Orcs investigate in `ALERT`; the Xenomorph can enter `CHASE` directly.

This prevents `noise_response_mode = chase_directly` from converting an incomplete visual sighting into `CHASE`.

## Approach distance and collision — corrected in 5C

All current enemy resources use `combat_distance_tiles = 2.5`, with
`GameBalance.tile_size_m = 1.0`, so an APPROACH target is 2.5 m from the
player at its natural assigned angle. The 0.3 m slot-arrival tolerance means
combat normally begins at no closer than about 2.2 m when the player is still.

The Player and Enemy collision masks now include each other, preventing the
two `CharacterBody3D` colliders from passing through one another. Enemy
movement also caps each physics-tick advance to the remaining arrival distance,
preventing an overlong tick from overshooting a combat slot. Camera movement,
camera rotation, and artificial front-facing placement remain unchanged.

`vision_angle_deg` is the total FOV angle: Enemy compares the unsigned angle
from its forward vector against `vision_angle_deg / 2.0`. Therefore the current
Xeno FOV 150° means 75° to either side of forward, not 150° per side.

## FOV orientation and visual debug — implemented in 5D

Enemy perception uses Godot's standard local forward axis, `-global_transform.basis.z`.
The Xeno root transforms in `DungeonSandbox` use that same axis; the placeholder
CapsuleMesh is symmetrical and does not visually communicate its facing on its
own. `EnemyFovDebug.gd` therefore draws a ground-level cone that also points to
local `-Z`, inherits root rotation, and reads the real `vision_angle_deg` and
`vision_range_tiles` from the assigned `EnemyResource`.

With perception debug enabled, the cone is blue when no valid visual detection
exists, amber during visual `ALERT`, and red after visual confirmation/CHASE.
It is debug-only, has no collision or gameplay effect.

## Current visual detection/light model

The old binary `chase_capability_threshold` was removed because it could make visual CHASE mathematically impossible below a threshold.

The current intended/implemented model is progressive:

`sight_timer += delta * light_detection_capability`

Conceptually:

- Light 0 → capability 0 → visual confirmation does not complete while remaining at light 0.
- Light 1 → slow confirmation.
- Higher light → faster confirmation.
- Maximum capability → approximately the configured detection time.

The provisional example curve used during design/testing:

- 0 = 0%
- 1 = 15%
- 2 = 50%
- 3 = 80%
- 4 = 90%
- 5 = 100%

These values are balance values and may change after testing.

Detection is deterministic; there should be no independent random detection roll every frame.

### Important test behavior

If the player leaves valid FOV/LOS, `sight_timer` should reset.

The current implementation intentionally does not reset `sight_timer` merely because the player's light changes while LOS/FOV remain continuously valid. This should be observed in testing rather than changed automatically.

Close direct visibility uses the proximity override so the player should not get absurdly missed merely because of low light.

## Current LightingManager

Implemented:

- `autoloads/LightingManager.gd`
- `autoloads/LightingManager.tscn`
- `scripts/world/LightSource.gd`

The logical system currently supports:

- Ambient light.
- Point light sources.
- Source intensity.
- Source radius.
- Spatial falloff.
- Logical result in the 0–5 range.
- No grid required.

Current sandbox ambient light = 1.

The sandbox contains three test light sources.

### Important current limitation / next correction

Light aggregation accumulates ambient light plus every active source contribution, then quantizes and clamps the final logical result to 0–5. `LightSource` returns continuous distance/falloff contributions, avoiding per-source rounding artifacts before aggregation.

Example: ambient 1 + source A 2 + source B 2 = 5.

## Visual lighting

Logical lighting is currently NOT synchronized with Godot's actual visual lighting (`DirectionalLight`, `WorldEnvironment`, etc.).

This is intentional for the current stage.

Future requirement:

- visual light should communicate the logical light level clearly enough that gameplay does not feel arbitrary;
- source placement should eventually be part of biome/map generation;
- do not add full visual synchronization as part of the current perception correction unless explicitly requested.

## LightSource visual debug

The current `LightSource` debug visualization uses a small emissive-looking core and a translucent sphere representing the radius, without expensive real-time shadows/lighting.

This is intended as a cheap PC/Android/Cardboard debug aid, not the final lighting presentation.

## Doors

There are currently no interactive door objects in the dungeon sandbox.

A future `_compute_door_attenuation_m()` hook exists for sound but currently returns 0 because doors do not exist.

Do not implement doors during this perception correction.

Future intended behavior:

- Closed door blocks vision.
- Open door does not.
- Closed door attenuates sound.

## Navigation — repaired in 5F for DungeonSandbox

`DungeonSandbox` owns a scene-declared `NavigationRegion3D` and `NavigationMesh`
for its four rooms and three connecting corridors. The mesh contains 14
triangles. Headless validation confirms that every patrol A/B pair projects to
it exactly, has an agent-reachable route, and that the complete Room 1 → Room 4
path connects all seven room/corridor surfaces.

Every Enemy scene includes a `NavigationAgent3D`; PATROL, ALERT, CHASE, and
APPROACH all request the next path point through the same movement function.
Patrol markers are floor-level references, while navigation queries use the
enemy walk-plane height. The prior patrol bug was not a disconnected route: the
first waypoint could equal the agent's current position and was mistakenly
treated as arrival at its final patrol target, so A/B alternated every frame.
Arrival now checks distance to the final target; a near self-waypoint merely
waits for the next navigation update. During movement, local `-Z`, motion
direction, and the FOV cone remain aligned. APPROACH still targets its natural
combat-distance slot, never the player's exact position.

If an agent has no valid route (including a scene without this navigation
region), it stops and rechecks on subsequent physics ticks instead of walking
indefinitely into a wall. This is intentionally a sandbox-specific, non-
procedural navigation setup; advanced navigation/avoidance remains future work.

Perception debug adds `NAV: OK` or `NAV: NO PATH` and the current navigation
target's X/Z coordinates to each enemy label while enabled.

## Navigation and combat transition — repaired in 5G

The Android patrol failure exposed a gap between NavigationServer route checks
and `NavigationAgent3D` readiness. Enemy movement now waits safely for the
first map synchronization and, when an agent temporarily reports no path while
the same NavigationMap has a route, follows that map route's next waypoint.
PATROL retries and alternates its target after a sustained no-path result rather
than remaining frozen forever.

APPROACH is now cancellable. Closing the 1.5-second join window no longer makes
combat inevitable: every frame the manager retains only enemies with current
contact or already-close combat distance. Combat requires at least one enemy
within `combat_distance + 0.35 m`; a timeout drops invalid/far enemies or
cancels the encounter, and never calls a force-finish combat path. Debug adds
`APPROACH`, `READY`, `DROPPED`, and `COMBAT DIST: actual / required`.

The complete 5G automated set now passes: Navigation, five-second real patrol,
real-perception escape, two-participant APPROACH, and the controlled DROP
fallback. The DROP integration first verifies that A and B are accepted as the
two candidates of the same encounter, then observes both in `APPROACH` before
adding a low physical cage around B. B follows the normal timeout fallback
through `DROPPED`; A starts a valid one-enemy combat and B is not added to that
combat or queued automatically afterwards. This is a test harness only; it did
not require a production-logic change.

The current double integration uses `combat_distance = 2.5 m` and finished at
0.51 m for A and 2.16 m for B. Those are recorded for Android visual review;
they have deliberately not been rebalance-adjusted in this checkpoint.

## Patrol runtime diagnosis — repaired in 5H

The prior five-second patrol check instantiated `DungeonSandbox` without the
normal `MainSandbox` Player/UI tree and only compared initial versus final
position. It did not expose an Android/runtime-specific waypoint failure.
The new `stage5h_runtime_patrol` test instantiates the unmodified
`MainSandbox.tscn`, including its normal Player and `DungeonSandbox`, waits for
normal synchronization, and records every Orc position for ten seconds.

The actual patrol freeze was caused by a NavigationAgent next waypoint at
exactly `0.30 m` (the arrival threshold). `_move_toward_point()` subtracted the
same `0.30 m` threshold from every intermediate waypoint, yielding a requested
horizontal velocity of `0.00` despite `NAV: OK`. PATROL now caps movement at
the actual intermediate waypoint; the arrival threshold remains for the final
patrol target and the existing APPROACH/CHASE behavior was left unchanged.

When perception debug is enabled, each patrolling enemy now shows its patrol
index/target, target distance, requested and actual speeds, horizontal
velocity, NavigationMap iteration, navigation state, next waypoint distance,
and `PATROL STALLED` with the observable cause after one second. Patrol facing
uses actual horizontal displacement, so a stopped enemy preserves its last
valid orientation instead of turning toward a self waypoint or wall.

The ten-second MainSandbox runtime validation passed: Orcs 2–5 each remained
in PATROL, alternated their patrol index, and covered about 18.33 m without a
stall. Orc 1 legitimately left PATROL after detecting the normal Player placed
nearby at scene start and entered combat; it moved 2.23 m before that state
transition, so it is not classified as a patrol stall.

## Loss of contact and last known position — repaired in 5F

`CHASE` now means an enemy has current visual or hearing contact. Every valid
signal updates `_last_known_player_position`. When both channels are lost, the
enemy navigates to that saved position exactly; it does not read or chase the
player's new invisible position, and it does not use combat standoff distance
while doing so. On arrival (or no route), it changes immediately to `ALERT`.

`lose_target_timeout_sec` now measures the subsequent ALERT/search duration,
not an idle CHASE delay. Orcs search for 7 seconds and return to patrol; the
Xenomorph searches for 14 seconds and returns to its non-patrol idle behavior.
This expresses stronger Xeno persistence without omniscience or a permanently
stationary CHASE. A new perception signal during ALERT updates the saved point
and applies the existing vision/hearing response rules.

## Multiple encounters — stabilized in 5E

`CombatEncounterManager` retains a 1.5-second join window and a maximum of two
combatants, but now distinguishes candidates from locked participants. A
candidate independently has a current visual baseline (range/FOV/LOS, including
visual ALERT) or valid hearing contact while the window is open. At lock, every
candidate recalculates contact directly; it becomes a participant only if still
valid. If none remain, the pending encounter is cancelled with no freeze,
APPROACH, or combat.

This lets a second enemy reserve the remaining place before completing full
progressive visual detection, without grouping by proximity. A candidate
rejected because the window is closed or full is `REJECTED` for that pursuit and
cannot form an automatic queue after reset. Accepted combatants keep natural-
angle slots and use APPROACH to their configured combat distance.

## Current debug HUD

Enemy perception debug was restructured to show:

- STATE
- DIST
- FOV
- LOS
- PLAYER LIGHT
- SIGHT
- CAPABILITY
- CONTACT: YES / NO
- LAST KNOWN: distance to the saved position
- ENCOUNTER: NONE / CANDIDATE / JOINED / REJECTED / COMBAT
- NAV and NAV TARGET
- During PATROL: patrol target/index, target distance, requested speed,
  velocity, actual speed, NavigationMap iteration, next-path distance, and
  `PATROL STALLED` cause when applicable

`N/A` is used when a value was not evaluated on that tick rather than displaying stale data.

Player debug separately shows:

- PLAYER
- LIGHT: X/5
- NOISE

Both player and enemy debug light use `LightingManager.get_light_level_at()`.

The DebugHUD has a small `Percepción: ON/OFF` control. With it ON, the existing
technical perception/navigation overlay is visible; with it OFF, the basic HUD
remains available without FOV, noise, path, and enemy-label noise.

## Current testing status

Etapa 5 is closed. Manual Android testing confirmed patrol and orientation,
FOV/perception, navigation, CHASE and last-known behavior, escape before
combat, multiple encounters, APPROACH/COMBAT, and the perception/navigation
debug tools.

Observed:

- Logical lighting feels more coherent.
- Player light debug is useful.
- Darkness no longer acts as a geometric vision wall.
- Detection progression is more sensible.
- Xeno perception remains 12 m / 150° / hearing 7 m.
- Light-source overlap now accumulates correctly.
- 5E/5F headless integration checks passed for every patrol pair, complete
  sandbox connectivity, actual patrol movement, cancellation, two valid
  candidates, late rejection, last-known navigation, arrival, recovery, and
  Xeno non-stationary persistence.
- 5G headless validations now pass for navigation, five-second patrol,
  real-perception escape, double encounter, and one-enemy fallback after a
  second admitted participant cannot complete APPROACH.
- 5H validates the actual `MainSandbox` runtime for ten seconds with the
  normal Player present; Orcs 2–5 patrol continuously and the nearby Orc 1 is
  documented separately as a legitimate perception/combat transition.

### Mandatory Stage 5 regression battery

Any future change that affects `Enemy`, navigation, perception, or
`CombatEncounterManager` must run all of the following before a TEST MOBILE
package is generated:

- `stage5e_navigation_validation`
- `stage5f_behavior_validation` (patrol)
- `stage5g_escape_integration`
- `stage5g_double_integration`
- `stage5g_drop_integration`
- `stage5h_runtime_patrol` (ten-second `MainSandbox` runtime)

## Known limitations that remain intentionally deferred

- No interactive doors.
- No sound attenuation through actual doors yet.
- Navigation avoidance and procedural/dynamic navigation are not implemented; the current NavigationRegion3D is limited to DungeonSandbox.
- No logical-light → visual-light synchronization.
- No real XR/Google Cardboard integration or configuration yet; mobile controls and gaze-oriented targeting remain, but Cardboard compatibility requires its own future stage.
- No advanced acoustic simulation.
- No stealth assassination/ambush implementation.
- No new status effects beyond already implemented prototype behavior.
- No V.A.T.S.-style combat time scaling.
- No full procedural lighting placement system yet.

## TEST MOBILE

Every change requiring manual Godot testing must finish with a root-level `RogueSpace_TEST_MOBILE_YYYYMMDD_HHMMSS.zip`. The package contains the project contents directly (with `project.godot` at the ZIP root) and excludes editor caches and prior TEST MOBILE packages. It is intended for import/testing in Godot Android; it is not an APK export.

## Immediate next task

Manually validate the Fortress 6A.1 greybox on Android: branch readability,
line-of-sight breaks, deliberate lighting, normal and double Orc encounters,
end trigger, and debug toggle. Do not change oxygen yet; 6A.2 will use this
traversal data to design its minimum implementation. Procedural generation,
well transition, Xenomorph caves, boss, XR/Cardboard integration, doors, and
visual-light synchronization remain out of scope.

## AI-agent discipline for this checkpoint

Any coding agent working on RogueSpace should:

- Read `CORE_Design.md` and this file before modifying relevant systems.
- Treat the immediate next task as narrowly scoped.
- Not claim to have run Godot unless it actually did.
- Distinguish verified code facts from manual-test results.
- Not rewrite architecture unnecessarily.
- Not modify unrelated systems to solve a local issue.

## Etapa 6A.3 — consolidación del vertical slice

### Investigación de última posición

`LAST KNOWN` es multisensorial: visión actualiza la posición vista y oído
actualiza estrictamente la posición del evento de ruido. Sin contacto, el
enemigo viaja por navegación hasta ese punto antes de entrar en `SEARCH`.
SEARCH dura provisionalmente 5 s y recién entonces vuelve al comportamiento
base. Una cancelación de APPROACH no puede convertir un LAST KNOWN lejano en
ALERT estacionario: vuelve a CHASE hacia el punto pendiente.

### Movimiento y telemetría

WALK conserva 2.0 m/s; STEALTH es 0.65× (1.30 m/s) y RUN 1.50× (3.00 m/s).
Los radios/intensidades de ruido son 1/1, 3/3 y 5/5. PC usa Ctrl para
STEALTH y Shift para RUN; Android cicla STEALTH → WALK → RUN. RunState
registra tiempo de run, distancia, O2, combates, enemigos derrotados y tiempo
efectivo por modo. O2 sigue calculándose por distancia real.

### Perfiles demo

Los IDs heredados `orco` y `xenomorfo` permanecen por compatibilidad de ADN;
los nombres visibles son Varkhen Carnotauro, Varkhen Raptor y Horvex Avispa.
Carnotauro: 40 HP, 7 m/120°, oído 4 m, Hacha 8×2, Defensa 6×2, Mordisco 12,
Regeneración 4 (no a vida máxima), Piel Dura 6 block. Raptor: 20 HP,
visión alta provisional 9 m/120°, oído 4 m, Arañazo 10, Defensa 6,
Mordisco 12, Piel Dura 6 block. Horvex: 30 HP, no patrulla, visión muy alta
provisional 11 m/140°, oído 7 m, Arañazo 10×2, Coraza 8 y Aguijón 5.
Horvex usa curva de luz 0–2 = 0.55/0.70/0.85 sin ignorar FOV ni LOS.
Veneno queda pendiente: no se inventó una regla de duración/daño no definida.

### Preparación de stealth y pendientes

Perception debug muestra una Ambush Zone verde a 1 m detrás del forward
lógico de cada Enemy. Es sólo señal/hook, sin colisión, navegación ni ventaja
de combate. PERCEPTION BALANCE continúa pendiente; HIGH=9 m y VERY HIGH=11 m
son provisionales. También quedan pendientes veneno completo, bonus de
emboscada, arte/sprites, XR/Cardboard y balance final de oxígeno.

## Etapa 6A.3b — ownership Enemy/Encounter (en validación)

Enemy conserva ownership de exploración en PATROL, ALERT, CHASE y SEARCH;
CombatEncounterManager sólo lo toma en APPROACH/READY/COMBAT. DROPPED limpia
target, slot, timer de approach y pedido de encounter, pero conserva
percepción y LAST KNOWN. Queda excluido sólo del encuentro activo y debe
perder/reconseguir contacto antes de abrir otro. El debug muestra AI OWNER,
MOVEMENT SOURCE y AI STALLED. Falta validación manual Android e integraciones
runtime 6A.3b: no es cierre de IA.

### Validación runtime completada (pendiente Android)

La batería 6A.3b confirmó CHASE→COMBAT, RUNAWAY, reacquisition por VISION y
SOUND, DROPPED recovery/future encounter, dos enemigos con LAST KNOWN
independiente y la regresión de waypoint intermedio. `current_contact_kind`
separa VISION/SOUND/NONE: sólo visión aplica stop de combate; sonido navega
hacia la posición situada del evento. Un waypoint intermedio nunca es llegada
al destino final. El watchdog `AI STALLED` no se disparó en estos escenarios.
La IA queda provisionalmente validada por headless y sigue pendiente de prueba
manual Android; no se considera cierre definitivo hasta entonces.

### Navegación física de corredores (validada por headless; pendiente Android)

Fortress6A conserva una `NavigationRegion3D` manual única, pero su malla fue
reconstruida como una red continua: los rectángulos anteriores se tocaban en
tramos parciales sin vértices compartidos, lo que creaba islas de navegación
en entradas de corredores. El `NavigationAgent3D` podía agotar la ruta en el
borde aunque el cuerpo físico del Enemy aún tuviera que cruzar el paso.

La malla nueva comparte bordes de conexión y deja un inset de 0.40 m respecto
de las paredes laterales relevantes, equivalente al radio de la cápsula del
Enemy. No se redujo la cápsula, no se desactivaron colisiones, no se añadió
teletransporte ni se cambió gameplay. La regresión
`stage6a3b_corridor_choke_runtime` cruza físicamente el corredor inicial desde
el centro y desde ambos ingresos diagonales, verificando ruta, waypoint,
velocidad solicitada, desplazamiento real y colisiones. Fortress6A vuelve a
tener ruta spawn→pozo (6 puntos) y sus cuatro patrullas siguen activas.

Los flujos runtime de CHASE/LAST KNOWN continúan cubiertos por RUNAWAY y TWO
ENEMY CORRIDOR. La validación final de esta corrección sigue siendo manual en
Android: esta build es candidata, no declara cerrada la IA.

### Etapa 6A.3c — robustez física / stuck recovery (pendiente Android)

El clearance de Fortress6A se ajustó de 0.40 m a 0.55 m desde las caras
internas de pared. La cápsula física conserva radio 0.40 m; el corredor más
estrecho mantiene 1.60 m de ancho navegable, dejando 0.40 m a cada lado del
centro de la cápsula. La malla sigue conectando spawn→pozo y todas las rutas
de patrulla; no se ensancharon paredes ni corredores físicos.

`Enemy.gd` ahora trata `NAV: OK + velocidad solicitada + desplazamiento físico
casi nulo` durante 0.65 s como bloqueo físico, no sólo como debug. En
exploración (PATROL, ALERT y CHASE), invalida la ruta, reproyecta inicio y
destino al NavigationMap y prueba un pequeño objetivo lateral navegable de
0.55 m. Tras alcanzarlo, vuelve al mismo objetivo semántico original (incluido
LAST KNOWN); no teletransporta, no atraviesa colisiones ni declara llegada
falsa. El debug muestra `PHYSICAL MOVEMENT: OK`, `BLOCKED` o `STUCK RECOVERY`.

La orientación de recuperación se actualiza sólo después de desplazamiento
horizontal físico: un cuerpo bloqueado conserva su orientación en vez de
alternar con waypoints. La orientación normal de exploración permanece como
antes fuera de recuperación para conservar FOV y regresiones validadas.

`stage6a3b_corridor_choke_runtime` cubre CENTER, DIAGONAL LEFT/RIGHT,
WALL GLANCING y CORNER ENTRY con CharacterBody/collisions reales.
`stage6a3c_stuck_recovery_runtime` crea una obstrucción temporal fuera de la
malla, confirma `STUCK RECOVERY`, retira sólo el obstáculo de test y verifica
movimiento físico hacia el LAST KNOWN auditivo original sin giro estacionario.
Todas las regresiones de navegación, percepción/encounter, Fortress6A,
oxígeno e identidad Varkhen pasaron en Godot 4.7.2 headless. Falta validación
manual Android antes de considerar cerrada esta corrección.

### Etapa 6A.3d — clearance físico (pendiente Android)

La auditoría halló una causa de NavigationMesh manual: Enemy usa cápsula de
radio 0.40 m (diámetro 0.80 m), mientras dos conectores
Storage/Barracks→Convergence tenían carriles de sólo 0.60 m y conexiones por
aristas parciales. NavigationAgent3D usa radio 0.50 m, distancias deseadas de
0.15 m y avoidance desactivado. La malla activa ahora comparte bordes completos,
Convergence es una región abierta y los dos pasos físicos locales se ampliaron
de 1.70 m a 2.00 m, dejando 0.90 m navegable y 0.55 m hasta cada pared.

`stage6a3d_clearance_audit` recorre con la cápsula/CharacterBody reales las
ocho rutas base en ambos sentidos, diagonales y tres repeticiones (24
recorridos), más una matriz determinista de doce entradas de borde, diagonales
y sentidos inversos en los chokes norte/sur y el corredor inicial (36
recorridos físicos en total). Todos llegaron sin bloqueo sostenido, giro
estacionario ni stuck recovery. Falta validación manual Android; no se
considera cierre definitivo todavía.

### Etapa 6A.3d — slots de APPROACH junto a paredes (candidata Android)

La selección de slot de combate ahora valida la posición física completa antes
de aceptarla: debe pertenecer realmente al NavigationMap (sin una proyección
que esconda una pared), tener ruta desde el Enemy, conservar la banda de
combate 2–3 m, tener LOS al Player y no superponerse con la cápsula real del
Enemy. Si el ángulo natural cae contra una pared o esquina, prueba offsets
angulares deterministas y acotados alrededor del ángulo asignado; no mueve al
Player, no teletransporta y no fuerza un slot inválido. Si no existe slot
físico válido, el fallback existente de Encounter sigue siendo observable y
no inicia COMBAT a distancia.

`stage6a3d_approach_runtime` usa `MainFortress6A`, Player, Enemy,
NavigationRegion, percepción y CombatEncounterManager reales. Verifica por
separado Player en centro de habitación, contra una pared, cerca de esquina
interior y junto a entrada de corredor. Los cuatro recorren
percepción→CANDIDATE→APPROACH→COMBAT con slot válido, owner COMBAT y sin
AI STALLED. La fuente de luz temporal del harness sólo normaliza exposición
para evaluar positioning en geometría oscura; no modifica Fortress6A ni el
pipeline de percepción productivo.

### Etapa 6A.3c — seguimiento de corrección final (pendiente Android)

La revisión del paquete Android anterior encontró dos causas raíz, ambas en
`Enemy.gd`, sin relación con balance perceptivo. En exploración,
`_move_toward_point()` orientaba con el waypoint solicitado antes de
`move_and_slide()`, mientras `_update_actual_motion_debug()` podía volver a
orientar usando el desplazamiento físico en condiciones de bloqueo. Dos
waypoints alternantes podían por tanto modificar el forward/FOV aun cuando el
CharacterBody no avanzaba. Ahora PATROL, ALERT viajando y CHASE sólo orientan
después de un desplazamiento horizontal físico confirmado; APPROACH conserva
su autoridad separada para mirar al Player y COMBAT su orientación propia.
El debug expone `ROTATION OWNER`, heading solicitado, heading físico y
waypoint para diagnosticar conflictos sin interpretar texto de HUD.

La recuperación de atasco usaba el target transitorio de NavigationAgent como
si fuese el destino de IA. Ahora `Enemy` conserva un objetivo semántico
separado (patrulla, contacto o LAST KNOWN), detecta ausencia de progreso real
hacia ese objetivo durante la ventana de recuperación y usa cualquier sonda
lateral sólo como desvío temporal. Al terminar la sonda retoma el mismo LAST
KNOWN; no lo sustituye, no teletransporta ni declara llegada falsa. Se expone
un contador debug persistente de recuperaciones para que una activación entre
muestras no quede oculta.

Se agregaron validaciones runtime sobre `MainFortress6A` real:

- `stage6a3c_orientation_stability_runtime`: choke físico con ruta NAV válida;
  no admite giros grandes frame a frame sin desplazamiento real.
- `stage6a3c_raptor_last_known_runtime`: Varkhen Raptor adquiere al Player por
  visión, recibe una última posición válida, pierde contacto detrás de
  geometría, disminuye físicamente esa distancia y llega a SEARCH con forward
  alineado al movimiento físico.

La batería final también volvió a aprobar CHASE→COMBAT, RUNAWAY,
REACQUISITION VISION/SOUND, TWO ENEMY CORRIDOR, waypoint intermedio,
choke físico, stuck recovery, las regresiones de navegación/patrulla,
encounter/escape/double/drop, Fortress6A, multisensorial, oxígeno e identidad
Varkhen. Ninguno de estos escenarios disparó `AI STALLED`. Esta build sigue
siendo candidata a validación manual Android: la IA no se declara cerrada
hasta esa prueba.

### Etapa 6A.3e — cornering/NavMesh físico (candidata Android)

La matriz física detectó el defecto de datos que no veía el test anterior:
las aproximaciones Android `7,-3.2`, `8,-3` y `8.5,-2` a la boca inferior de
entrada llegaban en PC, pero el centro de la cápsula recorría sólo `0.401 m`
de la punta física de W05. Era inferior al contrato de `0.45 m` para una
cápsula de radio `0.40 m`, por lo que el funnel podía producir un atasco
oblicuo dependiente de plataforma/ángulo.

La malla activa `NavigationMeshClearanceConnected` se corrigió como datos:
los bordes centrales de corredores se insetearon a ±`0.65 m`, W08 quedó
inset a `x=23.85`, las dos gargantas Storage/Barracks→Convergence usan
bandas a `0.70 m` de las caras de pared, y la boca x=9 recibió chaflanes de
NavMesh que retiran el triángulo que llevaba el funnel a la punta de W05.
No se modificaron cápsulas, colisiones, Enemy AI, perception, velocidad ni
stuck recovery.

`stage6a3d_clearance_audit` ahora mide clearance contra cada CSGBox3D de
`Walls` en todos los frames físicos y falla bajo `0.45 m`, aun si el Enemy
llegara. La matriz post-fix recorre rutas base, ambos sentidos, diagonales,
bordes y las reproducciones/reversas exactas; el mínimo observado fue
`0.494 m`, sin bloqueo sostenido, oscilación ni stuck recovery. Los escenarios
runtime `stage6a3e_corner_gameplay_runtime` validan CHASE atravesando la
boca, LAST KNOWN hasta SEARCH y retorno de SEARCH; los cuatro escenarios de
APPROACH (centro, pared, esquina y entrada de corredor) siguen llegando a
COMBAT con slot físico válido.

Deuda técnica: un dungeon procedural/final debe bakear/generar navegación a
partir de geometría con un agent radius aproximado de 0.45–0.50 m, en vez de
depender de polígonos manuales de esta clase. Esta build sigue pendiente de
validación manual Android.

## Etapa 6B — identidad, veneno y emboscada

Los perfiles visibles definitivos son **Varkhen Carnotauro**, **Varkhen Raptor** y **Horvex Avispa**. Se conservan filenames legacy para no romper referencias, pero los Resources usan ADN `varkhen` / `horvex`. Carnotauro: HP 40, patrol/chase 1/2, visión 7, FOV 120°, oído 4, Piel Dura +6 y Hacha×2, Defensa×2, Mordisco, Regeneración. Raptor: HP 20, 3/3, visión 9, FOV 120°, oído 4, Piel Dura +6 y Arañazo, Defensa, Mordisco. Horvex: HP 30, sin patrulla, chase 4, visión 11, FOV 140°, oído 7, curva oscura `[0.55,0.70,0.85,1,1,1]`, Arañazo×2, Coraza y Aguijón. Valores de balance provisionales.

VENENO aplica 2 HP al comienzo del turno de la unidad afectada, no stackea y se limpia al terminar/resetear combate. Aguijón inflige 5 y aplica VENENO; Horvex es inmune por Resource. CombatUI muestra el próximo tick junto a stamina. Entrar en la zona trasera sin contacto y antes de CHASE arma AMBUSH; si ese enemigo inicia el encounter, el Player obtiene +2 stamina una única vez en el primer turno, sin elevar el máximo ni sumar por enemigo.

El lifecycle de Ambush usa el Encounter normal: un candidato Ambush pendiente puede conservar `CONTACT: NONE` durante la join window y no se retira por la limpieza histórica destinada a candidatos sensoriales. El manager distingue candidato Ambush pendiente de la marca histórica de debug. Runtime validado: Ambush E2E (STEALTH trasero, `ambush_ready` una vez, APPROACH→COMBAT, stamina 5→3), REJECTED_CLOSED recovery y tercer enemigo (máximo dos y elegibilidad posterior). Los negativos deterministas sin STEALTH y entrada frontal pasan. El negativo "contacto previo" queda como fixture pendiente/no determinista: los intentos de precondición SOUND/VISION no son un fallo funcional ni bloquean 6B.

## Etapa 6C — framework extensible de efectos y estados

Se incorporó un framework data-driven con `StatusEffectDefinition` (Resource inmutable) e instancias runtime separadas en `StatusEffectContainer`. Cada contenedor registra `Effect ID | stacks | turnos restantes`, aplica y elimina efectos por API, y soporta reaplicación `NO_STACK`, `ADD_STACK` y `REFRESH_DURATION`. Las resistencias e inmunidades se resuelven por tags, no mediante condicionales centrales por efecto.

El lifecycle de combate procesa efectos al comienzo del turno del receptor: al inicio del turno Player, después de recuperar stamina/bloque y antes de robar cartas; para cada EnemyCombatant, al inicio de su resolución. Cada hook se consume una única vez y descuenta duración tras aplicar su operación. `Poison` es el prototipo configurable: daño por turno, duración, tags y reaplicación están en datos; no congela todavía el diseño final de veneno de RogueSpace. El mismo pipeline también valida un buff temporal de bloqueo y su restauración al expirar.

`RunState` y `EnemyCombatant` alojan su propio contenedor sin duplicar lógica. Las extensiones futuras pueden otorgar definiciones, tags de resistencia o inmunidad desde ADN, cartas, equipo, enemigos o eventos narrativos sin introducir casos especiales en `CombatManager`. La persistencia de efectos de run queda como contrato futuro mínimo (`effect_id`, stacks, turnos restantes y magnitud/estado adicional cuando exista), sin ampliar el formato de save en esta etapa.

Gates 6C validados: compilación/import; framework aislado (apply/remove, duración, refresh, stacks, Poison, resistencia, inmunidad y buff); e integración de combate real Player/EnemyCombatant. La timeline de integración confirmó Poison `30→28→26→24`, duración `1→refresh 2→1→expira`, resistencia 50 %, inmunidad por tag y buff de bloqueo. Las regresiones funcionales de navegación B+C, patrulla, CHASE→COMBAT, RUNAWAY, reacquisition VISION/SOUND, LAST KNOWN→SEARCH, APPROACH, encounter doble, DROP/Fallback, Ambush, REJECTED recovery, tercer enemigo, identidad/veneno 6B y O₂ continúan PASS. El diagnóstico largo Well→Spawn mantiene una excepción conocida y deliberada: el harness debe excluir al Player estacionado en Spawn; aislado así, ambos sentidos completan sin colisión arquitectónica.

## Etapa 6D — cartas, armas y loadout data-driven

`CardResource` conserva compatibilidad con las cartas existentes por `action_id`, y suma componentes configurables: daño, block, efectos 6C, objetivo del efecto y valores derivados de arma/escudo. Cuando una carta usa componentes, `CombatManager` resuelve la misma composición genérica (daño + block + lista de StatusEffectDefinition) sin casos por carta, veneno o arma. Las cartas básicas futuras pueden marcar valor derivado del loadout/equipamiento; no requieren una carta hardcodeada distinta por arma.

`LoadoutResource` es una fuente independiente de cartas iniciales. `RunState` selecciona el loadout explícito, el loadout del arma equipada o el deck legacy, en ese orden, y reconstruye sus pilas con una copia del array, sin mutar Resources compartidos. ADN, equipo y eventos futuros pueden aportar/modificar fuentes de cartas sin que CombatManager conozca su procedencia.

Para crear una carta nueva: crear un `CardResource`, asignar coste y componentes (`damage_amount`, `block_amount`, `apply_effects` y objetivo) o mantener el `action_id` legacy durante una migración gradual. Para crear un arma/loadout: crear un `LoadoutResource`, cargar `starting_cards` y asignarlo al arma o a `RunState.equipped_loadout`. Una carta aplica estados 6C referenciando `StatusEffectDefinition` en `apply_effects`; las resistencias/inmunidades permanecen responsabilidad del receptor.

Validación 6D: dos loadouts de fixture reconstruyen decks distintos, draw de cuatro y reshuffle; combate real valida coste/stamina, daño configurado, block, carta combinada y aplicación/tick de efecto en EnemyCombatant. No se implementaron Rifle, Espada Viva ni contenido final: quedan como consumidores futuros de esta infraestructura.

### Etapa 6D.1 — loadout modular y resolución unificada

`LoadoutResource` puede componer un mazo de tamaño configurable con el contrato **PRIMARY → SECONDARY → FALLBACK**. La primaria siempre conserva todas sus cartas; la secundaria sólo ocupa slots libres y se trunca si excede el espacio; el fallback rellena lo restante. Una primaria con `allows_secondary=false` compone primaria más fallback. Si no hay loadout modular, se conserva sin cambios el deck legacy.

`ArtifactResource` y `ValueModifierResource` expresan modificadores planos o porcentuales filtrables por tipo de valor (`DAMAGE`/`BLOCK`) y tags de carta. `CardValueResolver.get_resolved_card_values()` es la fuente única de preview y ejecución: valor base de carta → stat explícito del personaje si la carta lo solicita → artefactos → arma primaria → arma secundaria → `roundi` y clamp final. Los Resources de carta no se mutan. La matriz runtime verificó `6 × 1.05 × 1.10 = 6.93 → 7`, block `6 × 1.50 = 9`, y paridad exacta entre preview y daño/block aplicados por CombatManager.

Deuda futura registrada: enemigos fuera de un Encounter podrían oír combates activos como refuerzos opt-in; no se modifica el lifecycle actual. Un excluido puede aproximarse durante combate: es polish pendiente, no un bug confirmado.

## Etapa 6E — Character Stats y ADN data-driven

`CharacterStats` expone stats por ID (`damage`, `block` hoy; extensible sin cambiar el resolver). `DNASpeciesResource` suma ID, tags, `units_per_level` y modificadores de stat data-driven reutilizando `ValueModifierResource`. La cantidad se conserva por canal legacy compatible (`weapon`, `shield`, `suit`), se deriva nivel mediante `units_per_level` y se consulta como bonus de stat; los Resources no se mutan. Los Resources legacy declaran explícitamente `units_per_level=1` para preservar la demo actual; las especies nuevas usan el contrato de `5` unidades por nivel.

La jerarquía de `CardValueResolver` queda: **base de carta → Character Stat/ADN → artefactos → primaria → secundaria → roundi/clamp**. Preview y ejecución usan la misma API. La validación 6E comprobó acumulación `12→nivel 2`, reasignación `15→nivel 3`, rechazo de slot inválido y la cadena `(6 + 6) × 1.05 × 1.10 = 13.86 → 14`; para block, `(6 + 2) × 1.50 = 12`, sin mutar los valores base de las cartas.

La integración futura de resistencias/inmunidades de ADN seguirá los tags de 6C; no se introdujo una segunda capa de estados ni contenido de especies, híbridos, evoluciones o UI de asignación en esta etapa.

## Etapa 6F — Run Structure, World Graph y Dungeon Template Foundation

La estructura de run es data-driven mediante `RunGraphResource` y `RunNodeResource`: grafo dirigido, nodo actual, visitados/completados y selección limitada a conexiones disponibles. `RunDirector` resuelve FIXED directamente a `fixed_scene` y TEMPLATE/PROCEDURAL a un `DungeonPlan` lógico; no cambia escenas productivas ni construye geometría todavía. `RunState` conserva `run_seed` y director junto a HP, O₂, ADN, loadout y stats existentes.

Los contratos de contenido son `DungeonDefinitionResource` (FIXED/TEMPLATE/PROCEDURAL), `DungeonTemplateResource`, `ModuleDefinitionResource` y pools ponderados con RNG local de run. Un plan válido contiene un START único, EXIT alcanzable, IDs/conexiones válidos y tamaño dentro del template. El fixture validó el ciclo mapa→A fixed→reward→bifurcación B/C→plan template, determinismo con seed `4242` y persistencia de HP/O₂/ADN/stats.

Contrato previsto para 6G: **run seed → DungeonDefinition → DungeonTemplate → DungeonPlan → module scenes → assembler físico → proxies B+C → navigation bake → placement**. 6F no genera todavía dungeon 3D, NavMesh, enemigos, iluminación, UI de mapa ni contenido canon.

## Etapa 6G — Physical Dungeon Assembler + B+C prototype

`Stage6GProceduralPrototype` consume ahora un `DungeonPlan` real construido por `RunDirector` a partir de un seed, en vez de una cadena de transforms hardcodeados. El plan conserva tipos semánticos por módulo (`START`, `STRAIGHT`, `TURN_LEFT`, `TURN_RIGHT`, `EXIT`); el assembler TEST los interpreta mediante `Marker3D` de conectores locales compatibles y alinea posición/orientación sin coordenadas de puertas en Resources. Cada aceptación valida overlap antes de insertar el módulo. El catálogo sigue siendo exclusivamente TEST: no añade biomas, enemigos ni contenido canon.

### 6G.2 — variedad topológica, seams y gate NAV READY

El template TEST ahora expresa variedad topológica mediante datos: límites de giros, probabilidad de salas y habilitación/probabilidad de bifurcaciones. `RunDirector` genera de forma determinista `STRAIGHT`, `ROOM`, `TURN_LEFT`, `TURN_RIGHT`, `JUNCTION` y `SIDE_ROOM`; `DungeonPlan.get_topology_signature()` representa la estructura sin depender de seed, transforms ni dimensiones. El assembler recorre `DungeonPlan.links` como grafo, no como una cadena de `module_ids`.

Los módulos TEST son tiles canónicos de 8×8 m. Cada `Marker3D` de conector declara posición/orientación, forward/up, rol, ancho útil de 2,40 m y altura útil de 2,00 m. Las puertas se construyen con dos segmentos de pared que dejan esa abertura exacta; antes de aceptar una unión se validan coincidencia de posición, forwards opuestos, up coincidente y dimensiones útiles, y una consulta física con cápsula `r=.40/h=1.80` rechaza seams bloqueados. Los materiales DEBUG unshaded se conservan para Android.

El lifecycle B+C del prototipo incluye ahora `NAV: SYNCING`: después de crear la única `NavigationRegion3D`, espera asíncronamente evidencia del `NavigationMap` actual —proyección horizontal válida de START y EXIT más ruta START→EXIT no vacía— con límite de protección de 120 intentos. Ya no interpreta cinco physics frames como disponibilidad garantizada. Cada reset limpia assembly, proxies y región anterior antes de iniciar el mismo gate; sólo luego publica `NAV: OK` y reposiciona Player.

Validación 6G.2: 20 seeds (`61001–61020`) produjeron 19 topology signatures distintas; todos completaron assembly, seams, START/EXIT proyectables y conectividad después de `NAV READY`. Cinco firmas diferentes completaron cápsula START→EXIT, EXIT→START y acceso a ramas cuando correspondía, sin recovery. Las 20 regeneraciones ocurrieron en la misma instancia y mantuvieron exactamente un assembly, un conjunto de proxies y una región. `Stage6F run structure` y `Fortress6A B+C validation` continúan PASS; Fortress6A no fue modificada.

El prototipo deriva proxies `StaticBody3D + BoxShape3D` automáticamente desde los CSG, con layer 32/mask 0, y bakes una sola NavigationMesh B+C. La cápsula `r=.40/h=1.80` recorre START→EXIT y EXIT→START sin recovery. La validación de regeneración ejecutó diez seeds consecutivos: produjo ocho firmas físicas distintas, recorrió tres layouts distintos ida/vuelta con cápsula real, confirmó mismo seed→misma firma y verificó que queda exactamente un assembly, un conjunto de proxies y una región de navegación activa.

La escena manual está en `scenes/tests/Stage6GProceduralPrototype.tscn`: el botón debug existente **Reset run** se reutiliza sólo en esta escena para generar `seed + 1`, limpiar assembly/proxies/región previa, resolver un nuevo plan, bakear y reposicionar al Player real en START. El overlay muestra `SEED | MODULES | ASSEMBLY | NAV`; el seed permite reproducir exactamente el layout. Fuera de esta escena el botón conserva su reset productivo normal. Esta etapa no altera Fortress6A, Enemy, Encounter ni percepción.

El empaquetador admite una escena inicial exclusiva de validación: el paquete manual de 6G usa `Stage6GProceduralPrototype.tscn` sólo dentro de su `project.godot` archivado; el `project.godot` del workspace conserva `MainFortress6A.tscn` como entrada productiva.

Validación Android 6G.1: el Player no estaba bloqueado ni intersectaba el START (`is_on_floor`, sin overlap lateral y movimiento físico válido), pero la escena aislada no instanciaba `TouchControls`; por eso el joystick Android no entregaba input y la distancia permanecía en cero. El prototipo ahora incluye esos controles y un `PlayerSpawn` explícito en START, orientado hacia la boca de salida. Tres seeds verifican Player real no congelado, sin intersección, con avance físico desde START y rutas START↔EXIT. Los CSG TEST usan materiales unshaded de depuración: suelo START azul claro, EXIT verde, giros violeta, resto azul y paredes gris azulado; no constituyen arte ni iluminación productiva.

### Regresión de lifecycle de Encounter (6G.1)

`stage6g_late_enemy_lifecycle_diagnostic` reproduce A en COMBAT, B detectando tarde y recibiendo `REJECTED`, victoria real de A y cierre del encounter. B conserva ownership de exploración mientras está excluido; al cerrar A limpia exclusión/cierre, registra un candidato nuevo y sólo vuelve a `COMBAT` cuando figura como combatant real del nuevo encounter. El runtime actual pasó sin cambios de gameplay. Este harness cubre el síntoma Android de un externo detenido con `READY/COMBAT` sin pertenencia válida.

## Etapa 6H / 6H.2 — Dungeon Templates, gramática y variantes físicas TEST

`DungeonTemplateResource` contiene una gramática data-driven: reglas por rol,
límites de cantidad/consecutividad, profundidad de camino principal, branches,
roles prohibidos y restricciones de secuencias. Los dos templates exclusivamente
de prueba continúan siendo **TEST_CORRIDOR_HEAVY** y
**TEST_ROOM_BRANCH_HEAVY**; no representan biomas ni contenido canon. El
primero favorece corredores y pocas salas; el segundo conserva salas frecuentes,
una rama lateral y side room. `DungeonPlan` conserva roles, enlaces,
main-path/branch y la definición física elegida, para que futuros sistemas de
contenido puedan consultar estructura sin inferirla desde geometría.

La restricción de transición `ROOM → TURN → ROOM` se declara mediante
`DungeonRoleSequenceConstraintResource`; `RunDirector` sólo consulta esos
Resources y no contiene nombres de módulos TEST. Cuando una elección aleatoria
queda sin continuación compatible, el template permite un único reintento
determinista de generación derivado del mismo seed. Esto evita devolver planes
parciales, sin convertir el director en un solver.

6H.2 añadió vocabulario físico TEST por rol: `test_room` (10×10) y
`test_room_compact` (8×8), más `test_side_room` (8×8) y
`test_side_room_compact` (6×6). `DungeonGrammarRuleResource` declara esas
variantes; el plan sigue describiendo sólo el ROLE y el assembler prueba las
definiciones compatibles y los conectores disponibles en orden determinista
derivado del seed. Cada candidato debe superar contrato de seam y AABB antes
de comprometerse. No se mueve geometría previa ni se acepta overlap.

El placement-aware queda deliberadamente acotado por template:
`max_placement_candidates_per_node`, `max_placement_retries` y
`max_plan_generation_retries`. No hay búsqueda ilimitada ni backtracking
general. La muestra Template B `62001–62020` completó 20/20 assemblies, NAV
READY y limpieza de región/proxies; preservó 18 firmas topológicas, ramas en
20/20 y una media lógica de 2.9 salas y 0.5 corredores. Los antiguos casos
62006/62016 usaron side room compacta; 62019 usó room compacta. Cinco firmas
representativas completaron cápsula física START→EXIT, EXIT→START y acceso a
branches sin recovery. Template A, gramática 6H, Run Structure 6F y el
assembler/B+C 6G también continúan PASS.

Esto sigue siendo infraestructura TEST: no implementa biomas productivos,
loot, enemigos, iluminación, decoración ni backtracking procedural. Si un
template futuro supera el vocabulario físico disponible aun después de sus
variantes, deberá evaluarse un planner con backtracking explícitamente antes
de introducirlo.

## Etapa 6I — Content Placement / Semantic Slots

6I separa explícitamente **gramática** (qué nodos existen), **placement**
(qué lugares semánticos pueden reservarse) y los futuros sistemas de contenido
(qué encounter, loot, evento o interacción se instancia). `ContentSlotDefinitionResource`
declara un slot local inmutable por módulo: categoría, posición/rotación local,
tags, ocupación múltiple opcional y distancia mínima a conectores.
`ModuleDefinitionResource` referencia esos slots; no se infieren de la
geometría ni se agrega un segundo grafo.

Después del assembly, `ContentPlacementDirector` construye un
`ContentPlacementPlan` determinista desde `DungeonPlan + ContentPlacementProfile
+ seed`. Cada `DungeonContentSlot` runtime conserva ID único (`node:slot`),
node propietario, transform global, tags y estado de ocupación. El perfil
data-driven define categorías ponderadas, cantidad mínima/máxima, roles/tags
permitidos o prohibidos, exclusión de START/EXIT y máximo por nodo. Ningún
slot puede reservarse dos veces; una validación física contra los Marker3D de
conectores rechaza slots demasiado cercanos antes de mostrarlos. Los markers
son `MeshInstance3D` DEBUG sin colisión y viven fuera del árbol fuente del
bake B+C.

Los Resources exclusivamente TEST incluyen slots de ROOM, CORRIDOR y
SIDE_ROOM, y dos perfiles: **TEST_COMBAT_HEAVY** (sólo ENCOUNTER) y
**TEST_EXPLORATION** (LOOT/EVENT/INTERACTION/SPECIAL). Con la misma dungeon
seedada `62001`, ambos perfiles conservan idéntica firma física pero producen
reservas distintas; la repetición con mismo seed/profile reproduce la misma
firma de placement y otros seeds producen otra distribución. El harness validó
transform local→global bajo rotación de módulos, ownership por node, START/EXIT
libres, ocupación única, clearance de conectores y placeholders DEBUG.

En `Stage6GProceduralPrototype`, el botón DEBUG **Template TEST** alterna A/B;
**Profile TEST** alterna Combat Heavy/Exploration sin regenerar geometría. El
overlay muestra TEMPLATE, PROFILE, SEED, MODULES, ASSEMBLY, NAV, cantidad de
slots y la leyenda de colores. Esto no crea enemigos, cofres, eventos,
interacciones, loot ni escenas productivas: los sistemas futuros consumirán
`ContentSlot` junto a un content ID/resource y harán el spawn concreto.

## Etapa 6J — Dungeon Archetypes y sectores encadenados TEST

6J añade una capa estrictamente data-driven por encima de la infraestructura
6F–6I. `DungeonArchetypeResource` describe la identidad de una familia de
dungeon —ID, sectores disponibles, rango de sectores, facciones permitidas,
perfiles conceptuales de luz/población y preferencias de habitaciones— y
`DungeonSectorDefinitionResource` describe cada sector físico independiente.
`DungeonArchetypeDirector` consume esos Resources con RNG local derivado del
seed y reutiliza `RunDirector` para producir un `DungeonPlan` por sector. No
hay condicionales por nombre de archetype en RunDirector ni en el assembler.

Los tres Resources de prueba son **ABANDONED_SHIP**, **VARKHEM_BASE** y
**HORVEX_NEST**. Son arquetipos estructurales TEST, no biomas/producto final:
la nave favorece corredores y un único sector DECK; la base usa el template
room/branch-heavy y puede recorrer GROUND_FLOOR→BASEMENT; el nido usa un
template de túneles, junctions y cámaras de huevos y genera 2–3 sectores
UPPER_NEST→DEEP_NEST→CORE_NEST. Facción, iluminación y densidad son sólo
metadata conceptual preparada para futuros sistemas de población/ambiente; 6J
no instancia enemigos, loot, eventos ni iluminación procedural.

`DungeonSectorRun` conserva la identidad/seed, la secuencia y los planes de
sector, pero no duplica estado de gameplay. Al cruzar una transición el
prototipo limpia el assembly/proxies/NavigationRegion del sector anterior,
genera el siguiente y reposiciona Player en su START. HP, O2, ADN,
CharacterStats, loadout y artefactos continúan en `RunState` y no se resetean.
El EXIT contiene un `DungeonTransitionSlot` lógico (por ahora marker DEBUG
amarillo) con tipo data-driven como `STAIRS_DOWN` o `TUNNEL_DOWN`. La
distinción de contrato queda preparada: completar un sector no equivale a
completar toda la dungeon.

La escena manual es `scenes/tests/Stage6JArchetypePrototype.tscn`. Arranca en
modo archetype y muestra ARCHETYPE, SECTOR, SEED, TEMPLATE, MODULES, ASSEMBLY,
NAV, FACTION, LIGHT y POPULATION. En esta escena TEST, **Archetype TEST**
alterna archetype, **Reset run** crea una seed nueva y **Sector transition**
reconstruye el siguiente sector cuando existe. Estas acciones no cambian la
entrada productiva Fortress6A.

Validación 6J: la muestra `63001–63020` fue determinista y produjo Ship
65 corridors/9 rooms/14 branches, Base 23 corridors/91 rooms/30 branches y
Nest 178 corridors/11 rooms/52 branches (contando todos los sectores). Las
pruebas físicas de los tres archetypes completaron B+C y cápsula real
START→EXIT→START; la transición Horvex preservó HP/O2/stats y dejó exactamente
un assembly, un conjunto de proxies y una NavigationRegion. Las regresiones
6F, 6G.2 y 6H continuaron PASS. 6J no implementa pisos conectados físicamente,
arte final, contenidos productivos ni más biomas.

## Etapa 6K — Semantic Locations: Abandoned Ship y Varkhem Base

`SemanticLocationResource` reserva significado sobre un `DungeonPlan` ya
generado, sin alterar su topología ni solicitar geometría al assembler. Declara
roles compatibles, obligatoriedad, profundidad, preferencias de main path o
branch y si el espacio es **TRANSIT** o **DESTINATION**. El plan mantiene las
reservas runtime como `DungeonSemanticLocation`, separadas de la selección de
`ModuleDefinitionResource` y de sus transforms físicos.

### Parte 1 — Abandoned Ship

La Nave Abandonada TEST conserva un recorrido principal dominado por corredores
y destinos cortos laterales: AIRLOCK/SHIP EXIT, BRIDGE y CARGO HOLD son
obligatorios; CREW QUARTERS aparece entre 1 y 5; ENGINE ROOM/MEDBAY son
opcionales y LABORATORY sólo se habilita en LARGE. Cada instancia selecciona
una única facción metadata. La muestra de 20 seeds validó tamaños SMALL/MEDIUM/
LARGE, semánticas obligatorias, determinismo, assembly y navegación hacia/desde
CARGO HOLD. Sus 49 ramas son spurs terminales; no hay branches exploratorios
prolongados bajo el contrato actual.

### Parte 2 / 6K.2 — Varkhem Base y variantes físicas

VARKHEM_BASE usa BASE_ACCESS, CENTRAL_HUB y COMMAND_ROOM obligatorios, más
BARRACKS/PRIVATE ROOM y destinos opcionales ARMORY, FOOD STORAGE y PRISON.
BASEMENT y UPPER_FLOOR siguen siendo sectores independientes opcionales. El
COMMAND_ROOM conserva profundidad mínima y preferencia por UPPER_FLOOR cuando
existe; CENTRAL_HUB representa circulación y está declarado explícitamente como
`TRANSIT`, no como destino. Esto evita que la regla de separación entre destinos
descarte junctions válidos adyacentes a BARRACKS/VARKHEM_ROOM.

El role lógico permanece independiente de la variante física. Cada
`ModuleDefinitionResource` puede declarar `connector_sides` y
`placement_priority`; el assembler consume esos datos, no una topología inferida
por role. Varkhem dispone de `base_hub_junction` (WEST/EAST/NORTH) y
`base_hub_junction_south` (WEST/EAST/SOUTH), ambas variantes del role
JUNCTION. `base_room` es la variante preferida; `base_room_compact` es fallback
geométrico y sólo se selecciona si la estándar no cabe. El placement espacial
mantiene backtracking reversible y determinista con profundidad máxima **2**.

Validación 6K.2: los 11 seeds previamente sensibles a CENTRAL_HUB pasan; la
muestra lógica de 200 seeds Varkhem produjo 200/200 planes válidos y
deterministas. La muestra física `65001–65020` completó 20/20 assemblies,
incluyendo 33 sectores, 142 ROOM estándar, 4 ROOM compactas (las 4 necesarias),
89 junction NORTH, 1 junction SOUTH y dos backtracks totales (máximo 2).
GROUND_ONLY, GROUND_BASEMENT, GROUND_UPPER y el caso SOUTH `65012` validaron
assembly, seams, B+C, navegación, transición y persistencia. No se generó
contenido de combate, loot, boss, arte ni un TEST MOBILE en esta etapa.

La regresión 6J mide ahora contratos estructurales en lugar de comparar el
número bruto de ramas: Ship exige circulación/corredores y spurs terminales;
Varkhem exige densidad de ROOM+SIDE_ROOM, CENTRAL_HUB y decisiones
exploratorias reales. Esto preserva la identidad de ambos archetypes sin usar
una comparación obsoleta de raw branches.

### Parte 3 — Horvex Nest

`HORVEX_NEST` completa el tercer archetype TEST con identidad propia: túneles,
giros y junctions dominantes, dead ends y ramas exploratorias frecuentes,
cámaras opcionales y 2–3 sectores descendentes. `CENTRAL_CHAMBER` es
**TRANSIT**; `SMALL_CHAMBER`, `BROOD_CHAMBER` y `REMAINS_CHAMBER` son destinos
opcionales; `NEST_CORE` es el único destino obligatorio final, profundo y
exclusivo del último sector. El gate lógico ejecutó 200/200 runs válidas
(504 sectores): 96 runs de dos sectores y 104 de tres.

El gate físico `66001–66020` completó 20/20 runs y 50 sectores, con B+C,
seams, cápsula START↔EXIT/NEST_CORE, transiciones, limpieza de assembly y
persistencia de RunState. El backtracking espacial productivo permanece en
máximo **2**. Cuando un plan lógico/semántico válido agota exclusivamente el
placement físico, el template puede habilitar una regeneración de sector
determinista y acotada: el seed efectivo deriva de `run_seed`, índice de
sector y retry; `DungeonSectorRun` registra retry y seed efectivo. HORVEX usa
como máximo **3 intentos** por sector; Ship y Varkhem conservan **1**. En la
muestra: 44 sectores usaron attempt 0, 4 attempt 1 y 2 attempt 2; no hubo
agotamientos. El caso 66005 reprodujo exactamente attempt 0/1 físicos fallidos
y attempt 2 válido.

**Deuda futura — HORVEX MODULE KIT REVIEW:** la tasa de retry físico actual es
6/50 (**12%**). Es aceptable técnicamente, pero el objetivo futuro es reducirla
idealmente por debajo de 10% mediante variantes físicas, offsets o refinamiento
del kit. No aumentar backtracking ni retries como sustituto de esa revisión.

La experiencia manual aislada `scenes/tests/Stage6KArchetypeExperienceTest.tscn`
permite comparar Ship, Varkhem y Horvex con Player real. Muestra archetype,
seed de run, sector, retry, effective seed y estado NAV; sus botones DEBUG no
alteran el entry point productivo Fortress6A.

### 6K.4 — Cierre comparativo

**6K.4A Abandoned Ship, 6K.4B Varkhem Base y 6K.4C Horvex Nest están
CLOSED / PASS.** La generación procedural queda congelada para la evaluación
manual. `Stage6KArchetypeExperienceTest.tscn` es el entry point del TEST
MOBILE comparativo: permite seleccionar SHIP/VARKHEM/HORVEX, crear una seed
nueva y avanzar de sector. El HUD DEBUG conserva archetype, run seed, sector,
effective seed, retry y NAV, y añade el espacio semántico más cercano de forma
discreta. El paquete se genera en la raíz con el patrón
`RogueSpace_TEST_MOBILE_YYYYMMDD_HHMMSS.zip` y no incluye caches ni ZIPs
anidados.

### Base certificada — containment Varkhem + reducción de chambers Horvex

Se integraron y certificaron los dos cambios externos data-driven. Varkhem
activa `enforce_walkable_containment = true` en su template semántico. El
resource recibido contenía el valor en disco, pero su serialización legacy no
lo deserializaba: `ResourceLoader` con cache ignorada devolvía el default
`false`. Se reserializó el mismo `DungeonTemplateResource` en formato canónico
de Godot. La cadena disco → carga directa → duplicate → template activo queda
en `true`. El gate 65001–65020 completó 20/20 runs (33 sectores, 1.148
openings): cero aperturas expuestas, escapes, caídas, fallos de cápsula,
navigation o assembly; 65003 y 65015 conservan sus contratos certificados.

Horvex reduce el rango lógico `ROOM` de los tres perfiles a **1–2**, sin cambiar
los node counts 15/23/29 ni los contratos de branches, junctions, dead ends,
retry o backtracking. El gate lógico de 200 runs completó 504 planes/sectores
válidos y deterministas. La dominancia tunnel-like quedó en 90,7% / 94,6% /
95,2% para LEVEL_1/2/3; las rooms promedio son 1,205 / 1,140 / 1,298. El gate
físico/containment volvió a pasar: 50 sectores, 2.187 openings auditadas,
cero fugas, caídas, escapes, fallos nav o assembly; retries 47/2/1 para
attempts 0/1/2.

**VARKHEM WALKABLE CONTAINMENT y HORVEX CHAMBER REDUCTION: CLOSED / PASS.**
Esta workspace es la nueva base local oficial de RogueSpace. La sincronización
con Google Drive queda pendiente de identificar una carpeta destino accesible;
la búsqueda de Drive no devolvió una carpeta ni archivo RogueSpace y no se creó
una copia paralela.
