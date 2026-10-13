# Core Gameplay P1-B — cierre de recompensas

Fecha: 2026-10-13. Rama aislada `fix/core-gameplay-reward-lifecycle-p1-b`.
Base: P0 `7c063ec4f2aceaca588dfa44185420b05e03e821`.
ANDROID — PENDIENTE. No integración a main ni aprobación Android de Varkhem B/C.

## Causa y alcance

P1-A reprodujo 17 inconsistencias: los resets de escena/prototipo no cerraban
la recompensa persistente del autoload. Regeneración liberaba exploración con
UI/pending todavía activos; reload destruía Player/UI, pero conservaba pending,
referencia al Player liberado y suspensión de recompensa.
No era un defecto de cálculo de ADN ni de conservar elecciones confirmadas.
El informe histórico completo se conserva en CORE_GAMEPLAY_P1A_REWARD_DIAGNOSIS.md.

Se modifica exclusivamente el lifecycle de RewardManager y sus propietarios/
callers de salida. No cambios a probabilidades, thresholds, curación, mazo,
ADN, combate, navegación, geometría, especies, población o percepción.

## Contrato público

```gdscript
abort_reward_sequence(reason: String = "cancelled", expected_sequence_id: int = -1) -> bool
is_reward_active() -> bool
get_sequence_id() -> int
get_last_close_result() -> Dictionary
```

- Abort devuelve true sólo si cerró la secuencia activa. Idle/repetición/ID
  antiguo son no-op, sin señales ni efectos. El ID es monotónico en el proceso.
- DONE, pending ADN/carta/kit/mensaje vacíos y Player=null se publican ANTES
  del evento terminal. Se desconecta el callback del Player de esa secuencia.
- `_finish()` y abort comparten un cierre protegido contra reentrada.
- `reward_sequence_finished` conserva su firma SIN argumentos. Significa
  cierre terminal, NO necesariamente victoria/recompensa completada.
- Durante el evento, `get_last_close_result()` entrega una copia de
  `{sequence_id, kind: "completed"|"cancelled", reason}`. No es persistencia.
- La bandera reward se libera mediante el consumidor existente de
  ExplorationState. No se usa reset_for_regeneration como cancelación global.
- Sólo se descongela un Player válido, dentro del árbol, no encolado para
  destruir y sin otra suspensión activa. Se conserva una suspensión de combate
  ajena; RewardManager no adquiere ni libera ownership de ese combate.
- Una secuencia activa no puede ser sobrescrita. Durante el dispatch terminal
  síncrono no se acepta otra: el caller debe esperar al retorno o diferirla.
- SUMMARY se inicializa antes de started; si un listener cancela, no se
  resucita el paso. Los callbacks de ADN/curación también verifican secuencia
  después de emitir señales externas antes de volver a escribir estado UI.

## Política de efectos

Cancelación descarta ofertas/elecciones pendientes. No confirma ADN, cartas o
kit pendientes. No revierte ADN, unlock, reemplazo de carta o curación ya
confirmados. Un unlock confirmado cuyo reemplazo no fue elegido permanece
desbloqueado, NO equipado. No se agrega inventario ni se reofrece esa carta.

Abort no redefine reset_run ni inicio de una run nueva. Las políticas vigentes:

| Caller | Orden | Progreso |
|---|---|---|
| Stage6G.regenerate_from_debug | abort antes de limpieza RuntimeContent | preserva efectos confirmados |
| DebugHUD fuera de prototipo | abort → DNA.reset → reset_run → resets combate → reload | limpia ADN como antes |
| CombatUI restart | abort → DNA.reset → reset_run → resets combate → reload | limpia ADN como antes |
| FortressEndTrigger.restart_test | abort → reset_run → reload | conserva ADN/bonos como antes |
| Destrucción de Player | tree_exiting con ID capturado → abort | no toca nodo destruido |
| Destrucción de RewardUI | _exit_tree con ID propio → abort | UI antigua no cancela recompensa futura |
| Finalización normal | _finish → cierre completed | mismos efectos y reglas |

