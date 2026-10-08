# Varkhem V2.1.1 — distribución, Command y diagnóstico

Base aprobada: `0a350506d6faaafad3bed4cc334eca79ec9e03f7`.
Rama: `feature/varkhem-polish-v2-1-1`.
Worktree independiente: `varkhem_v2_1_1_worktree`.
Estado: funcionalmente validado; pendiente de Android. NO CLOSED/PASS definitivo.
Sin publicación ni merge. V2.1, main y el trabajo Horvex V1B.3 permanecen intactos.

## Estructura real conseguida y límites

Familia B: se añade TEST_VARKHEM_SPREAD_WINGS (distribución repartida, **no alas
de circulación independientes**). Tiene un destino directo del Hub, un destino
en el primer distribuidor elegible intermedio y otro en el último distribuidor
elegible. Los padres son distintos mediante used_parents existente. Las salas
siguen siendo hojas; COMMAND conserva prefer_far/min_depth=4/REQUIRED.
Se mantienen las familias Hub dominante y ala tardía, con pool de tres templates.

El mínimo CORRIDOR pasa del override común de perfil al template: 3 para los dos
templates anteriores (igual comportamiento resuelto que V2.1), 4 para el nuevo.
Así hay dos corredores elegibles después del acceso sin aumentar 13/17/21 nodos.
No cambian grammar/solver ni límites, pesos, footprints, oxígeno o población.
Clearance conserva radio bilateral 3 / máximo 1 turno.

Familia A no implementada: RunDirector._apply_distribution_rule añade sólo hijos
terminales, con una destination_role por regla; no añade alas de circulación.
Las profundidades se calculan antes de aplicar el conjunto de reglas, por lo que
encadenarlas sobre un hijo recién creado no es una solución declarativa válida.

Familia C descartada: RunDirector._build_grammar_plan retorna directamente tras
_apply_distribution_rules. La generación de reconnections queda en la ruta
legacy posterior. Configurar reconexiones en estos templates no crearía un
circuito real. Habilitarlo requeriría revisar integración compartida y presupuesto,
fuera del pulido seguro. El grafo actual sigue siendo un árbol; no se fingen loops.

## Comparación equivalente

100 seeds lógicas 65001–65100, 160 sectores. Comparación física 65001–65050,
50 runs / 80 sectores por versión. La baseline se carga en memoria desde el
worktree V2.1, con sus propios perfiles/templates; no se edita aquella rama.

| Métrica | V2.1 | V2.1.1 |
|---|---:|---:|
| Módulos SMALL/MEDIUM/LARGE | 13/17/21 | 13/17/21 |
| Firmas topológicas, 160 sectores | 127 | 129 |
| Profundidad media de destinos, lógica | 8,01 | 7,77 |
| Profundidad media COMMAND, lógica | 12,71 | 12,75 |
| Rango de profundidad COMMAND | 7–17 | 7–17 |
| Distribuidores/decisiones medios, física | 2,34 | 2,65 |
| START→COMMAND, metros NavMesh medios | 139,48 | 139,92 |
| START→EXIT, metros NavMesh medios | 143,78 | 144,43 |
| Visitar destinos y regresar, árbol estimado (m) | 341,60 | 340,32 |
| Visitar destinos y terminar en EXIT, árbol estimado (m) | 215,88 | 214,17 |
| Tramo máximo sin decisiones por sector, media (m) | 107,45 | 95,47 |
| Mayor tramo sin decisiones de toda la muestra (m) | 167,00 | 163,00 |
| Rectángulo XZ envolvente, área media (m²) | 7.544,27 | 7.231,51 |
| Extensión X/Z media (m) | 87,46 / 86,88 | 84,80 / 86,96 |

La mejora es moderada: -11,1% en tramo medio sin bifurcaciones y -4,1% en área
envolvente media. No desaparece la spine ni se garantiza compacidad en cada seed.
El recorrido óptimo no se acorta significativamente; COMMAND no se adelanta.
Área envolvente no significa superficie caminable. Los itinerarios completos
son sumas de rutas entre centros del árbol, no óptimos continuos dentro de salas.
Los tramos sin decisiones se miden entre nodos de grado distinto de 2, sumando
rutas NavMesh. No se traducen estas distancias a tiempo de juego.

