# Cierre P3 y preparación Varkhem V2.3

Fecha: 2026-10-15. Rama nueva: `feature/varkhem-v2-3`.
Worktree: `C:/Users/chris/OneDrive/Documentos/RogueSpace/varkhem_v2_3_worktree`.
HEAD exacto: `9fb0e12b8bab3ef6ef238c1ee725a9fd7d75e321`.
No se modifica producción. Este informe queda sin commit; no ZIP, merge ni push.

## Base y cierre P3

Ascendencia comprobada mediante `git merge-base --is-ancestor` (todos EXIT_0):
P0 `7c063ec`, P1-B `4110520`, P1-C `e68ca00`, P2-B `804dfca`,
P2-C-B `a110841`, P0-R2 `af78fef`, P2-C-C `8949f44`, P3-B1 `c8f582d`, P3-B1.1 `9fb0e12`.

- P3-B1: Stage6G reutiliza `Stage6GDebugLayer/Stage6GDebug`; InfiltrationInspection
  conserva estados de actores activos y hasta 32 snapshots retirados configurables,
  con contador explícito de truncamiento. No es un replay completo.
- P3-B1.1: ExplorationState limpia registros débiles inválidos al registrar/refrescar
  y mediante callback diferido `tree_exited` ligado sólo a ID. No requiere cambiar
  suspensión; no elimina actores vivos temporalmente separados del árbol.
- P3-B2 permanece en `audit/core-gameplay-navigation-bake-p3-b2`, como auditoría.
- P3-B3 permanece en `experiment/core-gameplay-navmesh-cache-p3-b3`, rechazado.
  Sus archivos no se copiaron. Esta base sigue bakeando navegación; no incorpora caché NavMesh.
- P2-C-F rechazado tampoco se incorpora: esta base desciende del P2-C-C aceptado.

Los contratos anteriores siguen presentes: admisión/READY y posicionamiento
no bloqueante en CombatEncounterManager/Enemy; abort idempotente con sequence ID
en RewardManager; OMITIR y bloqueo de cierre pendiente en RewardUI; perfiles
efectivos en DungeonArchetypeDirector; coberturas de hubs e interiores en
RoomEnvironmentBuilder y VarkhemRoomEnvironment; postura, LOS y reentrada total
frente a DROP parcial en Player/Enemy. Verificación estática y de ascendencia:
no sustituye volver a ejecutar toda la batería de combate/recompensas.

## Integración para V2.3, sin cambios

1. `DungeonArchetypeDirector.resolve_sector_profiles()` resuelve referencias
   explícitas: ambiente de arquetipo con override de sector; contenido de template
   con override de sector y fallback. Los IDs LIGHT/POPULATION históricos son
   etiquetas, no claves del resolver. `population_density` permanece explícitamente
   bloqueada por ausencia de contrato aprobado de presupuesto: no afirmar aplicación.
2. `Stage6GProceduralPrototype` consume el ambiente efectivo y ejecuta
   `RoomEnvironmentBuilder.build()` antes del bake. Publica solicitado/efectivo/aplicado
   en PROFILES. `RoomLogicalLight` registra contribución limitada al footprint de cada
   ubicación admitida; no cambia ambient global ni crea iluminación física.
3. `LightingManager.get_light_level_at()` suma ambient y contribuciones continuas;
   redondea/limita una sola vez a 0–5. Player/HUD y Enemy consultan esta fuente.
4. `Enemy._passes_vision_baseline()` exige alcance/FOV/LOS desde ojo físico a Head.
   LogicalCover aplica HIGH/MEDIUM/LOW y postura por interposición; sólo sus cuerpos
   etiquetados se excluyen del raycast posterior. Paredes conservan bloqueo físico.
5. `_evaluate_vision()` acumula `perception_interval_sec * capability` según
   `EnemyResource.light_detection_curve`, después de baseline válido. Sospecha
   opt-in usa `visual_suspicion_min_capability`; proximidad conserva override existente.
   No se interpreta oscuridad como pared ni STEALTH como invisibilidad.
