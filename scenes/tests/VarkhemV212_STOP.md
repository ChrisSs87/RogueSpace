# Varkhem V2.1.2 — STOP / implementación preservada sin commit

> Historical STOP record. The subsequently authorized stabilization and
> current results are documented in VarkhemV212_STABILIZATION.md. The
> statements below describe the earlier task, not the final branch status.

Base limpia: 51efd77be10e0bd0da768d4331456269f4cab815 (V2.1.1).
Rama: feature/varkhem-patrol-infiltration-v2-1-2.
Worktree independiente: ../varkhem_v2_1_2_worktree.
No publicación, merge, commit ni ZIP. Pendiente de autorización/revisión.
No CLOSED/PASS experiencial ni certificación completa.

## Auditoría y cambios implementados

Enemy conserva la única máquina de estados: PATROL, IDLE, ALERT (investigación),
CHASE, APPROACH, COMBAT y BOSS_IDLE. No se crea INVESTIGATE paralelo. Usa el
NavigationAgent/ancla y recuperación existentes; ALERT viaja a LAST KNOWN y
busca antes de volver a PATROL. Vision usa distancia, FOV, LOS, luz lógica del
Player y exposición sostenida. Oído usa eventos de desplazamiento real.

La causa del IDLE procedural era la ausencia de patrol_points y el fallback
del consumidor que duplicaba EnemyResource con can_patrol=false. Ahora un
perfil opt-in espera al bake sincronizado antes de consumir los encuentros.
ContentPatrolRoutes obtiene puntos locales declarativos relativos al footprint
real y aplica assembly_transforms; valida proyección, ruta dentro del módulo y
sweep de la CollisionShape real de Enemy. Un fallo rechaza y reporta el spawn:
no teletransporte, waypoint fuera del mapa ni fallback silencioso.

ContentPatrolResource declara puntos, pausa (1.5s) y giro (100 grados/s).
Enemy recibe Markers top-level antes de _ready, y sus posiciones world quedan
fijadas sin acompañar al cuerpo móvil. La patrulla existente sigue siendo
ida/vuelta; pausa/giro son opcionales, con defaults cero para authored/legacy.
PerceptionTimer sigue funcionando durante movimiento y pausas.

Tipos: CORRIDOR (dos extremos interiores), HUB (dos rutas paralelas separadas),
ACCESS (movimiento y orientación alternada cerca de un acceso). Las parejas
del Hub son grupos atómicos de dos slots dentro del presupuesto, no group aggro.
Perfil exige cobertura ROOM y CIRCULATION. budget_capacity_tag=ROOM conserva
la capacidad de población anterior por seed, aunque redistribuya esos puestos.
Rango 2–4 y pool Carnotauro/Raptor sin retocar; START/EXIT excluidos.
Selección agrupada opt-in uniforme entre grupos elegibles; categorías ajenas y
el selector legacy permanecen intactos cuando priority_slot_tags está vacío.

VarkhemV212ExperienceTest reutiliza Stage6J, CombatUI/RewardUI y el inspector
V211. Conserva vistas, mapa real, zoom/fit, seed/sector; añade INFILTRATION DEBUG
activable con rutas, FOV existente, estados/ownership, distancia, luz real,
último ruido y transiciones observadas/última fuente sensorial. No se inventa
una causalidad nueva para cada transición ni una segunda percepción.
No compactación adicional: se conserva la arquitectura/tamaños V2.1.1.

## Resultados antes del STOP

Godot 4.7.2 Windows. Logs en ../artifacts/varkhem_v2_1_2 (fuera del proyecto).

- Gate físico final 65001–65050: 50 runs / 80 sectores, salida 0.
- 734 aperturas no consumidas selladas/auditadas; cero errores de cápsula,
  floor, containment, seams, overlaps aceptados, navegación o transiciones.
- 80 attempt0; cero backtracks finales; presupuesto 2 intacto.
- Lógico 100 runs /160 sectores, 129 topologías, salida 0; sin cambios al plan.
- Determinismo físico 65001/03/05/15/20 y runtime slots/composición/transforms/
  waypoints: PASS. Se comparan transforms iniciales reportados, no AI ya móvil.
- Población equivalente V211/V212: 222/222 enemigos. Antes: 222 en salas.
  Después: 127 circulación /95 salas; CORRIDOR88, ACCESS126 (incluye salas),
  HUB8 = cuatro parejas. Cero rutas rechazadas en la muestra final.
- Movimiento real durante 14s por seed: 65001/02/03/04/05/15/20, 21 guardias
  con desplazamiento, pausas y cambio de índice; cero stall >2s observado.
- behavior_final.log: visión frontal sí, lateral/trasera no; ruido a3.5m con
  radio WALK3 no / RUN5 sí; ALERT por sonido, retorno PATROL, combate por
  percepción y reset del ownership: PASS, salida0.
- Recorridos reales de Player por main-route, entrada a salas opcionales=0:
  65001: 1 visible /1 oportunidad /1 combatiente, 99.57m, O2 movimiento9.96
  +combate3. 65003: 1/1/1,20.47m,O2 movimiento2.05+combate3. Recorridos ingenuos
  interrumpidos por combate, NO demostración de evitabilidad óptima.
