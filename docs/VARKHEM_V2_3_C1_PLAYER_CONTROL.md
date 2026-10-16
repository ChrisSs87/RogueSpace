# Varkhem V2.3-C1 — Control durante persecución y preparación

## Estado y aislamiento

Rama: fix/varkhem-chase-control-v2-3-c1.
Worktree: varkhem_v2_3_c1_worktree.
HEAD: 7f487b6ce857e69dcdc53e1109f9c2ec2f4c9d69.
Se trasladaron a este worktree los 15 archivos pendientes de B sin crear
commit ni modificar la rama B. La producción heredada de B permanece igual
en contenido. Main y los otros worktrees se conservan.
Estado: validación funcional dirigida; Android pendiente, sin certificación
integral por NATIVE_SHUTDOWN_AV abierta. Sin ZIP, commit, push ni merge.

## Causa reproducida

Enemy confirma visión y solicita candidatura. Tras join_window_sec=1.5,
CombatEncounterManager._lock_encounter revalida contacto, reserva participantes
y, antes de READY, llamaba Player.freeze_for_combat y
ExplorationState.set_encounter_positioning(true). No había comprobación de
posición de combate en esa frontera. La cercanía máxima 3 m se comprobaba
después, en READY y en el inicio efectivo.

Control previo con Player/Enemy reales, suelo, nav y contacto sensorial normal:
7.000 m, FOV=YES, LOS=true, exposición=2.24, READY=false, APPROACH,
starts=0; sin embargo player_frozen=true y suspended=true a 2778 ms.
baseline_corrected_runner.log conserva FAIL/EXIT_1. Para aislar esa frontera,
el fixture mantiene inmóvil al enemigo (no su percepción) hasta la reserva.
Después habilita su movimiento normal. No representa todas las trayectorias
Android ni afirma reproducir sus coordenadas exactas.

Un primer lanzamiento del runner omitió accidentalmente la escena por la
construcción de argumentos PowerShell; abrió Fortress6A y fue interrumpido.
baseline.log se conserva y no cuenta como prueba funcional. Se corrigió sólo
el runner antes de la reproducción válida.

## Corrección mínima y contrato nuevo

Único archivo productivo C1: autoloads/CombatEncounterManager.gd.

- _lock_encounter conserva ventana, cupo, contacto confirmado, excepciones
  legítimas de emboscada, reserva y APPROACH físico hacia el Player vivo.
- Retira de esa fase freeze_for_combat y set_encounter_positioning(true).
  Player, percepción y exploración ajena continúan activos. La lista reservada
  sigue cerrada: no cambia el contrato de incorporación de candidatos.
- Elimina el bookkeeping y la liberación de ese freeze/suspensión anticipados:
  la preparación ya no los adquiere, por tanto cancelar tampoco puede liberar
  un bloqueo adquirido por otro propietario.
- _start_combat_now conserva revalidación final de contacto, FOV, LOS,
  LogicalCover/postura, máximo 3 m, clearance y navegación. Sólo después
  congela Player y emite combat_ready en la misma llamada síncrona.
  CombatManager inicia el combate y ExplorationState adquiere la suspensión
  mediante combat_started; no se inserta ninguna espera entre esas fronteras.
- Se conservan posiciones actuales seguras a corta distancia, tolerancia de
  endpoint junto a pared, timeout 10 s, DROP parcial, cancelación total y
  reentrada, stamina y recompensas. Sin cambio de radios o percepción.

ExplorationState, Enemy, Player, iluminación, coberturas, navegación, población
y Resources no cambian respecto de B. La API set_encounter_positioning se
conserva compatible, pero este coordinador ya no la activa durante APPROACH.
Esta nota sustituye exclusivamente la suspensión anticipada descrita en el
contrato histórico P0-R2; no reescribe sus resultados anteriores.

## Tests C1

