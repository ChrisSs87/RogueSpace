# Varkhem V2.1 — distribución y preparación de Command

Base: `95734ec61bd868050de187e583e36e21ce92bfe0`.
Rama: `feature/varkhem-distribution-v2-1`.
Estado: validación automatizada satisfactoria; pendiente de Android. Sin merge ni publicación.
Worktree independiente: `varkhem_v2_1_worktree`. El trabajo Horvex sin commit en
`official_repo` permanece intacto y no forma parte de esta entrega.

## Verificación y cambios

La auditoría fue consistente con el código: tamaños 13/17/21, prefijo
CORRIDOR/JUNCTION/CORRIDOR, salas terminales y Hub en profundidad 2. COMMAND ya
era obligatoria, REQUIRED y portaba DUNGEON_OBJECTIVE; no existía una misión que
condicionara EXIT. La transición debug avanza sectores; la finalización actual
no prueba neutralización militar.

No se cambió código de generación. El enum real parent_selection es
SEEDED=0, EARLIEST=1, LATEST=2. Ambos templates usan ahora LATEST para
CORRIDOR_DISTRIBUTION y min_parent_depth=4 (excluye el acceso de profundidad 3).
Los perfiles conservan sus presupuestos; CORRIDOR.min_count sube de 2 a 3 para
garantizar circulación elegible después del prefijo.

- TEST_VARKHEM_BASE_SEMANTIC: dos destinos directos del Hub, uno o dos tardíos.
- TEST_VARKHEM_LATE_WING: un destino directo del Hub y dos tardíos.
- Pool equiprobable existente de dos templates en Ground/Basement/Upper.
- Clearance radius=3/max_turns=1, límites físicos, footprints, contenido y
  población sin cambios. La posición tardía sigue dependiendo de corredores
  elegibles, no de un plano fijo ni de IDs de nodos.
- COMMAND conserva min_depth=4, prefer_far, rama terminal y variante 14x12.
  Se añade display_name y NEUTRALIZE_COMMAND_FUTURE, una etiqueta informativa
  sin consumidor de gameplay. No se declara misión completada ni se bloquea EXIT.

## Comparación reproducible

Godot 4.7.2 stable, headless, Windows. Todas las ejecuciones finales salieron 0.
100 runs lógicas 65001–65100 / 160 sectores, mismas seeds antes/después.

| Métrica | V2 | V2.1 |
|---|---:|---:|
| Planes válidos | 160/160 | 160/160 |
| Módulos SMALL/MEDIUM/LARGE | 13/17/21 | 13/17/21 |
| Firmas topológicas distintas | 126 | 127 |
| Destinos totales de la muestra | 568 | 527 |
| Profundidad media de destinos | 3,73 | 8,01 |
| Profundidad media COMMAND | 4,75 | 12,71 |
| Rango de profundidad COMMAND | 4–8 | 7–17 |
| START→EXIT, aristas lógicas medias | 12,50 | 12,76 |
| START→EXIT, metros NavMesh medios (20 runs) | 142,64 | 147,65 |
| START→COMMAND, metros NavMesh medios (20 runs) | 52,15 | 138,76 |
| Visitar destinos y volver, estimación sobre árbol (m) | 167,64 | 348,67 |
| Visitar destinos y acabar en EXIT, estimación sobre árbol (m) | 222,30 | 218,55 |

El último itinerario puede disminuir aunque COMMAND esté más lejos: recorrer
el árbol hasta EXIT ya pasa junto a las hojas tardías. No son tiempos de juego
ni una optimización continua del recorrido dentro de cada sala. Los itinerarios
de visita suman rutas NavMesh entre centros del árbol lógico; START→EXIT/COMMAND
se miden directamente en NavMesh.

V2.1 destinos por tamaño: profundidad media 5,84 / 7,84 / 10,41.
COMMAND: profundidad media 8,58 / 12,68 / 16,75.
Templates: 86 Hub dominante, 74 ala tardía.
Hub grados: 74 de grado 3 y 86 de grado 4.
Distribuidores: 141 con un destino y 70 con dos.
0 ROOM en spine, 0 ROOM no terminal, 0 violaciones de clearance.
COMMAND única por run: 100/100. Determinismo lógico y semántico PASS.

## Gates físicos e integración