6. `_on_perception_tick()` separa VISION confirmada, VISUAL_SUSPICION y SOUND.
   Sospecha conduce a ALERT; confirmación a CHASE. ALERT utiliza última observación
   y hasta dos puntos de búsqueda configurados, no posición oculta actual.
   SOUND mantiene la coordenada del evento y su respuesta por especie.
7. P0/P0-R2 revalidan contacto/geometría antes de COMBAT; SOUND solo no habilita
   combate a través de paredes. ExplorationState suspende lógica/timers durante
   posicionamiento, combate y recompensa sin retirar cuerpos físicos.

Datos actuales comprobados: Carnotauro/Raptor 10 m, FOV total 105°, sospecha activada,
umbral 0.1 y dos puntos ALERT. Horvex 11 m/140°, sin copiar ajustes Varkhem.
No se retocaron estos valores.

## Android / Cardboard y límites gráficos

- `project.godot` selecciona renderer **mobile**, no compatibility; no se cambió backend.
  Compatibilidad GPU/driver y exportación requieren dispositivo real, no headless.
- Geometría procedural usa materiales unshaded; las tiras visuales de RoomEnvironmentBuilder
  son BoxMesh unshaded, no luces físicas. La luz lógica NO está sincronizada con
  WorldEnvironment/DirectionalLight. Añadir luces/sombras no cambia automáticamente percepción.
- Mobiliario simple y colisión/LogicalCover son contratos separados. Cualquier mejora visual
  debe conservar footprint, conectores, navegación, presupuesto y volúmenes lógicos.
- TouchControls y selección manual/gaze existen; no hay integración/configuración XR/Cardboard
  real certificada. Preservar cámara libre, sin rotación forzada, y probar input/UI en dispositivo.
- No hay garantía medida de FPS, draw calls, triángulos, memoria GPU ni presupuesto térmico Android.
  Bake de navegación, consultas recurrentes de percepción y overlays requieren medición móvil
  separada. Los tiempos P3-A/B2 de escritorio no son resultados Android.
- Main scene permanece `MainFortress6A.tscn`; no se cambia entrada ni se prepara paquete móvil.

## Evidencia y límites de validación

Godot `4.7.2.stable.official.ed1daf0bf`, Windows headless, APPDATA de tests aislada.
Logs y ledger: `../artifacts/varkhem_v2_3_preparation/`.
Importación de editor EXIT_0; diagnosticó `Safe save failed` preexistente.
Los resultados finales de los tres controles básicos están en `additional_ledger.csv`.
Varkhem: 65001–65006, seis runs/nueve sectores; controles deterministas adicionales
65001/65003/65005/65015/65020. Ship: tres tamaños. Horvex: 66001–66003.
No es certificación integral de gameplay ni aprobación Android.

Resultado final: **3/3 PASS funcional / 3 EXIT_0 / 0 NATIVE_AV / 0 FAIL**.
Varkhem completó nueve sectores y los cinco controles deterministas sin fallos;
Ship completó tres tamaños; Horvex completó tres runs/ocho sectores.
Preservación posterior: **26 otros worktrees y 4071 archivos**, cero diferencias
de HEAD/rama/status y hashes. Main conserva `8bc3e890d5983700db9465fa41c3607cb3b831a9`.
Producción sin diff; único archivo nuevo del worktree: este informe sin commit.

`NATIVE_SHUTDOWN_AV` y `Safe save failed` siguen ABIERTAS y no investigadas.
La ausencia de AV en una batería no demuestra resolución. El estado histórico de
CURRENT contiene hitos antiguos (por ejemplo banda mínima 2 m) superados por
P0-R2; para estos contratos se contrastó código actual y documentación específica,
sin reescribir historia ni modificar CURRENT/main.

STOP: rama preparada; ninguna nueva mecánica u optimización implementada.
