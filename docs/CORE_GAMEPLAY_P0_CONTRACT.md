# Core gameplay P0 — admisión y READY compartidos

Rama: `fix/core-gameplay-admission-ready-p0`.
Base: `69ecc66737e23b313daddbfb5c02dac462964cfb`.
Worktree independiente `core_gameplay_p0_worktree`.
Estado vigente: cierre automático y recuperación local documentados al final.
Sin push, merge ni ZIP. Varkhem B/C siguen pendientes Android.
AGENTS.md e informe completo CORE_GAMEPLAY_PHASE1_AUDIT leídos; este último
permanece intacto en su worktree de auditoría (no estaba commiteado en la base).

## Reproducción antes de corregir producción

Fixture nuevo `core_p0_encounter_validation.tscn`: Player/Enemy reales, Resources
orco_melee/xenomorfo sin alterar números, suelo físico CSG y NavMesh de fixture
con ruta alrededor de la barrera. Guardia retenido sólo antes del lock para
aislar el caso cercano; luego física normal. No se fuerza CHASE/READY/COMBAT.
El SOUND repetido se emite por el EventBus público como estímulo de prueba;
no se presenta como movimiento real del jugador inmóvil. Se validan piso y
ruta antes de observar candidatura, APPROACH y combat_started reales.

En ambas especies, pared y HIGH a distancia 2.5007 m produjeron:
`ALERT → APPROACH → COMBAT`, contacto SOUND, exposición 0, LOS false, Player
congelado. Es un defecto real reproducido de inicio de combate, no sólo una
consulta al predicado. En abierto, Horvex entró con VISION_ALERT, exposición
.88/1.0 s; Varkhen esperó confirmación. Procesos de las seis sondas EXIT_0:
el modo `--probe` registra el comportamiento, NO declara correcto el juego.

Logs: `artifacts/core_gameplay_p0/probe_{open,wall,high}_{varkhen,horvex}.log`.
Control adicional probe_slot_open verificó que el validador de slots existente
ya acepta la posición cercana válida, permitiendo reutilizarlo.

## Contrato implementado

1. Visión: candidatura ordinaria requiere confirmación por acumulación real
   (`VISION_CHASE`, sight_timer >= Resource.detection_time_sec), FOV/LOS y
   condiciones actuales de iluminación. `visual_suspicion_enabled` conserva
   umbral/estabilidad ALERT, pero ya no concede admisión visual anticipada al
   estar deshabilitado. Curvas, rangos, FOV, oído y velocidades intactos.
2. SOUND sigue siendo contacto propio reconocido por hearing/radio del Resource
   y memoria existente .35 s. Puede originar investigación/candidatura/APPROACH;
   NO se etiqueta como visión ni se fuerza CHASE. No se añade otro sentido.
   Contacto auditivo no permite READY detrás de una pared/cobertura bloqueante.
3. READY necesita contacto vigente, banda 2–3 m, línea geométrica real y reglas
   LogicalCover/postura, proyección navegable y clearance físico del actor.
   Reutiliza `_is_valid_combat_slot` y exige ruta a la proyección del Player.
   Límite de proyección lateral .12 m existente; no se amplía banda/tolerancias.
   Estar cerca, haber visto antes o figurar nominalmente COMBAT no basta.
4. La emboscada del JUGADOR ya existente es un origen distinto de adquisición
   sensorial del enemigo. Ahora se declara `allow_player_ambush` en Resource:
   default false; true explícito en los tres Resources existentes que ya la
   soportaban. Mantiene validación STEALTH/zona posterior/candidatura propia.
   Sólo exime confirmación sensorial del Enemy, nunca LOS/cobertura/clearance/nav.
   No es una habilidad nueva de Horvex; stage6b_ambush_runtime ya usa Horvex.
5. READY es provisional hasta la frontera final del manager. Cada participante
   se revalida antes de combat_ready. Si dejó de ser válido, recibe el abort
   público existente: parcial si otros continúan, total si ninguno puede.
   No se filtran silenciosamente enemigos todavía poseídos/congelados.
6. Pérdida de contacto conserva LAST_KNOWN, ALERT/investigación y timeouts.
   DROP parcial conserva la obligación de perder contacto. Cancelación TOTAL
   conserva reentrada por tick normal posterior en banda/posición válidas.
   No hay teletransporte, reintento por seed, pausa global ni timeout infinito.

La definición de posición AI `COMBAT` durante espera de otros READY ya existía;
COMBAT efectivo se registra mediante CombatManager.combat_started, no ese texto.

## Cambios de producción acotados