- Control V2: 65001–65020, 20/20, 33 sectores, salida 0.
- V2.1 final: 65001–65050, 50/50, 80 sectores, 1.356 módulos.
- Incluye 65003, 65015, 65020 y 65043; ninguno excluido.
- 80 sectores en attempt 0; 0 retries, 0 backtracks finales.
  Presupuesto backtrack permanece 2. Los probes REQUIRED pueden rechazar
  candidatos antes del assembly final; no se confunden con retries finales.
- 680 aperturas no consumidas auditadas: todas selladas y bloquean cápsula.
- 0 overlaps aceptados, 0 errores seam, floor/collision, containment,
  cápsula, nav o transición; REQUIRED sin degradaciones.
- NavMesh conecta cada arista real, START↔EXIT y START↔COMMAND.
- 223 Enemy reales en 80 sectores, 2–4 por sector y uno por slot seleccionado.
  Resources/posición navegable válidos; no se aumentó la población.
- Assembly medio 52,89 ms; máximo 115 ms. Excluye bake y probes semánticos.
- Repetición de 65001/65003/65005/65015/65020: mismas topologías,
  semánticas, variantes y transforms físicos.
- Stage6K.4 Varkhem V2 logical: PASS (100 runs).
- Stage6I content placement: PASS.
- Stage6I runtime content encounter: PASS (20 runs).
- Stage6J playable combat/reset: PASS.
- Stage6H template grammar: PASS.
- Ship circuits logical: PASS (100 runs).
- Horvex scale logical: PASS (200 runs).
- V21 mobile smoke: PASS, escena real, NEW SEED 65002→65003 y NEXT SECTOR;
  una raíz de módulos y una región de navegación tras transición.
- Carga runtime Godot y scripts nuevos: PASS. La importación editor inicial
  terminó 0 pero avisó que no pudo guardar preferencias del editor en el sandbox;
  no fue un error de parseo/Resource ni afectó los gates runtime.

## Reproducción

Desde el worktree, usar el ejecutable Godot del entorno:

```text
godot --headless --path . scenes/tests/varkhem_v2_1_validation.tscn -- --logical
godot --headless --path . scenes/tests/varkhem_v2_1_validation.tscn -- --from=65001 --to=65050
godot --headless --path . scenes/tests/varkhem_v2_1_validation.tscn -- --mobile-smoke
```

Los logs detallados de esta sesión están fuera del proyecto en
`../artifacts/varkhem_v2_1/`: before_logical, before_physical, after_logical,
after_physical, extended_physical, final_physical, mobile_smoke y regresiones.

## Entrada móvil y límites

`scenes/tests/VarkhemV21ExperienceTest.tscn` hereda Stage6J, inicia Varkhem con
65001 y conserva Player/touch, CombatUI y RewardUI. NEW SEED incrementa seed;
NEXT SECTOR usa la transición existente. Overlay local: tamaño, seed, sector,
effective seed y attempt. No altera project.godot del workspace; el empaquetador
apunta a esta escena solamente dentro del ZIP.

TOP VIEW/LOGICAL MAP no se importan: no existen en la base 95734ec y arrastrarían
trabajo Horvex posterior. No se hicieron cambios globales de debug.
Los destinos siguen siendo opcionales respecto de EXIT; algunos tramos entre
Hub y ala tardía carecen de salas. La experiencia militar y duración requieren
prueba Android. No hay garantía de factibilidad para todas las seeds posibles.
PATROL_PROCEDURAL_GAP/IDLE y max 1 enemigo por slot se conservan.

## Contrato mínimo pendiente para V2.2

Usar COMMAND_ROOM/DUNGEON_OBJECTIVE como identidad, asociada al sector y nodo
del plan de la run. Añadir estado explícito e idempotente de objetivo
pendiente/completado/abandonado, un élite real vinculado a esa identidad y
evidencia de su derrota antes de completar. La extracción normal debe consultar
ese estado; la de emergencia debe preservar recursos/run y renunciar al objetivo
y recompensa. La concesión de recompensa debe ser única. Nada de ello está
implementado ni simulado en V2.1. El tag FUTURE no es una API de misión.

Sistemas protegidos modificados: NINGUNO. Sin solver, navegación, containment,
combate, ADN, Enemy, Ship ni Horvex alterados.
