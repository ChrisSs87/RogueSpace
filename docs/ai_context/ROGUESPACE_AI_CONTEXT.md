# ROGUESPACE_AI_CONTEXT

Fecha2026-10-20. Síntesis operativa, no especificación de balance inmutable.
Verificación local:integración31044975 y Horvex V1F.1 6700e93; versiones distintas.
Este documento se publica desde una rama SOLO documental basada en
main8bc3e890d5983700db9465fa41c3607cb3b831a9. No trae código experimental.

## Visión y plataformas

Roguelike espacial/fantasía oscura en primera persona; exploración continua,
sigilo y combate por cartas en el mundo3D. Estética retro económica.
Objetivo PC, Android y Google Cardboard. Nunca rotar/sacudir automáticamente
la cámara para presentar combate. Headless Windows no valida gráficos/input
Android ni comodidad/estereoscopía Cardboard.

Varkhen/Varkhem:instalación militar; Horvex:nido orgánico; Abandoned Ship:dungeon,
no asumir nave-hub persistente terminada. Ruinas SURAAN:templo futuro, diseño
de basalto/calor/trampas/reliquia, no bioma jugable ya construido.

## Arquitectura real en desarrollo

`project.godot` declara10autoloads:GameBalance,EventBus,DebugConfig,LightingManager,
DNAManager,RunState,CombatEncounterManager,CombatManager,RewardManager,
ExplorationState. No hay GameManager/SaveManager productivos asumibles.

|Sistema|Fuentes reales|Contrato|
|---|---|---|
|Planes/sectores|scripts/world/RunDirector.gd,DungeonArchetypeDirector.gd;resources/run|Semántica, módulos, conexiones y seed separados de montaje|
|Montaje/nav|scripts/world/Stage6GProceduralPrototype.gd|Geometría→proxies estáticos→bakeglobal→NavigationRegion/Agent; no ampliar retries para esconder fallos|
|Población|ContentPlacementDirector.gd,ContentPlacementRuntimeConsumer.gd|Slots físicos→selección→Enemy real; alias auxiliares no generan actores|
|Mobiliario|RoomEnvironmentBuilder.gd,LogicalCover.gd|Accesos y nav preservados;HIGH bloquea ambas posturas,MEDIUM agachado,LOW no bloquea visión|
|Iluminación|autoloads/LightingManager.gd;scripts/world/LightSource.gd,BiomeLightingBuilder.gd;resources/lighting|Canónica0–10;adaptador continuo0–5 para detección, no redondeo A4|
|Player|scripts/player/Player.gd|Input PC/táctil,postura/ruido,desplazamiento físico; cámara libre|
|IA|scripts/enemies/Enemy.gd;resources/enemies/EnemyResource.gd|Distancia→FOV→LOS/cobertura→luz→confirmación progresiva|
|Encuentro|autoloads/CombatEncounterManager.gd|Candidatos/APPROACH/READY no equivalen a miembros efectivos|
|Cartas|autoloads/CombatManager.gd;scripts/ui/CombatUI.gd|Máximo2 enemigos;target por índice/ID de lista real _combatants|
|Suspensión|autoloads/ExplorationState.gd|Actores débiles;registros inválidos retirados;ownership de combate/recompensas|
|Recompensas|autoloads/RewardManager.gd;scripts/ui/RewardUI.gd|abort técnico idempotente vs OMITIR paso opcional;efectos confirmados no revierten|
|Estado|autoloads/RunState.gd,DNAManager.gd|RunState en memoria;reset_run no equivale a nueva run completa|

Rutas de clases sin prefijo en la tabla pertenecen a scripts/world salvo indicación.
Confirmar rutas/funciones en el SHA elegido: no copiar managers de otra rama.

## Contratos jugables implementados en integración

- CombatManager.MAX_COMBATANTS_THIS_STAGE=2;Encounter.max_enemies_per_combat=2.
  Incorporación requiere contacto válido y ventana vigente; no agrupar por cercanía.
- C1:Player conserva control durante CHASE/APPROACH;freeze sólo en transición
  válida inmediata a COMBAT. P0-R2 permite posición cercana segura, sin teleport
  ni combate por SOUND solamente/a través de paredes.
- P0 limpieza doble valida referencias liberadas antes de llamadas tipadas.
  ENC DEBUG observa lista real/objetivo/excluidos;READY provisional no es COMBAT.
- Combate usa cartas,stamina,intenciones,selección manual/gaze. Recompensa tras
  TODO el encuentro, no por primera muerte. Emboscadas legítimas conservan bono.