Nuevo scripts/tests/v23c1_player_control_validation.gd, UID y escena homónima.
Reutiliza cuerpos, Resources, helpers físicos y trazas del fixture P0-R2.
No fuerza CHASE/READY/contacto ni llama registro interno para simular detección.
Movimiento del Player mediante Input y sus ticks físicos normales.

core_p0r2_encounter_validation.gd: el caso histórico positioning_suspend
exigía pausa antes de COMBAT y contradice explícitamente el nuevo contrato.
Ahora exige exploración libre durante preparación, progreso de la patrulla
ajena y suspensión/inmovilidad al iniciar COMBAT. No se elimina esa cobertura.
Los demás casos/aserciones no cambian. Runner/logs externos en
artifacts/varkhem_v23_c1; detiene secuencia ante un error de proceso funcional.

## Resultados finales (Godot 4.7.2 escritorio/headless)

| Control | Funcional | Proceso / evidencia |
|---|---|---|
| Escape durante APPROACH | PASS | EXIT_0; 1.20 m/0.6 s y otros 2.00 m/1 s, sin COMBAT ni freeze |
| Alcance tras dejar de escapar | PASS | EXIT_0; inicia una vez a 2.967 m, READY/LOS válidos |
| Cancelación y movimiento posterior | PASS | EXIT_0; ownership liberado, progreso 1.20 m |
| Pérdida LOS durante aproximación | PASS | EXIT_0; cero combates, cancelación y movimiento libre |
| Cercanía 1.10 m | PASS | EXIT_0; sin retroceso artificial |
| Junto a pared 1.25 m | PASS | EXIT_0 |
| Esquina 1.15 m | PASS | NATIVE_AV -1073741819 después de P0R2_RESULT valid=true |
| Pareja válida | PASS | EXIT_0; dos participantes, un combate |
| Patrulla ajena en preparación/COMBAT | PASS | EXIT_0; avance antes, inmovilidad después |
| Emboscada E2E | PASS | EXIT_0; bono +2 inicial, turno siguiente normal, emisión única |
| stage5g_drop_integration | PASS | EXIT_0; expulsión/ownership/suspensión/recuperación/sin cola |
| Suspensión y UI/cartas/reset V214 | PASS | EXIT_0; cero movimiento externo, 2 starts/2 endings/1 reward |
| Cancelación total y reentrada | PASS | EXIT_0; blink_cancel, un combate posterior válido |
| SOUND tras pared | PASS | EXIT_0; ALERT auditivo, cero COMBAT y LOS=false |
| Horvex cercano | PASS | EXIT_0; Resource real, posición segura cercana |
| Recompensas OMITIR uno a uno | PASS | EXIT_0; efectos pendientes no aplicados, cierre único, control recuperado |
| Lifecycle victoria/derrota/reset/nuevo combate | PASS | NATIVE_AV -1073741819 después del resumen PASS |

17 PASS funcionales, 15 EXIT_0, 2 NATIVE_AV, cero FAIL funcionales finales.
La reproducción previa FAIL no se convierte retrospectivamente en PASS.
Importación editor EXIT_0, con Safe save failed ya conocido; sin error de
parser/script. Los cierres nativos no fueron investigados ni ocultados.

## Límites y riesgos

- Android debe confirmar comodidad al escapar, encuentro junto a esquina y
  presentación de dos enemigos. Ningún FPS o experiencia móvil certificado.
- Con varios participantes, un Enemy READY puede esperar a otros mientras
  Player sigue libre; se conserva el timeout y la revalidación final. No se
  reescribió la política de agrupación ni se garantiza que todos se admitan.
- La exploración ajena y los estímulos continúan mientras se reserva/APPROACH;
  durante COMBAT/recompensas se mantienen las suspensiones existentes.
- No se repitieron auditorías extensas, mediciones de rendimiento ni la batería
  completa de cada sistema. Regresiones seleccionadas según el cambio.
- NATIVE_SHUTDOWN_AV y Safe save failed siguen ABIERTAS.

STOP. Cambios C1 sin commit para revisión; B y su ZIP siguen intactos.