Pool lógico: Hub 56, tardío 50, repartido 54 (160 sectores).
Pool físico: Hub 27, tardío 24, repartido 29 (80 sectores).
Hub grados 3/4: 104/56; distribuidores de corredor con 1/2 destinos: 215/42.
0 ROOM de tránsito, 0 ROOM no terminal, 0 violaciones de clearance.
COMMAND única por run, profundidad preservada y accesible.

## Identidad de COMMAND

SemanticLocationResource.visual_presentation: PackedScene opcional, default null.
Stage6G._attach_semantic_presentations la añade **después de aceptar assembly**,
no durante probes ni selección física. Se resuelve desde la definición semántica
real; no por seed, posición ni nombres accidentales. No duplica la geometría.
Las molduras con metadata connector_side sólo se muestran en bocas realmente
consumidas; no se pinta una falsa entrada sobre la boca sellada de la sala.

VarkhemCommandPresentation.tscn contiene 13 MeshInstance3D (146 triángulos de
primitivas, excluyendo el texto): franjas y dinteles ámbar en W/E, paneles de mando
navy/cian sobre paredes N/S y marca táctica plana central. Label3D COMMAND ROOM /
MILITARY CONTROL. Materiales unshaded compartidos, sin shaders o luces dinámicas.
No añade colisiones, navegación, scripts, obstáculos, mesa invisible ni contenido.
Mantiene centro y accesos libres para futuro combate. El harness verifica el
contrato visual-only y presencia de las 50 COMMAND de la muestra física.
No se afirma rendimiento Android/FPS medido; identidad visual pendiente del usuario.

## Diagnóstico aislado

VarkhemV211ExperienceTest hereda Stage6J con Player, TouchControls, CombatUI y
RewardUI existentes. ProceduralInspection es un observador local y reutilizable
de ese contrato de escena: cámara ortográfica, encuadre de footprints ensamblados,
mapa XZ con enlaces exactos de DungeonPlan.links, colores START/EXIT/COMMAND/
distribuidores/ROOM. No infiere conexión por proximidad ni crea otro plan.

PLAYER VIEW / TOP VIEW / LOGICAL MAP / ZOOM +/- / FIT / NEW SEED / NEXT SECTOR.
ZOOM/FIT afectan tanto cámara superior como escala del mapa lógico.
Seed, effective seed, tamaño, sector, template, attempt, módulos y distribuidores
visibles. El mapa se refresca al regenerar o cambiar de sector. La cámara debug
no mueve ni rota Player; los toggles no alteran oxígeno ni estado de run.
La capa debug queda debajo de CombatUI/RewardUI. Las capas legacy duplicadas se
ocultan localmente por su Label hijo, sin reparar el prototipo compartido.
Los controles debug actúan sobre la escena padre, no dependen de current_scene
ni de scripts/recursos del experimento Horvex.

## Validación Godot 4.7.2 / Windows

- Varkhem lógico 100/100, 160 sectores, determinismo: PASS, salida 0.
- Varkhem físico 50/50, 80 sectores: PASS funcional, repetición final salida 0.
  Incluye 65003, 65015, 65020 y 65043, sin exclusiones.
- 734 aperturas no consumidas auditadas: selladas, cápsula bloqueada.
- 0 errores de overlaps aceptados, seams, floor, containment, nav o transiciones.
- Todos los enlaces reales navegables, START↔EXIT/COMMAND, REQUIRED sin degradar.
- 80 attempt 0, 0 retries, 0 backtracks finales; presupuesto 2 sin cambios.
- 222 Enemy reales, 2–4 por sector, recursos y posiciones nav válidos. No se
  retocó perfil/pool/población. La variación respecto de 223 en V2.1 deriva de
  nodos/slots seleccionados, no de un cambio de reglas de contenido.
- Repeticiones 65001/65003/65005/65015/65020: firmas físicas deterministas.
- V211 inspection: PASS, salida 0. Compara transforms Player/Head y oxígeno antes
  y después de toggles, nodos/aristas reales, zoom, fit, seed y sector, limpieza.
- Player y Enemy reales: 8 cruces físicos de umbrales conectados de salas, PASS.
  El test desactiva sólo callbacks físicos, no cuerpos/colliders, y restaura estado.
  Una primera versión del test usó PROCESS_MODE_DISABLED: Godot retiró los bodies
  del espacio físico (body->get_space null). Se corrigió el test, no el juego.
