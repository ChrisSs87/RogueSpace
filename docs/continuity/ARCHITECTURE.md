# Mapa de arquitectura — base B+C1

Mapa orientativo verificado por rutas/autoloads y contratos actuales; no nueva
auditoría ni garantía de todas las capacidades. Consultar informes de STATUS.

| Responsabilidad | Fuente/consumidor | Contrato a preservar |
|---|---|---|
| Composición | scripts/world/Stage6GProceduralPrototype.gd; escenas/tests/Stage6JArchetypePrototype.tscn | Prototipo de ensamblaje/sectores, no misión final |
| Plan lógico | resources/run; RunDirector, DungeonArchetypeDirector, DungeonPlan | Semántica/gramática separadas de geometría |
| Assembly/nav | scripts/world; módulos/CSG → proxies → bake → región/agentes | Footprints, seams, containment; no límites relajados |
| Contenido | ContentPlacementDirector, perfiles y consumidores runtime | Configurado ≠ resuelto ≠ instanciado; density no implica cuota absoluta |
| Ambiente/muebles | RoomEnvironmentBuilder; RoomEnvironmentProfileResource | Reservas, accesos, navegación, presupuestos deterministas |
| Luz | LightingManager; BiomeLightingBuilder; resources/lighting | Fuentes declaradas → exposición0–10 → detección continua0–5; variantes permitidas |
| Movimiento/postura | scripts/player/Player.gd | STEALTH agacha, ruido independiente; cámara nunca girada por combate |
| Percepción/búsqueda | scripts/enemies/Enemy.gd; EnemyResource | FOV/LOS/cobertura, confirmación gradual; sonido separado; LAST_KNOWN no omnisciencia |
| Cobertura | scripts/world/LogicalCover.gd | HIGH ambos, MEDIUM agachado, LOW nunca; interposición real |
| Candidatura/READY | autoloads/CombatEncounterManager.gd + Enemy | Contacto confirmado y posición válida; no bloqueo durante APPROACH C1 |
| Combate/cartas | autoloads/CombatManager.gd + CombatUI | Máximo actual2 participantes, señales/bonus únicos, no teleport |
| Suspensión | autoloads/ExplorationState.gd + actores | Suspensión lógica, cuerpos registrados; ownership combat/reward; no pausa indiscriminada |
| Recompensas | RewardManager + RewardUI + DNAManager/RunState | Abort idempotente técnico; OMITIR resuelve un paso; efectos confirmados permanecen |
| Run/ADN/O2 | RunState/DNAManager; GameBalance | Reset_run no equivale a nueva run; no asumir guardado a disco |
| Depuración | DebugHUD, ProceduralInspection, InfiltrationInspection | TOP/PLAYER/MAP/PROFILES; lifecycle sin acumulación |

`project.godot` declara10 autoloads: GameBalance, EventBus, DebugConfig,
LightingManager, DNAManager, RunState, CombatEncounterManager, CombatManager,
RewardManager, ExplorationState. No asumir un GameManager inexistente.

Flujo vivo resumido:

`percepción → candidatura → APPROACH libre → posición/contacto finales válidos
→ combat_ready → CombatManager/ExplorationState → recompensa → resolución/abort
→ recuperación de exploración`.

SOUND puede investigar y abrir candidatura, pero no sustituye visión confirmada
para COMBAT ordinario. Emboscada legítima conserva su excepción declarada y
stamina, no excepción a obstáculos. DROP parcial y cancelación total son distintos.

Pruebas: scenes/tests y scripts/tests. Entrada manual Varkhem:
`scenes/tests/VarkhemV213ExperienceTest.tscn`. El proyecto base sigue abriendo
MainFortress6A; paquetes móviles anteriores cambian entrada sólo en su ZIP.
No modificar project.godot para una auditoría sin necesidad/autorización.

## Extensiones todavía propuestas

Narrativa/video/motion comics: diseño en auditoría Phase1 local, no reproductor
terminado. Requiere owner/cierre idempotente, suspensión propia, omisión,
retorno sin reconstruir escena, política visto/omitido y persistencia explícita.
No copiar un reset global para implementar narrativa. Formatos/capacidad se
deben volver a verificar en el ejecutable/dispositivo seleccionado antes de construir.

Abandoned Ship no es la nave-hub persistente; Command Room no implementa todavía
élite/credencial/recompensa de misión/extracción. Horvex/Nythari preparatorios
de luz no equivalen a migración completa de biomas productivos.