No existe un nuevo reset global ni un contrato productivo nuevo de nueva run.
Para cambios genéricos de escena, los callbacks de salida son la red de
seguridad antes de liberar los nodos propietarios. Los callers conocidos
abortan explícitamente antes de reemplazar contenido; no necesitan esperar
a que se liberen las referencias.

## Archivos de producción

1. autoloads/RewardManager.gd: contrato/cierre único y guardas reentrantes.
2. scripts/ui/RewardUI.gd: ID propietario, abort al salir, limpiar ID al cerrar.
3. scripts/world/Stage6GProceduralPrototype.gd: abort antes de regeneración.
4. scripts/ui/DebugHUD.gd: abort antes de reset completo.
5. scripts/ui/CombatUI.gd: abort antes de restart.
6. scripts/world/FortressEndTrigger.gd: abort antes de Well restart.

ExplorationState, CombatManager, Enemy, Player, RunState y DNAManager intactos.

## Fixtures y cobertura

Se conservan las cuatro fuentes P1-A originales en su worktree sin edición.
Se copian aquí informe, escena, script y UID. En la copia del script se extrae
un hook `_validate_interruption` manteniendo sus asserts diagnósticos originales.
La subclase P1-B sobrescribe ese hook con el contrato terminal más estricto:
DONE/inactivo/ref null/pending vacío/UI oculta/freeze y suspensión liberados,
exactamente una señal al cancelar y cero adicional tras finalizar, más
preservación/limpieza del progreso según caller.
No se exige conservar una referencia al Player después de abort exitoso.
El original P1-A y sus resultados FAIL históricos no se reescriben como PASS.

Se reutilizan los 26 escenarios reales (9 puntos regen, 9 reset completo,
2 Well, derrota/reset, sector, reset_run aislado, arranque fresco y 2 ADN/reset).
Las acciones usan victorias, Player/UI reales y callers productivos. Los
límites de fixture/semilla RNG/control de actores de P1-A siguen documentados.

Diez escenarios adicionales en core_p1b_abort_contract_validation:
abort repetido; finish tras abort; abort tras finish; Player destruido; UI
destruida; cambio real de escena; nueva recompensa/ID obsoleto; efectos
confirmados vs pendientes; suspensión ajena; carreras de callbacks terminal,
ADN y started. Sólo el control white-box de cierre llama `_finish` para probar
idempotencia, nunca para fabricar una recompensa o una victoria.

Comandos desde el worktree, usando el mismo Godot 4.7.2 de P0:

```powershell
$env:APPDATA='C:/Users/chris/OneDrive/Documentos/RogueSpace/artifacts/varkhem_v2_1_5/b/appdata'
& 'C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64_console.exe' --headless --path . scenes/tests/core_p1b_reward_validation.tscn -- --operation=regen --step=dna_result
& 'C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64_console.exe' --headless --path . scenes/tests/core_p1b_abort_contract_validation.tscn -- --operation=foreign_combat
```

Evidencia/ledgers/runners en `../artifacts/core_gameplay_p1b`. Los runners de
P0 se copian allí, no sobrescriben sus evidencias. Se usan deadlines internos
de harness, sin límite externo de frames que corte comprobaciones.

## Validación y pendientes

| Batería | Funcional | EXIT_0 | NATIVE_AV |
|---|---|---|---|
| 26 escenarios P1-A con contrato P1-B | 26 PASS | 25 | 1 |
| Diez controles adicionales de abort/ownership | 10 PASS | 10 | 0 |
| P0 dirigido, siete casos por especie | 14 PASS | 14 | 0 |
| Regresiones compartidas | 24 PASS | 22 | 2 |
| Controles físicos Varkhem/Ship/Horvex | 3 PASS | 3 | 0 |
| **Total harnesses** | **77 PASS** | **74** | **3** |