- `scripts/enemies/Enemy.gd`: admisión visual uniforme; refresh sin adelantar
  exposición; READY compuesto reutilizando validadores; gate de ambush Resource.
- `autoloads/CombatEncounterManager.gd`: siete líneas para abortar participantes
  invalidados antes de COMBAT usando el contrato parcial/total existente.
- `resources/enemies/EnemyResource.gd`: excepción explícita player-ambush y
  comentario corregido sobre sospecha vs admisión.
- `orco_melee.tres`, `orco_picaro.tres`, `xenomorfo.tres`: sólo declaración de
  la emboscada preexistente. Ningún parámetro sensorial/balance modificado.

No cambios a arquitectura, solver, START, población, geometría productiva,
navegación, LogicalCover/Player, suspensión, CombatManager, recompensas o ADN.

## Segunda reproducción: invalidación de READY antes de COMBAT

Caso `late_drop`: A alcanza READY legítimamente; B aún se aproxima. Se coloca
una pared real que corta LOS de A. El filtro final previo conservó sólo B en
CombatManager, pero A quedó `state=COMBAT`, `owner=COMBAT`, encounter READY fuera
de la lista. Log `late_drop_before_manager.log`: FAIL_PRODUCTION / EXIT_1.
Es la misma frontera de admisión final/READY, no otra mecánica nueva.

Después de la corrección del manager, ambas especies:
`second_only=true`, `released=true`, A `CHASE / EXPLORATION / DROPPED`, un único
inicio efectivo. PASS / EXIT_0 en `late_drop_checked_{varkhen,horvex}.log`.

## Resultados y STOP

- Matriz dirigida inicial, después del arreglo Enemy: 10/10 PASS / EXIT_0
  (`checked_*`): abierto, pared, HIGH, CHASE y LOS roto durante APPROACH,
  cada uno Varkhen/Horvex. Mantiene diferencias can_patrol/curvas/velocidades.
- Dos casos late_drop posteriores al cambio del manager: PASS / EXIT_0.
- Una expectativa del fixture nuevo se corrigió, NO producción: inicialmente
  prohibía cualquier combate tras una pared. Horvex la rodeó por una ruta válida
  y combatió con LOS true. La aserción ahora evalúa el instante real del combate.
  El FAIL original `final_wall_horvex.log` se conserva; no prueba detección
  a través de pared. Varkhen también puede rodear y recuperar legítimamente.
- Batería existente: 19 PASS / EXIT_0, un FAIL / EXIT_1 con causa de fixture.
  Ledger completo `artifacts/core_gameplay_p0/regression_ledger.csv`.
  Pasaron navegación 5E, comportamiento 5F, escape/double/DROP 5G, patrulla 5H,
  covers/posturas, sospecha B, A2 near-cover, reentrada normal/SOUND stream,
  suspensión, Stage6J playable/reset, combate 6C (victoria/derrota), pared,
  recuperación SOUND/VISION, V213 fase A y emboscada E2E Horvex.
- NO hubo NATIVE_AV en estas ejecuciones registradas. NATIVE_SHUTDOWN_AV
  sigue abierta; no se investigó. Importación EXIT_0 con Safe save failed
  preexistente; no se alteraron settings/OS.

**Bloqueo: stage6b_ambush_negatives_runtime, caso prior_contact.**
Los otros dos negativos no_stealth y frontal pasan, ready_count=0. El tercero
informa `TEST SETUP INVALID (no real VISION)` y no alcanza su aserción de
emboscada con contacto previo. NO se cuenta como PASS ni como regresión de IA.

Instrumentación en test separado `core_p0_ambush_negative_diagnostic` conserva
setup, plazo y expectativas originales. Log `ambush_fixture_diagnostic.log`,
EXIT_1: desde el primer muestreo el rayo intercepta
`MainFortress6A/Fortress6A/Walls/W05`; Player queda z=-2.050851, is_on_floor=false
y cae (Y .994 → .423 → -.271 → -1.238...). FOV YES, LOS NO, exposición 0.
No se puede exigir contacto visual confirmado en esas condiciones.
Fixture y geometría productiva son idénticos a la base; no se ejecutó control
runtime adicional sobre la base para declarar historia de aprobación/fallo.

STOP aplicado: no reparar Fortress6A, no mover sucesivamente el fixture, no
cambiar percepción ni sus expectativas. No continuar la batería tras el bloqueo.
La versión final del fixture dirigido incorporó HIGH físicamente bajo y un caso
SOUND abierto explícito; esa reejecución final ampliada queda NOT_RUN por STOP.
Los 10 casos dirigidos anteriores y los dos late-drop no equivalen a certificación
completa de la versión final; el gate de negativos sigue pendiente.

