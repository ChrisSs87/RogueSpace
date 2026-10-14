# P0-R2 — admisión, posicionamiento no bloqueante y revisión A1–A4

## Estado e aislamiento

Rama `fix/core-gameplay-encounter-p0-r2`, worktree `core_gameplay_p0r2_worktree`.
HEAD/base recuperada P2-C-B: `a110841c37a30df0ced20d392f22184a428fbc67`.
Ascendencia P0 → P1-B → P1-C → P2-B → P2-C-B verificada. Se continúa el
trabajo R2 anterior sin descartar sus cambios. Índice vacío, sin commit/ZIP/push/merge.
ANDROID PENDIENTE. No certificación integral por NATIVE_SHUTDOWN_AV abierta.

La captura Android aporta estado/distancia/sector, pero no coordenadas ni
trayectoria exacta. No afirmamos haber reproducido el mismo rincón de65003.
Sí se reprodujeron sus clases de fallo con cuerpos/resources reales y geometría
determinista;65003 está además incluida en las regresiones físicas procedurales.
El caso manual de exclusión de un segundo enemigo sigue siendo un riesgo:
no se reprodujo una exclusión general de dos candidatos válidos.

## Causas comprobadas

La primera investigación R2, conservada en `CORE_GAMEPLAY_P0_R2.md`, demostró:

- READY aplicaba un mínimo2m absoluto y obligaba a retroceder desde posiciones
  actuales físicamente seguras.
- ALERT visual podía avanzar hasta≈0.8m antes de completar exposición.
- Player válido contra pared/esquina podía quedar fuera del inset del NavMesh:
  cápsula Player radio0.4 frente a bake0.55, error0.14/0.198 mayor que0.12.
- Filtros/cancelaciones podían conservar solicitudes u ownership huérfanos.
- Una cancelación total podía clasificarse como DROP parcial y bloquear reentrada.

La revisión actual reproduce adicionalmente A3: al retirar un participante,
los restantes READY no recibían otra notificación y esperaban al timeout global.
Control previo `admission_before_ready_drop.log`: sigue READY sin COMBAT después
de420ms. Arreglo: reevaluación inmediata tras filtrar; control final20ms,
un solo COMBAT y liberación del descartado.

## Contrato final

1. **Contacto/candidatura:** exposición visual progresiva y sentidos conservados.
   Una candidatura no equivale a COMBAT. SOUND conserva investigación y candidatura
   auditiva, pero no basta para cerrar el lock ordinario ni para READY/COMBAT.
2. **Reserva/posicionamiento:** al cerrar la ventana1.5s se revalida visión confirmada
   real de cada candidato, o la excepción explícita de emboscada. Se suspende el
   control de movimiento del Player y la exploración. Los candidatos confirmados
   todavía lejanos pueden intentar APPROACH; no se declaran combatientes efectivos
   por esa reserva. No se cambia alcance sensorial ni se agrupa por cercanía.
3. **Admisión efectiva/turno:** READY y el límite final revalidan contacto visual,
   FOV, LOS/LogicalCover/postura, distancia máxima configurable3m, clearance de
   cuerpos y navegación. Excepción sensorial legítima `allow_player_ambush`,
   nunca excepción física. No mínimo artificial para una posición actual segura.

Se reutiliza `combat_max_distance_m=3.0`; no Resource sensorial retocado.
`combat_min_distance_m=2.0` y Resource ideal2.5m siguen siendo preferencias de
slots, no requisitos para retroceder. La reserva puede comenzar fuera de3m;
el inicio efectivo de COMBAT no. No se sustituye toda la aproximación lejana por
admisión instantánea ni se modifica la ventana/cupo2 existente.

### Suspensión con ownership explícito

`ExplorationState._positioning` es una causa independiente de suspensión.
`can_update_positioning(actor)` permite únicamente al coordinador y actores
con ownership de posicionamiento avanzar. Los Enemy READY/COMBAT no se mueven.
Percepción, ruido, timers de exploración y patrullas externas permanecen pausados.
No `process_mode` ni desregistro de cuerpos; no pausa global de SceneTree.

COMBAT transfiere la suspensión al owner existente antes de liberar positioning.
Cancelación libera exclusivamente positioning y el freeze del Player adquirido
por él, sin liberar COMBAT/recompensas ajenas. Player conserva cámara libre.
Control compatible con actores reales y TestPlayer de métodos opcionales.

### Posicionamiento y salida

