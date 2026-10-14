# Core Gameplay P0-R2 — admisión, posición y recuperación

Rama: `fix/core-gameplay-encounter-p0-r2`.
Worktree: `core_gameplay_p0r2_worktree`.
Base recuperada: `a110841c37a30df0ced20d392f22184a428fbc67` (P2-C-B).
Sin commit, push, merge o TEST MOBILE. ANDROID PENDIENTE.
No modificación de main/otros worktrees, Resources, generación, iluminación,
mobiliario, población o reglas de recompensas. NATIVE_SHUTDOWN_AV no investigada.

## 1. Reproducción, no suposición

Fixture `core_p0r2_encounter_validation`: Player/Enemy reales, Carnotauro,
Raptor y Horvex Avispa reales, suelo físico y NavMesh de test con inset equivalente
al radio0.55 de producción. Las posiciones de pared/esquina dejan0.41 al Player
de radio0.4, sin interpenetración. Capas/máscaras físicas originales.
En los casos cercanos se retiene movimiento sólo antes del lock, no detección;
al entrar APPROACH se habilita física normal. No se fuerza CHASE/READY/COMBAT,
exposición o resultados de percepción. Las operaciones withdraw/reset usan APIs
públicas para los casos de lifecycle. Recursos sensoriales/balance intactos.

El modo `--probe` devuelve EXIT_0 para recoger evidencia, pero conserva
`valid:false` y errores: **no significa PASS funcional**. Logs en
`../artifacts/core_gameplay_p0r2`. También se creó copia de control del commit
base fuera de los worktrees para verificar retirada de emboscada con fixture
actualizado, sin editar producción base ni las ramas anteriores.

| Escenario | Base observada | Diagnóstico |
|---|---|---|
| A cercano1.1m | retrocede a≈2.00m; combate≈2.83s | mínimo2m usado como requisito absoluto READY |
| Raptor dinámico desde3m | llega≈0.80m y luego retrocede | ALERT visual sin confirmar navega hasta Player con umbral de llegada.3, antes de CHASE |
| B Player junto a pared | LOS/contacto/clearance válidos; no combate en16.5s | proyección Player0.14m supera0.12; tras timeout queda CHASE con cancelación pendiente |
| C Player en esquina | LOS/contacto/clearance válidos; no combate en16.5s | error Player≈0.198m y no cabe ningún slot ideal2.5m en el bolsillo; posición actual≈1.15m sí es segura |
| D dos detectores válidos | PASS, ambos combaten | no se reproduce un fallo general de todos los pares |
| E sin confirmación / ventana cerrada | exclusión legítima | cercanía no basta; conservar sentidos, ventana y cupo |
| F LOS perdido en APPROACH | no COMBAT a través de pared | control negativo conserva cancelación; READY tardío se cubre además con P0 late_drop |
| Candidato invalidado antes de lock, otro válido | request true sin pertenecer a pending; CHASE | el filtro descartaba sin release al candidato eliminado |
| FULL antes de lock, luego plaza liberada | sólo un combatiente, guardia elegible no reintenta | join_closed permanente con excluded=false |
| Breve pérdida/restauración de LOS, todos descartados | READY true/contacto confirmado; CHASE sin solicitud | cancelación total por validación se trataba como DROP parcial, a diferencia del timeout total |
| Reset durante APPROACH | ownership residual | reset borraba listas sin abortar posicionamiento de actores vivos |
| Última candidatura retirada | window restante>0 | cancel no limpiaba el timer de ventana |
| Emboscada retirada | excepción, intención de bonus y ventana permanecen | scopes de admisión/bonus no se liberaban al withdraw |

Primeros ensayos pared/esquina tenían preflight incorrecto: contaban contacto
normal con el suelo como obstrucción. Se preservan esos logs FAIL_FIXTURE;
el fixture corregido identifica el suelo y verifica soporte/interpenetración
antes de emitir las conclusiones de producción anteriores.

## 2. Contrato y cambios mínimos productivos

### Enemy.gd

- ALERT visual incierto mantiene distancia ideal configurada mientras acumula
  exposición, sin entrar en búsqueda por haber alcanzado ese standoff.
  VISION_NONE/SOUND siguen viajando a LAST_KNOWN e investigando normalmente.
  No cambios a FOV, alcance, curvas, threshold, intervalos, oído o velocidades.
- READY admite posición actual a menos de2m si supera contacto fresco, LOS/
  cobertura/postura, máximo3m, NavMesh, mundo y clearance entre cuerpos reales.
  No mínimo artificial que obligue a retroceder. Slots alternativos conservan
  banda preferida2–3m, objetivo Resource2.5m y búsqueda angular acotada existente.
- Clearance actual incluye Player y otros Enemy; no se permite resolver
  proximidad aceptando cuerpos interpenetrados. No máscaras globales cambiadas.