Los **17 FAIL anteriores pasan funcionalmente**, todos esos 17 con EXIT_0.
No se detectó FAIL funcional ni setup incompleto en estas 77 ejecuciones.
Varkhem 65001–65006: 6 runs/9 sectores; determinismo adicional 65001, 65003,
65005, 65015 y 65020, incluyendo cobertura/luz/navegación/content. Ship:
SMALL/MEDIUM/LARGE (64005/64002/64001), seams/semántica/navegación ida-vuelta.
Horvex 66001–66003: 3 runs/8 sectores, assembly/seams/containment/navegación
y transiciones según el harness existente. Tres controles PASS/EXIT_0.
Datos completos en additional_ledger.csv y logs asociados.

Las dos importaciones de editor terminaron EXIT_0, sin errores de parse ni
scripts, con el diagnóstico Safe save failed preexistente. Son controles de
carga adicionales, no se suman al denominador de 77 harnesses.

Preservación: manifiesto previo de 2.727 archivos de otros worktrees, cero
diferencias. P0 continúa limpio. P1-A conserva sus cuatro archivos nuevos
originales y su rama/HEAD. main permanece en 8bc3e890d5983700db9465fa41c3607cb3b831a9.
No operaciones de publicación, merge, reset, clean ni generación de ZIP.

Las 24 regresiones cubren navegación/behavior; escape/double/DROP/patrulla;
coberturas/postura/sospecha/A.2; cancelación/reentrada normal y SOUND continuo;
suspensión; Stage6J playable/reset; integración de combate; paredes; recuperación
SOUND/VISION; IA fase A; emboscada y negativos; stats/ADN; IDs canónicos; oxígeno;
runtime content encounters. Matriz completa: regression_ledger.csv.

Tres cierres nativos registrados tras el resumen funcional válido:

- diagnostic_ledger.csv: dna_sector, PASS, -1073741819 (0xC0000005).
- regression_ledger.csv: 15_varkhem_v214_sound_recovery_validation, PASS,
  valid=true/errors=[], -1073741819 (0xC0000005).
- regression_ledger.csv: 20_stage6e_stats_dna_validation, PASS,
  -1073741819 (0xC0000005).

No se atribuye su causa a esta corrección ni se declara resuelta. No se
vuelven a ejecutar para reemplazar su evidencia por una ejecución EXIT_0.
**FUNCTIONAL_PASS / NATIVE_SHUTDOWN_AV_OPEN**, no certificación integral.
La creación del commit de recuperación se deja pendiente: la autorización
estaba condicionada a controles satisfactorios y existen procesos NATIVE_AV.
Código/documentación/tests permanecen sin commit en el worktree aislado.

### Recuperación autorizada posteriormente

El usuario autorizó explícitamente recuperar este estado sin cambiar su
implementación, conservando el historial anterior. **P1-B — PASS FUNCIONAL.
NATIVE_AV — ABIERTO. ANDROID — PENDIENTE.** El commit local de recuperación
incluye únicamente los seis archivos productivos descritos, fixtures P1-A/P1-B
y sus informes. No convierte los tres NATIVE_AV en EXIT_0 ni certifica Android.
P1-C debe partir de este commit en rama/worktree independiente.

NATIVE_SHUTDOWN_AV sigue ABIERTA, causa indeterminada, no investigada aquí.
Safe save failed sigue ABIERTA: observado en importación EXIT_0, sin modificar
configuración. Un resultado funcional seguido por AV no es aprobación integral.
No se repiten ejecuciones para ocultar el código nativo.

## Narrativa futura

El terminal consultable permite distinguir cancelación de finalización sin
romper consumidores actuales. Narrativa puede posponer/rechazar su apertura
durante reward o cancelar explícitamente la secuencia correcta con ID.
No debe usar un reset global de ExplorationState para soltar una pausa propia.
Actualmente ExplorationState sólo modela combat/reward: una futura suspensión
narrativa necesita ownership propio antes de integrarse. Este cambio NO
implementa videos, persistencia de secuencias vistas, skip ni tokens narrativos.