La posición actual segura se acepta primero; se mantienen slots ideales y sus
alternativas deterministas para actores lejanos. Nunca teletransporte ni tolerancia
de overlap. La discrepancia Player/NavMesh sólo admite un puente barrido con su
cápsula real, dentro de su radio y sin atravesar geometría.
Timeout global existente10s, sin aumento. Si no hay participantes seguros se
cancela; si algunos son seguros, se liberan los inválidos y continúan sólo aquéllos.
La retirada de otro actor ya no retrasa a los restantes READY. DROP parcial
conserva pérdida/reconfirmación de contacto; cancelación total conserva reentrada
V2.1.4.1 en posición segura mediante ticks sensoriales normales.

## Escenarios A–J

| Caso | Evidencia final | Resultado |
|---|---|---|
| A contacto moderado | CHASE real desde5m; APPROACH físico hasta≈2.97m | PASS |
| B2.4m | `moderate`, combate≈2.80s, distancia≈2.4007m | PASS |
| C junto a pared | Player sin interpenetración; combate≈1.25m sin retroceso | PASS |
| D esquina | bolsillo sin slot ideal2.5m; posición actual≈1.15m segura | PASS |
| E demasiado cerca | posición actual≈1.10m; no retroceso artificial | PASS |
| F pared interpuesta | P0 wall/HIGH Varkhen y Horvex, con SOUND real | PASS |
| G pérdida de LOS | break/lost/late_drop: revalidación, no COMBAT atravesando pared | PASS |
| H dos confirmados | pair, dos combatientes, un solo inicio | PASS |
| I exclusión legítima | reject + closed_recovery, no agrupación por distancia; recuperación posterior | PASS |
| J sin posición segura | impossible: barrera real durante APPROACH; cero combates y cancelación limpia | PASS |

`positioning_suspend` verifica una patrulla externa que progresaba realmente
antes del lock, inmóvil después; Player congelado y participante acercándose.
La regresión V214 conserva además el control de bystander en CHASE y cuerpos.
Se registran posiciones, distancia, FOV/LOS/contacto/exposición, target, nav/path,
clearance, ownership, memberships, ventana, suspensión y resultado final.

## Claude A1–A4

| Hipótesis | Conclusión y evidencia |
|---|---|
| A1 excepción ambush residual | Confirmada en base: retirada conserva flag/lista. `_release_candidate` limpia ambos; `ambush_withdraw` PASS. |
| A2 stamina residual | Confirmada intención `_ambush_enemy` residual en base. No se afirma haber observado stamina duplicada en Android. `discard_pending_ambush` limpia sólo intención fuera de combate. Retirada y emboscada legítima PASS: bonus+2 primer turno, sin repetición segundo turno. |
| A3 espera READY tras descarte | Confirmada y corregida en esta continuación; reevaluación inmediata y protección contra doble inicio desde timeout. |
| A4 heredar ventana vencida | Base conservaba timer tras retirada del último candidato, riesgo reproducido por withdrawal. R2 lo limpia. `renew_window` retira al último con<0.2s y el nuevo obtiene1.5s. La ventana de un encuentro todavía existente no debe reiniciarse por cada candidato nuevo. No se altera ese contrato. |

Control base A1/A2/A4: `base_control_ambush.log` conserva `valid:false`, flag
de excepción, intención y ventana1.5 residuales. Su EXIT_0 diagnóstico NO es PASS.
No se introdujeron otros arreglos secundarios sin evidencia.

## Ajustes de fixtures y ejecuciones fallidas

- P0 `sound_open` esperaba COMBAT sólo con SOUND: incompatible con la nueva
  orden explícita. Ahora exige cero COMBAT, memoria/origen SOUND y respuesta
  ALERT/CHASE propia de especie. No se elimina cobertura auditiva.
- Stage5H confundía suspensión con COMBAT: APPROACH ahora tiene movimiento
  controlado permitido. Conserva inmovilidad READY/COMBAT/externos, cuerpos,
  progreso de patrulla antes/después y señales. Fallo original conservado en
  `admission_regressions/previous_stage5h_failure.log`.
- `closed_recovery` no puede exigir detección durante la pausa de positioning.
  Comprueba rechazo de la API cerrada, no participación y detección normal tras
  reanudar. `admission_after_closed_recovery.log` conserva el fallo anterior.
- El primer doble falló por acceso nuevo a `is_frozen` de un TestPlayer Node3D.
  Se corrigió compatibilidad de métodos opcionales en producción, no el test.