- Composición V211: Enemy procedural→combat_ready→CombatManager/CombatUI y reset
  con NEW SEED elimina combatantes obsoletos y libera Player, PASS. Es una prueba
  del límite público de integración, no una simulación de percepción/card UI.
- Stage6I content placement + runtime encounters 20 runs: PASS, salida 0.
- Stage6J playable combat/reset: PASS, salida 0.
- Stage6C combat integration + Stage6E stats/DNA: PASS, salida 0.
- Stage6H grammar + physical grammar (5 layouts/cápsula): PASS, salida 0.
- Ship circuits logical (100 runs) + physical SMALL/MEDIUM/LARGE: PASS, salida 0.
- Horvex scale logical (200 runs): tres repeticiones finales salida 0, PASS.
- Horvex physical 66001–66003: 3/3 runs, 8 sectores, 0 fallos y salida 0.
- Carga runtime de escena manual y render Compatibility: salida 0, capturas
  TOP VIEW, LOGICAL MAP y COMMAND inspeccionadas en escritorio.

### Incidencia nativa pendiente — no ocultada

Una ejecución Horvex logical, una Varkhem physical y un smoke debug imprimieron sus
resultados funcionales completos PASS, pero terminaron -1073741819 (0xC0000005).
Es la misma firma de cierre intermitente previamente documentada también en la
base; no se atribuye aquí una causa nueva ni se declara esa ejecución runtime PASS.
Controles en esta tarea: tres ejecuciones Horvex en la base V2.1 y tres en V2.1.1
terminaron 0. La repetición Varkhem 50/50 y el gate final de molduras también
terminaron 0. No se demuestra con ello
ausencia de fallo intermitente. No se corrigió el motor ni se aumentaron límites.
La importación editor salió 0 con aviso Safe save failed de preferencias en el
sandbox, sin errores de parse/Resource. La entrega conserva esta limitación
técnica; no es certificación de estabilidad nativa ni CLOSED/PASS definitivo.

## Archivos y reproducción

Producción localizada: SemanticLocationResource.gd (default visual inerte),
Stage6GProceduralPrototype.gd (hook visual post-assembly), VarkhemBase.tres,
TestVarkhemBaseSemantic.tres, TestVarkhemLateWing.tres y nuevo SpreadWings.tres.
Nuevos: CommandPresentation, escena manual V211, ProceduralInspection,
harness/escena V211 y este informe. El harness V21 obtiene hooks default-inertes
para compartir métricas/auditorías sin duplicar validadores físicos.
RunDirector, solver, navegación, containment, Enemy, combate, ADN, oxígeno,
Ship Resources, Horvex Resources y límites no se modifican.

```text
godot --headless --path . scenes/tests/varkhem_v2_1_1_validation.tscn -- --logical
godot --headless --path . scenes/tests/varkhem_v2_1_1_validation.tscn -- --from=65001 --to=65050
godot --headless --path . scenes/tests/varkhem_v2_1_1_validation.tscn -- --inspection
```

Baseline opcional: añadir `--baseline-root=<worktree V2.1 aprobado>`.
Capturas: sin --headless, añadir `--inspection --screenshots --capture-dir=<dir>`.
Logs/capturas de esta tarea: `../artifacts/varkhem_v2_1_1/` (no incluidos en ZIP).

Paquete: RogueSpace_Varkhem_V2_1_1_TEST_MOBILE.zip en la raíz sincronizada.
Entrada sólo dentro del ZIP: `res://scenes/tests/VarkhemV211ExperienceTest.tscn`.
project.godot del workspace no cambia. Proyecto sin .git/.godot/artifacts/ZIPs.
En Android: abrir/importar, probar seeds sucesivas, alternar vistas/mapa, FIT y
ZOOM, avanzar sector, recorrer COMMAND y completar un combate/reset.
La prueba real de botones táctiles, percepción→combate→recompensa y experiencia
militar sigue siendo MANUAL_REQUIRED. No se declara Android PASS.

## Pendiente V2.2

Misión/élite/credencial/recompensa/extracción no implementados. EXIT no se bloquea.
COMMAND debe vincularse a un objetivo por run/sector/nodo y derrota real del élite,
con finalización y recompensa idempotentes; extracción normal condicionada y
emergencia que conserve recursos. No hay simulación de cumplimiento.
Alas con circulación autónoma o loops necesitarán revisión arquitectónica aparte.