## Riesgos y siguiente autorización necesaria

Clasificación actual: corrección reproducida/implementada; validación INCOMPLETE
por FAIL_FIXTURE. Sin commit, ZIP o aprobación Android. B/C tampoco aprobadas.

Propuesta siguiente, sólo con autorización: construir el negativo prior_contact
en un espacio de fixture soportado y navegable, con LOS/FOV/cápsulas verificados,
y conservar sus aserciones de no emboscada tras contacto previo. No modificar
Fortress6A para arreglar el test. Después ejecutar matriz P0 final (incluyendo
HIGH bajo, SOUND abierto y política ambush deshabilitada) y repetir batería.

La reutilización de clearance conserva la excepción antigua de piso CSG delgado;
no se afirma soporte nuevo para suelos/meshes arbitrarios. Coste de consultas
extra y experiencia Android pendientes. No retocar rendimiento ni navegación
sin evidencia. No promover este trabajo a CURRENT/main o CLOSED/PASS.

## Cierre autorizado — fixture negativo de emboscada (2026-10-13)

La sección STOP anterior es histórica: no se borran fallos ni se reinterpretan
como PASS. La autorización posterior permitió corregir exclusivamente el
escenario `stage6b_ambush_negatives_runtime`, sin cambios nuevos a producción.

- Suelo CSG y región navegable propios, separados de Fortress6A; la geometría
  productiva y su bake permanecen intactos. Player, Enemy y Resource Horvex
  reales; física, percepción, timers e inputs normales.
- Preflight comprueba apoyo de ambos cuerpos, cápsula interior libre,
  proyección lateral < .12 m y ruta; los casos frontales además FOV/LOS/rango.
  El límite de preparación conserva los 180 ticks existentes.
- Frontal STEALTH empieza a 1.2 m en vez de .45 m para no interpenetrar las
  cápsulas. Sigue siendo frontal, no una entrada a la zona posterior.
- El primer ensayo aislado mantuvo 1 m en prior_contact: exposición alcanzó
  .8 s, ALERT llegó al Player, activó stuck recovery y perdió FOV antes de
  confirmar. Es una precondición visual no sostenida; no se cambió Enemy para
  forzarlo a detectar, ni se aumentaron tiempos de espera.
- El run-up frontal ahora deriva de la velocidad real, detection_time,
  capability de luz y perception_interval, más 1 m libre de cápsulas:
  `speed * (detection_time / capability + interval) + 1` (7.514286 m aquí).
  Permite acumular exposición antes del contacto físico. No se retiene la IA,
  no se fuerza CHASE/contacto ni se llama a callbacks para fabricar detección.
- Tras VISION normal, el Player entra físicamente en STEALTH a la misma zona
  trasera desde 1.55 m. Resultado: `had_vision=true`, `entered_zone=true`,
  `candidate=false`, `contact=VISION`, `state=CHASE`.

Se conservan **exactamente** las expectativas no_stealth, frontal, prior_contact
y `ready_count == 0`; ninguna negativa ni assert se elimina. El contrato probado
sigue siendo que falta de STEALTH, entrada frontal o contacto confirmado previo
impiden la emboscada. No se convierte esta prueba en validación de navegación
de Fortress6A ni se afirma que jamás pueda emboscarse tras perder todo contacto.

Evidencia en `artifacts/core_gameplay_p0/closure/`:
`ambush_negatives.log`, `ambush_negatives_trace.log` (FAIL_FIXTURE / EXIT_1),
`ambush_negatives_corrected.log` (tres negativos PASS / EXIT_0).
Los logs anteriores de W05 se conservan fuera de esa carpeta.

## Diferencias de especies conservadas (Resources actuales, no diseño histórico)

| Campo | Varkhen Carnotauro / Raptor | Horvex Avispa |
| --- | --- | --- |
| Resource | orco_melee / orco_picaro | xenomorfo |
| Visión / FOV | 10 m / 105 grados | 11 m / 140 grados |
| Oído | 4 m | 7 m |
| Curva luz 0–5 | 0/.15/.5/.8/.9/1 | .55/.7/.85/1/1/1 |
| Patrulla | true | false |
| Chase speed tier | 2 / 3 | 4 |
| Sospecha opt-in | true; mínimo .1 | false |
| ALERT puntos de búsqueda | 2 | default 0 |
| noise_response_mode | investigate | investigate |
| can_lose_interest | true | false |