- Ensayos iniciales del fixture externo no acreditaban movimiento (NO PATH
  inicial), o el actor adquiría visión y era un participante válido. Logs
  `admission_moving*` conservados; no son regresiones del bloqueo de externos.
  El fixture final usa la configuración pública de una patrulla y comprueba
  progreso previo, membership ajeno y ausencia de desplazamiento suspendido.
- Los tres ajustes de temporización/observación anteriores están documentados
  en el primer informe R2; se conservaron y repitieron, sin bajar asserts.

## Batería final — no certificación integral

`../artifacts/core_gameplay_p0r2/admission_final_gate_ledger.csv`, construido por
`summarize_admission.ps1` con cardinalidades exactas, sin filtrar ciegamente FAIL.

| Grupo | PASS funcional | EXIT_0 | NATIVE_AV |
|---|---:|---:|---:|
| R2 Varkhem |21|21|0|
| R2 Horvex |6|5|1|
| Compartidas: Stage5, percepción/covers, reentrada, suspensión, reset, ambush, ADN/O2 |24|24|0|
| P0 Varkhen/Horvex |14|14|0|
| P1 reset/lifecycle/ADN |26|26|0|
| P1-B |10|8|2|
| P1-C |14|11|3|
| Física Varkhem/Ship/Horvex |3|3|0|
| P2-B/P2-C-B |3|3|0|
| Total |121|115|6|

Seis AV `-1073741819 / 0xC0000005` después del resumen PASS: R2 Horvex reject;
P1-B abort_repeat/finish_after_abort; P1-C accept_skip/replace_skip/back_escape.
No normalizados ni investigados. FUNCTIONAL_PASS / NATIVE_SHUTDOWN_AV_OPEN.
No FAIL/INCOMPLETE en la selección final; los intentos anteriores fallidos
siguen separados y no se reclasifican retrospectivamente.

Física: Varkhem65001–65006,6 runs/9 sectores, determinismo dirigido repetido;
Ship3 tamaños; Horvex66001–66003,8 sectores. Seams, containment, cápsula,
navegación y transiciones cubiertos por los harnesses existentes.
Firmas iguales a P2-C-B en28 capturas Varkhem,4 Ship,25 Horvex (no seed counts).
Los9 payloads Varkhem conservan módulos/templates/semánticas/seed/retries/
backtracks/población/rutas/contenido/ambiente. No cambios de generación o balance.
Editor y arranque Varkhem65001: EXIT_0, assembly/nav válidos, sin parse errors;
`Safe save failed` sigue registrado en importación, no investigado.

## Archivos y preservación

Producción: `autoloads/CombatEncounterManager.gd`, `autoloads/CombatManager.gd`
(sólo intención ambush pendiente), `autoloads/ExplorationState.gd`,
`scripts/enemies/Enemy.gd`.
Debug aislado: `scripts/tests/InfiltrationInspection.gd` añade resumen opcional
ENC/IN/OUT y motivo POS/admision; no nuevos textos flotantes permanentes.
Fixtures existentes: `core_p0_encounter_validation.gd`, `stage5h_runtime_patrol.gd`,
`stage6b_ambush_runtime.gd`, `varkhem_v214_recovery_validation.gd`,
`varkhem_v2_1_2_validation.gd`.
Nuevos: `core_p0r2_encounter_validation.gd`/UID/escena y los dos informes R2.

2727 archivos de otros worktrees:0 diferencias contra manifiesto de preservación.
Main sigue `8bc3e890d5983700db9465fa41c3607cb3b831a9`; P2-C-B limpio en su rama.
Resources, percepción sensorial, START, población, navegación/solver, iluminación,
coberturas, recompensas y contenido de otros biomas no modificados.
El ZIP CORE P2CB anterior sigue intacto y NO contiene R2.

## Riesgos y siguiente paso

- Prueba Android necesaria, especialmente65003 GROUND_FLOOR y su rincón exacto,
  confort a corta distancia/Cardboard, doble encuentro y retorno/reset.
- No promesa de admisión por cercanía; cada actor requiere contacto propio,
  ventana/cupo y geometría válida. El caso manual múltiple no quedó confirmado.
- La suspensión comienza en la reserva de posicionamiento, antes del turno;
  validar sensación de esa transición en móvil. Timeout conservado10s.
- No FPS garantizados ni nueva certificación táctica P2-C-B (INCOMPLETE histórico).
- NATIVE_SHUTDOWN_AV y Safe save failed abiertas. Sin ZIP/commit/push/merge.

STOP, cambios preparados para revisión.