- `_player_navigation_endpoint_valid`:0.12m sigue siendo vía normal; una
  discrepancia mayor sólo se acepta dentro del radio real de cápsula Player,
  con sweep libre hasta la proyección. Usa shape/transform/safe_margin reales;
  separa únicamente contacto normal de suelo mediante ese safe_margin.
  No proyección arbitraria al otro lado de pared, teletransporte o path inventado.
  No modificación de bake, solver, límites ni NavigationServer.
- Un FULL anterior al lock permite otro intento desde contacto normal cuando
  exista capacidad y no haya encuentro bloqueado. No agrega por distancia;
  mantiene separados excluded, must-lose-contact y cancelación total.
- Release/abort retiran excepción ambush; getter diagnóstico expone motivo
  ACCEPTED/CAPACITY_FULL/WINDOW_CLOSED y guards de reentrada. API pública
  `has_combat_positioning()` evita basar limpieza productiva en etiquetas HUD.

### CombatEncounterManager.gd

`_release_candidate()` unifica retirada, filtrado, abort y reset: elimina scope
ambush, descarta intención de bonus pendiente y libera posicionamiento si existe;
en candidatura simple usa release. El filtro de lock ya no abandona requests.
Validación de APPROACH calcula primero retenidos para distinguir parcial/total.
Timeout y filtro final reutilizan la misma liberación. Cancel limpia también
window_timer; reset ejecuta esa frontera antes de borrar listas. Reset después
de COMBAT no se etiqueta cancelación total de APPROACH: antiguos participantes
conservan guard de no reentrada automática hasta pérdida de contacto.

No se cambia join_window1.5s, max2, timeout10s, separación angular ni slots.
Sigue sin haber cola automática ni combate simultáneo. Rechazos legítimos y
DROP parcial se conservan. Cancelación total puede reentrar en un tick sensorial
normal, una vez que contacto y posición realmente sean válidos.

### CombatManager.gd

Sólo `discard_pending_ambush(enemy)`: limpia la referencia de una intención
cancelada si pertenece a ese enemigo y todavía no hay COMBAT. No cambia bonus
consumidos, stamina, cartas, turnos, victoria/derrota o recompensas.
La emboscada legítima conserva +2 stamina inicial y sus gates existentes.

## 3. Auditoría A1–A4 de Claude

**INCOMPLETE_NO_SOURCE_TEXT**. La revisión no está adjunta ni se encontró en
docs de la base. Se pidió al usuario el texto mediante consulta no bloqueante.
No se inventaron correspondencias entre A1–A4 y los defectos reproducidos.
Las correcciones anteriores tienen evidencia propia; falta contrastarlas con
las cuatro afirmaciones concretas cuando se reciba el informe.

## 4. Fixtures temporales expuestos por el standoff correcto

Dos regresiones dependían accidentalmente de entrar en proximidad1.5m para
acelerar confirmación. A luz1 la capacidad real es.15:34 ticks×.2s =6.8s.
No se alteró producción para hacer pasar ninguno de estos escenarios.

- `varkhem_v214_recovery_validation`: deadline1.6s, FOV/LOS/rango/soporte
  válidos, sight_timer.24 y VISION_ALERT. Falló con etiqueta original
  FAIL_PRODUCTION, conservada en log; la auditoría demostró un límite de
  fixture incompatible con Resource. Ahora deriva confirmación de capacidad
  efectiva, intervalo y threshold, conservando todas las aserciones.
  Repetición: sight1.02, VISION_CHASE, pending1, sin ruido ni señales duplicadas,
  PASS/EXIT_0 (`vision_timing_checked.log`).
- `varkhem_v2_1_2_validation._contact_lifecycle`: corte fijo480 frames (~8s),
  cuando contacto ya es VISION, sight1.17–1.20, READY true y ventana aún
  tiene.293–.300s. `phase_a_timing_diagnostic.log` conserva EXIT_1 y ambos
  fallos. El límite ahora deriva de confirmación+join+timeout APPROACH+
  tres intervalos de muestreo ya utilizados, saliendo tan pronto inicia combate.
  No se cambian posiciones, parámetros ni asserts de CHASE/search/PATROL,
  orientación, contacto o inicio real de COMBAT.
- `stage6b_ambush_runtime`: el combate correcto, STEALTH, participante y bonus
  5→3 ya pasaban; sólo fallaba `approach_seen`, por muestrear después de una
  transición ahora inmediata a corta distancia. Observer de test conserva
  Enemy.tscn, cuerpos/Resource y llama `super.begin_combat_approach()` exactamente
  una vez; observa entrada APPROACH y ownership antes del siguiente callback.
  No fuerza estado ni añade un frame de retraso a producción. Todas las
  aserciones originales, incluida ocurrencia de APPROACH, quedan intactas.
  `ambush_original_failure.log` conserva EXIT_1 anterior; repetición PASS/EXIT_0.

No son esperas fijas añadidas para esconder fallos: son cotas de fallo que
respetan reglas actuales de luz, admisión y posicionamiento. Si no existe
capacidad visual, el fixture falla como configuración, no fuerza detección.