Ambos conservan detection_time=1 s, perception_interval=.2 s,
proximity_override=1.5 m y combat_distance=2.5 m. P0 no cambia estos datos,
la memoria auditiva, iluminación, velocidades ni balance. Los comentarios
históricos que describen CHASE auditivo directo de Xeno no son el valor vivo:
el Resource actual declara `investigate`. No se inventa una excepción sensorial.
La admisión visual confirmada y READY físico son compartidos; el resultado
distinto en oscuridad y tiempos de recorrido proviene de los Resources reales.

## Cierre de validación P0 — estado vigente

**P0 — VALIDADO AUTOMÁTICAMENTE. ANDROID — PENDIENTE.**
Recuperación LOCAL autorizada en esta rama; no integración a main, push, merge
ni ZIP. Varkhem B/C mantienen su estado Android pendiente.

Godot 4.7.2 official ed1daf0bf; mismo ejecutable y APPDATA de los controles.
Carga/importación de editor: EXIT_0, sin parse errors ni scripts faltantes;
persiste el diagnóstico preexistente **Safe save failed** del editor.
No se cambiaron settings ni se investigó esa incidencia.

### Matriz dirigida final (14/14 PASS funcional / EXIT_0)

Cada caso se ejecutó con orco_melee.tres y xenomorfo.tres reales:
open, wall, high, chase, break, late_drop, sound_open.
Ledger: artifacts/core_gameplay_p0/closure/directed_ledger.csv.

- Confirmación visual real antes de combate en open/chase.
- SOUND audible detrás de pared/HIGH: candidatura/investigación pueden existir,
  pero LOS=false y READY=false; no inicia COMBAT a través del obstáculo.
- HIGH físico de 1.1 m, volumen lógico de 3 m: slot geométrico puede resultar
  válido, pero READY sigue rechazado por cobertura lógica. No depende sólo
  de la altura visual de la caja.
- La ruta alrededor de una barrera permanece disponible. Horvex puede rodearla
  y combatir legítimamente: en ese instante LOS y READY son true y exposición
  confirmada. No se considera ese combate un fallo de oclusión.
- SOUND abierto sigue permitiendo contacto auditivo propio y combate en posición
  válida, sin etiquetarlo como confirmación visual (exposición=0, contact=SOUND).
- break prueba invalidación durante APPROACH; late_drop prueba revalidación
  FINAL de READY y liberación de A mientras B inicia el único combate.

### Regresiones finales (24/24 PASS funcional / EXIT_0)

| Harness | Funcional | Proceso |
| --- | --- | --- |
| stage5e_navigation_validation | PASS | EXIT_0 |
| stage5f_behavior_validation | PASS | EXIT_0 |
| stage5g_escape_integration | PASS | EXIT_0 |
| stage5g_double_integration | PASS | EXIT_0 |
| stage5g_drop_integration | PASS | EXIT_0 |
| stage5h_runtime_patrol | PASS | EXIT_0 |
| varkhem_v215_cover_validation | PASS | EXIT_0 |
| varkhem_v215_b_perception_validation | PASS | EXIT_0 |
| varkhem_v215_a2_validation | PASS | EXIT_0 |
| varkhem_v214_reentry_diagnostic | PASS | EXIT_0 |
| varkhem_v214_reentry_diagnostic | PASS | EXIT_0 |
| varkhem_v214_combat_suspension_validation | PASS | EXIT_0 |
| stage6j_playable_combat_reset_validation | PASS | EXIT_0 |
| stage6c_combat_integration | PASS | EXIT_0 |
| varkhem_v214_wall_vision_validation | PASS | EXIT_0 |
| varkhem_v214_sound_recovery_validation | PASS | EXIT_0 |
| varkhem_v214_visual_recovery_validation | PASS | EXIT_0 |
| varkhem_v2_1_3_validation | PASS | EXIT_0 |
| stage6b_ambush_runtime | PASS | EXIT_0 |
| stage6b_ambush_negatives_runtime | PASS | EXIT_0 |
| stage6e_stats_dna_validation | PASS | EXIT_0 |
| stage6j_canonical_species_dna_validation | PASS | EXIT_0 |
| stage6a2_oxygen_validation | PASS | EXIT_0 |
| stage6i_runtime_content_encounter_validation | PASS | EXIT_0 |

Ambos modos de reentry se ejecutan: normal y --sound-stream; A2 usa --near-cover
y V213 usa --phase-a. Ledger con argumentos en el runner y logs completos:
artifacts/core_gameplay_p0/closure/certification/{run_regressions.ps1,regression_ledger.csv}.