- Visión/audición separadas. Ruido registra su posición del evento, no una
  consulta posterior de la posición oculta. CHASE viaja a LAST_KNOWN y busca.
  Alcance máximo no significa detección inmediata. No retocar Enemy.gd sin alcance.
- Horvex Avispa usa xenomorfo.tres:visión11m en línea actual.18m sigue aparte.
- Luz visual y lógica comparten fuentes en Varkhen;OPERATIVA/REDUCIDA/EMERGENCIA.
  No extrapolar migración completa a Horvex por existir perfiles preparatorios.
- RunState.record_exploration_distance/consume_oxygen:100máximo,0,1/m horizontal
  realmente desplazado;3al combat_ready efectivo, incluso doble;quieto0. No coste
  por carta/turno añadido. O₂cero todavía no derrota en las bases indicadas.
- ADN y bonos viven en DNAManager/RunState;DebugHUD completo limpia ADN,Well lo
  conserva. No reemplazar esas semánticas por reset global indiscriminado.
- abort_reward_sequence(reason,expected_sequence_id) cancela sin aplicar decisiones
  pendientes ni revertir confirmadas. OMITIR resuelve normalmente un paso.

## Existente frente a diseño/pendiente

EXISTENTE:exploración/percepción,cartas,rewards/OMITIR,perfiles/coberturas Varkhen,
geometría orgánica/población/selector Horvex en ramas específicas,diagnósticos.
EXPERIMENTAL:Horvex V1D–F.1,visión18m,C2radio2,0Carnotauro, no aprobados globalmente.
PENDIENTE:Command Room comandante/credencial/misión;presión/dobles Horvex;
derrota por O₂/daño ambiental,guardado general validado;QAAndroid/Cardboard.
DISEÑADO NO IMPLEMENTADO en bases:linternaV01(cono→ALERT,noCHASEautomático),
motioncomics,reliquias/calor/trampasSuraan,Avispa techo/presentación rápida combate.
No confundir los documentos de Gemini/DeepSeek con sistemas existentes.

Experimentos posteriores de esta cola, NO en esas bases ni integrados:
- experiment/oxygen-defeat-v1,75c1148:derrotaO₂runtime y ownership terminal;
  PARTIAL por falta de persistencia a disco. No cambia costes.
- experiment/motion-comics-v1,5a49cbd:visor data-driven aislado y caller local;
  PARTIAL:sin suspensión global narrativa,escenas vistas persistentes oXRvalidado.
- experiment/horvex-ceiling-wasp-v1,ed661c8:subclase opt-in con descenso físico,
  percepciónheredada;no spawnprocedural,rearmeBLOCKEDo validación móvil.
Los tres parten de31044975 independientemente;ninguno heredaF1ni a los otros.

## Trabajo multi-IA

1. Tarea escrita con base SHA exacta, archivos/sistemas permitidos y gates.
2. Una rama/worktree por tarea, un escritor por archivo. No heredar V1F.1 sin
   autorización explícita. Revisores de sólo lectura no integran sus propuestas.
3. Commit local+handoff:diff,comandos,terminales,proceso,riesgos y siguiente paso.
4. V0estático,V1fixture,V2runtime,V3manualPC,V4dispositivo. Registrar PASS/FAIL/
   INCOMPLETE separado de EXIT_0/NATIVE_AV. No declarar trabajo sin evidencia.
5. Integración revisada aparte. Main/protegidas intactas,sin forcepush ni LATEST.

Gemini:según dirección sólo Drive;dar URLs/rutas verificadas y archivos concretos.
Claude/Copilot:acceso GitHub NO asumido;confirmar repo,rama,SHA y código faltante.
DeepSeek:sin persistencia;adjuntar estos MD y los fuentes acotados cada vez.
Codex:inspeccionar y ejecutar pruebas. No es certificación móvil automática.

## Fuentes y precedencia

Dirección autorizada→código del SHA asignado→evidencia→documentos de continuidad.
En desarrollo:AGENTS.md,START_HERE.md,docs/continuity/STATUS.md/ARCHITECTURE.md/
WORKFLOW.md/VALIDATION.md y docs/tasks. CURRENT/CORE históricos contienen números
viejos:0–5cuantizado,APPROACHbloqueante o especies antiguas no deben restaurarse.
En V1F.1:docs/tasks/HORVEX_V1F1_CHECKPOINT.md y docs/evidence/horvex_v1f1/.
Ver inventario y disponibilidad efectiva en [AI_HANDOFF](ROGUESPACE_AI_HANDOFF.md).