## 5. Validación y estado de entrega

Matriz dirigida R2 final:16 casos Varkhem +6 Horvex =22/22 PASS funcional/EXIT_0.
Incluye rechazo legítimo CLOSED y recuperación posterior independiente; el
participante anterior no se reencola. Distancias próximas después del arreglo:
abierto≈1.10m, pared≈1.25m, esquina≈1.15m sin retroceso; Raptor dinámico conserva
≈2.45m en vez de0.80m. No se demuestra que todo enemigo cercano deba sumarse.

### Batería final seleccionada

**116 PASS funcionales /109 EXIT_0 /7 NATIVE_AV.** No certificación integral.
Las tres ejecuciones de fixtures anteriores fallidas NO se convierten en PASS
histórico ni se incluyen como exitosas en ese total. Logs y resultados originales
conservados; se seleccionan repeticiones corregidas explícitas, no se filtran
ciegamente todos los FAIL. `summarize_final.ps1` construye final_gate_ledger.csv
con los casos exactos y verifica cardinalidades y arquitectura.

| Grupo | PASS funcional | EXIT_0 | NATIVE_AV |
|---|---:|---:|---:|
| Nuevos R2 Varkhem/Horvex |22|22|0|
| Compartidas Stage5, covers, reentrada, suspensión, reset, ambush, ADN/O2/runtime |24|21|3|
| P0 Varkhen/Horvex (incluye SOUND, pared, HIGH y READY tardío) |14|14|0|
| P1 lifecycle/reset/ADN |26|26|0|
| P1-B abort/idempotencia/ownership |10|9|1|
| P1-C resolución/OMITIR/UI |14|12|2|
| Física Varkhem/Ship/Horvex |3|3|0|
| P2-B perfiles/observabilidad + P2-C-B hubs |3|2|1|

Los siete AV conservan -1073741819/0xC0000005 después del resumen PASS:
suspensión V214, wall vision V214, Stage6E stats/ADN, P1-B scene_change,
P1-C repeat_ui/new_reward y P2-B profiles. Sin atribuir causa ni investigarla.
Carga inicial editor y control base: EXIT_0; Safe save failed sigue registrado.

Varkhem65001–65006:6 runs/9 sectores; cuerpo, suelo, seams, containment,
NavMesh, transiciones, población y coberturas PASS funcional/EXIT_0.
Determinismo repetido65001/65003/65005/65015/65020. Firmas de assembly idénticas
a P2-C-B:28 capturas Varkhem,4 Ship y25 Horvex (incluyen repeticiones, no son
cantidades de seeds). Ship cubre3 tamaños; Horvex66001–66003 cubre8 sectores.
Payloads de los9 sectores Varkhem idénticos: módulos/templates/semánticas,
profundidades, seed efectivo/retries/backtracks, población/rutas, runtime y
room_environment. No se retocaron arquitectura, enemigos ni mobiliario para PASS.

### Preservación y archivos

Base/HEAD sigue a110841; índice vacío. P2-C-B permanece limpio en su rama.
Main conserva8bc3e890d5983700db9465fa41c3607cb3b831a9.
2727 archivos de otros worktrees:0 diferencias contra manifiesto de preservación.
ZIP CORE P2CB anterior intacto (SHA256
6F6802809BEE9F2A543D730183F5C1D2B87F8BDDF87D1F8E08025FFECC835DBF);
NO contiene R2 y no se sustituye en esta tarea.

Producción modificada: Enemy.gd, CombatEncounterManager.gd, CombatManager.gd
(sólo intención ambush pendiente). Fixtures modificados: varkhem_v214_recovery_validation.gd,
varkhem_v2_1_2_validation.gd, stage6b_ambush_runtime.gd. Nuevos: fixture R2 .gd,
.uid, .tscn y este informe. Diez entradas de status, sin stage/commit.
RewardManager, RunState, DNAManager, UIs productivas, GameBalance, Resources
sensoriales, generación/iluminación/mobiliario y los otros worktrees intactos.

## 6. Riesgos y límites

- Nueva prueba Android obligatoria: entrada en esquina/pared, UI a corta
  distancia/Cardboard, múltiples enemigos, percepción progresiva y reset.
- Las solicitudes siguen requiriendo contacto propio; un segundo enemigo
  aparentemente cercano puede no estar confirmado o llegar fuera de ventana.
- SOUND mantiene investigación de su posición situada; no se convierte en
  visión ni se cambia su movimiento para satisfacer un standoff visual.
- No garantías de dificultad/evasión o FPS; no cambios a arquitectura/población.
- Táctica dinámica P2-C-B sigue INCOMPLETE, no se recertifica por estos tests.
- NATIVE_SHUTDOWN_AV y Safe save failed continúan abiertas.
- A1–A4 de Claude pendiente de texto, no declarado revisado.
- Sin commit, ZIP móvil, push ni merge. Dejar para revisión y STOP.