Stage6J lifecycle: defeat, defeat_reset, idempotent, victory, resume,
no_duplicate, new_combat y final_reset=true; endings=4, rewards=1.
Esta regresión de UI/lifecycle utiliza la señal pública combat_ready; la admisión
natural se prueba separadamente en la matriz P0, no se atribuye al test de UI.

SOUND recovery valida ruta real: llega al origen, expira candidatura, no
fabrica visión y retorna a PATROL. DROP conserva expulsión, ownership,
suspensión, cuerpo registrado, recuperación y ausencia de cola/duplicaciones.
Stage6J ADN real: tres victorias/recompensas, dna=3, nivel=3, bonus=6,
unlock y exploration resume=true. No se altera balance para P0.

### Regresión física y de entornos (3/3 PASS funcional / EXIT_0)

- varkhem_v215_c_environment_validation --from=65001 --to=65006:
  6 runs / 9 sectores, failures=[], con población/coberturas reales, destinos,
  seams, containment, navegación/cápsula y transiciones. Determinismo adicional
  65001/65003/65005/65015/65020: todos válidos.
- stage6k_ship_physical_validation: SMALL=64005, MEDIUM=64002, LARGE=64001,
  assembly, seams, cargo y recorridos ida/vuelta válidos.
- stage6k_horvex_physical_validation --horvex-from=66001 --horvex-to=66003:
  3 runs / 8 sectores; cero agotamientos, fallos físicos, semánticos o
  containment; todos attempt 0, backtrack_depth=0. Repetición determinista
  de esas tres seeds, recorridos START/EXIT/Core y transiciones válidos.

Ledger: artifacts/core_gameplay_p0/closure/certification/additional_ledger.csv.
No se modificaron Resources, geometría, solver o políticas físicas de biomas.

### Ejecución incompleta preservada (no certificación)

La primera pasada externa añadió --quit-after 2400. DROP terminó por ese límite
de frames antes de su resumen: INCOMPLETE / EXIT_0, **NO PASS**.
closure/regression_ledger.csv conserva cuatro PASS y ese incompleto.
Se repitió la batería con el runner original sin ese límite añadido, dejando
que cada test use sus deadlines existentes y cierre normal. No se alteraron
aserciones, tiempos internos ni producción. La repetición completa es la tabla
final de arriba. Los dos FAIL_FIXTURE de preparación también se conservan.

### Reproducción de la matriz y diagnóstico histórico

Desde el worktree, con $godot apuntando al ejecutable de Godot:
~~~powershell
foreach ($species in @('varkhen','horvex')) {
  foreach ($case in @('open','wall','high','chase','break','late_drop','sound_open')) {
    $arguments = @('--headless','--path','.','scenes/tests/core_p0_encounter_validation.tscn','--',('--case='+$case))
    if ($species -eq 'horvex') { $arguments += '--horvex' }
    & $godot @arguments
    if ($LASTEXITCODE -ne 0) { throw "Proceso fallido; revisar P0_RESULT" }
  }
}
~~~
Exigir además P0_RESULT.valid=true; un EXIT_0 sin resumen es INCOMPLETE.

core_p0_ambush_negative_diagnostic se retiene como reproducción histórica de
la precondición W05 inválida, **no como gate que deba pasar**. Usa el placement
original del caso prior_contact y registra collider, caída, FOV/LOS y exposición.
No se eliminó cobertura negativa: el gate real stage6b_ambush_negatives_runtime
ahora ejecuta satisfactoriamente los tres casos y ready_count=0.

### Preservación y riesgos

- Los 2.727 archivos del manifiesto previo de otros worktrees conservan SHA256.
  Horvex experimental (26 entradas pendientes), V213 (23), auditoría (4)
  permanecen sin descartar ni commitear; V215 C y V214.1 permanecen intactas.
- Ningún cambio nuevo a producción durante este cierre de fixture. El commit
  recupera también las seis modificaciones P0 ya existentes y validadas.
- NATIVE_SHUTDOWN_AV sigue ABIERTA, reproducida históricamente, causa
  indeterminada. Ninguna ejecución final registrada terminó NATIVE_AV; eso
  NO declara resuelta la incidencia ni certifica Android.
- Costo extra de consultas de READY, experiencia móvil, geometrías/suelos no
  cubiertos y nuevos Resources requieren sus propias pruebas. Se conserva la
  excepción anterior de suelo CSG delgado, no un contrato nuevo para cualquier
  mesh. La política allow_player_ambush=false está revisada estáticamente;
  el runtime cubre las especies actuales con su opt-in true.
- No cierre experiencial, cambios de gameplay adicionales ni publicación.