- 6I placement y runtime20/33, 6J playable/reset (asserts antiguos), 6C combat,
  6E statsDNA, canonical speciesDNA,6A2 oxygen: PASS/salida0.
- 5E navegación,5F behavior,5G escape/double/drop,5H authored patrol: PASS/0.
- Ship logical100 y physical SMALL/MEDIUM/LARGE, Horvex logical200/504 y
  physical66001–66003(3runs/8sectores), shared6H grammar: PASS/0.
- Render Compatibility y capturas: salida0. La inspección visual descubrió
  el bloqueo UI descrito abajo, que los asserts antiguos no comprobaban.

## Bloqueo independiente reproducido: UI de combate persiste tras Reset

Diagnóstico idéntico, sin editar la base, en V211 y V212:

initial_ui_visible=false; during_ui_visible=true;
after_reset_combatants=0; after_reset_encounter=false;
after_reset_player_frozen=false; old_enemy_freed=true;
after_reset_ui_visible=true.

Ambas ejecuciones reset_ui_diagnostic.gd devuelven 1 (FAIL).
El diagnóstico está en ../artifacts/varkhem_v2_1_2/reset_ui_diagnostic.gd.

Boundary exacto: Stage6G._clear_runtime_combat_before_regeneration invoca
CombatManager.reset_after_defeat, API documentada para derrota seguida de
recarga de escena. Limpia datos, pero no emite combat_ended. CombatUI permanece
en el mismo árbol y sólo se oculta mediante _on_combat_ended, conectado a esa
señal. Regenerar geometría no recarga ni oculta esa UI. No es causado por las
patrullas: la base limpia muestra exactamente el mismo resultado.

El nuevo gate V212 --inspection incorpora ahora el assert de UI oculta y
devuelve FAIL/salida1 (inspection_reset_ui_failure.log). Los PASS antiguos de
reset demuestran limpieza de ownership, no limpieza visual completa.

Requiere una corrección separadamente autorizada del contrato de cancelación/
reset in-place y notificación a UI, sin simular victoria/recompensas ni cambiar
reglas de combate. NO se aplicó ningún parche a CombatManager/CombatUI.
STOP conforme a AGENTS.md §8: no encadenar un segundo arreglo independiente.

## Otros resultados no certificados / limitaciones

- La prueba ampliada posterior (behavior_loss_final.log) también falla:
  chased=false, lost_and_returned=true, combat=false. El estímulo frontal
  adicional se posiciona respecto de un guardia que ha vuelto a moverse;
  aún NO se validaron soporte/LOS de ese nuevo punto. No atribuir el fallo a
  AI sin diagnóstico. Se conserva la prueba y el fallo, no se elimina.
- Esa última ejecución terminó además 0xC0000005 (-1073741819). Otro smoke
  físico anterior imprimió PASS y terminó con igual código. Ninguna de esas
  ejecuciones cuenta como runtime PASS. Incidencia nativa intermitente ya
  documentada; no investigada ni corregida aquí.
- Dos pruebas aceleradas --fixed-fps60 fallaron en retorno al mezclar tiempo
  simulado y la memoria auditiva de reloj real. Repetición sin aceleración
  behavior_final.log pasó/0. Usar tiempo real para gates sensoriales.
- Hearing no atenúa paredes hoy (_compute_door_attenuation_m retorna0).
  Luz visual y lógica aún no están sincronizadas; no se retocaron.
- STEALTH puede activar la emboscada existente muy cerca de la espalda;
  no confundir ese contrato con detección visual trasera.
- Evitar TODOS los combates con juego cuidadoso, detecciones injustas,
  balance de ventanas, Android y FPS: MANUAL_REQUIRED/no certificado.
- No élite/credencial/misión/extracción V2.2.

## Archivos

Modificados: ContentPlacementProfileResource.gd,ContentSlotDefinitionResource.gd,
VarkhemBase.tres,VarkhemEncounterV1.tres,varkhem_encounter_room.tres,
TestVarkhemBaseSemantic.tres,TestVarkhemLateWing.tres,TestVarkhemSpreadWings.tres,
Enemy.gd,ContentPlacementDirector.gd,ContentPlacementRuntimeConsumer.gd,
Stage6GProceduralPrototype.gd,stage6i_runtime_content_encounter_validation.gd,
varkhem_v2_1_1_validation.gd (hooks de test default-inertes).

Nuevos: ContentPatrolResource.gd,ContentPatrolRoutes.gd,
varkhem_guard_{corridor,access,hub_a,hub_b}.tres,InfiltrationInspection.gd,
VarkhemV212ExperienceTest.tscn,varkhem_v2_1_2_validation.gd/.tscn,este informe y
UIDs de scripts nuevos. Diagnóstico UI/logs/capturas fuera del proyecto.

V211 permanece limpia. official_repo/HorvexV1B3 conserva exactamente su estado
experimental previo; main/Ship/Horvex/combate/ADN/oxígeno no se modificaron.
No cambios a gramática, solver, geometría, navegación, containment o límites.
HEAD sigue en 51efd77; implementación sin commit preservada para revisión.
