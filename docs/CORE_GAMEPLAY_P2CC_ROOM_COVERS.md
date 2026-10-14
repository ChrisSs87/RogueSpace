# Varkhem P2-C-C — coberturas tácticas declarativas en habitaciones

## Estado y seguridad

Rama `feature/varkhem-tactical-room-cover-p2-c-c`.
Worktree `C:/Users/chris/OneDrive/Documentos/RogueSpace/core_gameplay_p2cc_worktree`.
Base/HEAD `af78fef28d0ea928d22a165136f806867540fcee`.
Cambios SIN COMMIT; sin ZIP/push/merge. ANDROID PENDIENTE.
Geometría y regresiones: PASS FUNCIONAL. Utilidad dinámica: INCOMPLETE.
NATIVE_SHUTDOWN_AV y Safe save failed permanecen abiertos, no investigados.

AGENTS.md, CURRENT State, contrato de diseño/percepción y auditoría íntegra
`core_gameplay_p2ca_worktree/docs/CORE_GAMEPLAY_P2CA_TACTICAL_AUDIT.md` revisados.
P0-R2 limpio en su worktree, commit intacto; main sigue8bc3e89.
2727 archivos del manifiesto de otros worktrees:0 diferencias.
ZIP P0-R2 preservado, SHA256:
`265E79BF8DE384E9759BED8DFEF4B5EC1D04CB542F9D228A115FA67D9C61381B`.

## 1. Causa anterior y alcance

El builder elegía categorías/variantes por seed, pero colocaba siempre en
localX=+.32×ancho y Z=±.32×profundidad. Protegía cruz/patrullas, no evaluaba
bolsillos interiores. BARRACKS, ARMORY y FOOD_STORAGE ya eran los únicos
destinos compatibles. PRIVATE/PRISON/COMMAND/START y corredores no se habilitan.
Los Hubs conservan íntegramente P2-C-B.

La cruz protegida1.8m se mantiene. Por eso esta entrega NO pretende ocultar
todo el eje central: mejora bolsillos/recorridos laterales de aproximación.
No agrega rutas lógicas alternativas ni modifica conectividad.

## 2. Estrategia final: redistribuir, no sumar

`RoomEnvironmentProfileResource.room_cover_candidates` es opt-in, default[]:
diccionarios con id/semantic/position_fraction y category/index opcionales.
`index` refiere a uno de los slots de mobiliario existentes, no a un nodo
procedural ni a una seed. Se conserva el presupuesto máximo2 por habitación,
las categorías originales y la selección de variantes/RNG anterior.

El Resource Varkhem declara6 alternativas: norte/sur de tres semánticas,
exclusivamente MEDIUM. Sólo se aplica la correspondiente al índice/categoría
del objeto que ya se iba a colocar. HIGH permanece exactamente en baseline.
No nueva familia visual, collider, shader, luz ni enemigo.

| Semántica | Footprint actual | MEDIUM interior localXZ | Baseline localXZ |
|---|---|---|---|
| BARRACKS |14×10|(+2.8,±2.45)|(+4.48,±3.2)|
| ARMORY |10×10|(+2.75,±2.45)|(+3.2,±3.2)|
| FOOD_STORAGE |10×8|(+2.75,±2.45)|(+3.2,±2.56)|

Fracciones respectivas(.2,±.245),(.275,±.245),(.275,±.30625), aplicadas al
footprint real. No coordenadas globales ni dependencia de orientación/seed.
No garantiza aceptación en una variante más pequeña: se vuelve a validar.
Si ningún candidato es seguro, se conserva fallback lateral, sujeto a seguridad;
si tampoco cabe, se omite con motivo explícito, nunca se fuerza colocación.

El stream local de candidatos está separado de la selección de categorías,
variantes, hubs, población y topología. Igual seed/configuración: mismo resultado.
La variación entre salas sigue proviniendo de semánticas, dimensiones, presencia
opcional y categorías/modelos seedados; no se amueblan automáticamente31 destinos.

## 3. Geometría, circulación y accesibilidad

Se reutiliza `_distribution_rejection` sin cambiar sus reglas:
cruz1.8m, margen pared.35m, reserva de spawns/patrullas expandida.55m.
Se comprueban todos los slots y segmentos declarados, no sólo enemigos elegidos.
Se agrega rechazo de intersección con otra reserva de prop aceptado.
Todos los objetos conservan su único cuerpo/BoxShape y CSG correspondiente al bake.

Después del bake, `room_access_positions` es diagnóstico de sólo lectura:
cuatro bolsillos acotados alrededor del mueble, proyección lateral≤.12m,
contención y ruta ida/vuelta desde el centro de sala, barridos con la cápsula
real de Player. Usa reservas/buffer existentes(.55m/.04m), sin cambiar solver,
bake, radios, tolerancias ni límites. No evalúa ocupación por guardias dinámicos.
Los gates existentes verifican además centro/conectores reales, patrullas,
seams, containment, suelo, cápsula, transiciones y spawns navegables.

## 4. Comparación reproducible con P0-R2

Mismo fixture con `--legacy` vacía sólo los candidatos nuevos en una copia del
perfil. Se verificó contra los nueve payloads originales de P0-R2: mismos
props/modelos/categorías/posiciones baseline, no una aproximación inventada.
Después se compara el perfil actual con ese control.

`artifacts/core_gameplay_p2cc/compare_rooms.ps1` verifica:
nodes/size/template/semánticas/profundidades/seed/retry/backtracks/population/runtime
idénticos, incluidas posiciones de spawn y rutas.28 firmas completas de assembly
Varkhem idénticas. Hubs/distribution y luces idénticos. HIGH y muebles de hubs
conservan todas sus posiciones. Sólo se reubican12 MEDIUM de habitación.

### Nueve sectores; A=posiciones accesibles, L=interposición LOS, F=LOS+FOV

| Seed/sector | Enemigos antes/después | Muebles sala | Interior antes→después | A antes→después | L antes→después | F antes→después |
|---|---:|---:|---:|---:|---:|---:|
|65001 GROUND_FLOOR|6/6|2|0→1|7→7|0→0|0→0|
|65002 GROUND_FLOOR|4/4|4|0→2|12→13|2→3|0→1|
|65003 GROUND_FLOOR|8/8|4|0→2|12→13|2→3|0→1|
|65003 BASEMENT|8/8|2|0→1|7→7|2→3|0→1|
|65004 GROUND_FLOOR|4/4|2|0→1|7→7|0→0|0→0|
|65005 GROUND_FLOOR|6/6|4|0→2|12→13|2→3|0→1|
|65005 UPPER_FLOOR|4/4|2|0→1|7→7|2→3|0→1|
|65006 GROUND_FLOOR|6/6|2|0→1|7→7|0→0|0→0|
|65006 BASEMENT|6/6|2|0→1|7→7|0→0|0→0|

| Métrica | Antes | Después |
|---|---:|---:|
| Destinos presentes |31|31|
| Habitaciones elegibles evaluadas |12|12|
| Habitaciones con mobiliario |12|12|
| Objetos sala |24|24|
| Objetos hub |5|5|
| Objetos totales |29|29|
| Coberturas interiores sala |0|12|
| Coberturas laterales sala |24|12|
| Props LOW/decorativos |0|0|
| Bolsillos examinados (4 por prop sala) |96|96|
| Posiciones accesibles |78|81|
| Posiciones con interposición LOS/rango |10|15|
| Posiciones con interposición LOS/rango/FOV muestreado |0|5|
| Problemas de navegación finales |0|0|

Rechazos geométricos de candidatos finales:0 en la muestra; los probes negativos
de eje se rechazan explícitamente en los24 props. Bolsillos no accesibles18→15
no equivalen a fallos de colocación: se registran como opciones rechazadas.
Los19 destinos no compatibles no reciben muebles nuevos. La muestra tiene
9 BARRACKS y3 ARMORY; no contiene FOOD_STORAGE.

FOOD_STORAGE se validó aparte con su ModuleDefinition real `base_food_storage`
10×8, slots, factory de módulos/covers y bake B+C existentes. Dos props,
MEDIUM interior/HIGH lateral; ambos tienen acceso válido y están representados
en el bake. No es una generación procedural ni una prueba táctica con guardias.
Una búsqueda lógica65007–65100 no encontró FOOD; no se cambia su selección ni se
concluye que esa semántica nunca pueda generarse. Resultado de esa búsqueda:
INCOMPLETE para obtener un caso procedural FOOD, no defecto de gameplay.

## 5. Qué se demuestra tácticamente

Para cada bolsillo accesible se usan guardias reales, Resources y rutas reales,
muestreando extremos/mitades en ambos sentidos de cada segmento. Se comprueban
alcance, LOS de paredes, interposición, postura y FOV de marcha. No se usa una
única posición instantánea como aprobación. Los raycasts de control sin props
pertenecen exclusivamente al fixture; no se cambia ninguna máscara productiva.

Los5 nuevos testigos F son bolsillos accesibles en5 habitaciones, con reducción
de LOS según categoría/postura frente a esas fases geométricas. Se demuestra
una mejora de distribución/interposición, NO sólo más muebles.
No se mide duración de exposición, ruido, giro/pausa de todo un ciclo, cruce
real temporizado ni ocupación dinámica conjunta. **Utilidad dinámica INCOMPLETE**,
también para salas sin guardia relevante en la muestra. No se etiquetan esos
props como inútiles/decorativos sin prueba; funcional lógico≠evasión certificada.
No garantía de infiltración perfecta ni de completar una seed sin combatir.

## 6. Experimentos rechazados, sin ocultarlos

- Primer ensayo de configuración: los comentarios añadidos al .tres hicieron
  que `room_cover_candidates` se cargara vacío. El ensayo físico conservó layout
  legacy; NO se cuenta como implementación exitosa. Se corrigió la serialización
  y se agregó gate de carga directa/duplicate/default inerte.
- El primer gate de configuración tuvo un parse error de inferencia del fixture;
  se interrumpió esa ejecución sin test activo. No se atribuye a producción/AV.
- Primer candidato interior de ambas categorías:65003 GROUND falló en un HIGH
  de ARMORY. La consulta de bake devolvía un punto bajo el prop, violando la
  aserción existente; dos mensajes provienen del bucle repetido del mismo cover.
  Se retiró HIGH del subconjunto interior. No se cambia el assert, motor, collider,
  radio o bake. No se afirma una causa nativa/general del problema.
  `rooms_final.log` conserva ese FAIL; `rooms_medium.log` contiene el gate final.
- La corrección acotada mantiene HIGH exactamente en baseline y conserva
  categorías/presupuesto. No cadena de hacks ni segundo ajuste de navegación.

## 7. Validaciones finales

`artifacts/core_gameplay_p2cc/final_gate_ledger.csv` enumera126 ejecuciones
seleccionadas (no126 asserts):121 PASS/EXIT_0 y5 PASS/NATIVE_AV;0 FAIL final.
Los intentos históricos fallidos anteriores no se reclasifican como PASS.

| Grupo | PASS funcional | EXIT_0 | NATIVE_AV |
|---|---:|---:|---:|
| P0-R2 Varkhem/Horvex |27|27|0|
| P0 Varkhem/Horvex |14|14|0|
| Compartidas Stage5/percepción/covers/APPROACH/CHASE/DROP/reentrada/suspensión/combate/reset/ambush/ADN/O2 |24|24|0|
| P1 reset/lifecycle/ADN |26|26|0|
| P1-B |10|7|3|
| P1-C/OMITIR |14|12|2|
| Física Varkhem/Ship/Horvex |3|3|0|
| P2-B/P2-C-B |3|3|0|
| Nuevos: perfil actual, legacy, carga Resource, inspección, FOOD aislado |5|5|0|
| TOTAL |126|121|5|

AV -1073741819/0xC0000005 después de resumen PASS: P1-B finish_after_abort,
abort_after_finish,player_destroyed; P1-C skip_all,abort_choice. Causa no atribuida.
**PASS FUNCIONAL / NATIVE_SHUTDOWN_AV ABIERTO**, no certificación integral.

Actual/legacy:6 runs/9 sectores cada uno PASS/EXIT_0. Determinismo de covers,
luces, navegación y contenido repetido65001/65003/65005/65015/65020.
Ship3 tamaños y Horvex66001–66003/8 sectores: PASS/EXIT_0;4 y25 firmas físicas
respectivas idénticas a P0-R2. No se incorporó el experimento Horvex.
Editor EXIT_0 con Safe save failed preexistente; configuración e inspección EXIT_0.
Los controles existentes no se editaron ni se relajaron asserts.

## 8. Observabilidad y archivos

PROFILES conserva su panel expandible/desplazable, sin HUD/panel nuevo:
room_cover_candidates expone habitación/semántica, presupuesto, candidatos,
rechazos/motivos, posición, interior/lateral, funcional/decorativo y accesibilidad
estática por prop/categoría. LOS/postura y táctica dinámica indican INCOMPLETE
cuando no se han ejecutado controles correspondientes; el log del fixture tiene
los testigos multisample detallados. No resultados dinámicos inventados en UI.

Producción modificada, exclusivamente:

- resources/run/RoomEnvironmentProfileResource.gd: schema opt-in inerte.
- resources/run/VarkhemRoomEnvironment.tres:6 candidatos MEDIUM declarativos.
- scripts/world/RoomEnvironmentBuilder.gd: alternativas seguras, fallback,
  reservas entre props, auditoría y diagnóstico estático read-only.
- scripts/world/Stage6GProceduralPrototype.gd: sólo exposición de esos datos en
  get_sector_profile_metrics/PROFILES, sin modificar generación/bake/solver.

Nuevos: scripts/tests/core_p2cc_room_cover_validation.gd/.uid,
scenes/tests/core_p2cc_room_cover_validation.tscn y este informe.
Artefactos de evidencia fuera del worktree: comparison.csv, compare_rooms.ps1,
summarize_gates.ps1, ledgers y logs en artifacts/core_gameplay_p2cc.

Comandos Godot sobre la escena nueva:
`-- --from=65001 --to=65006`; control `-- --legacy --from=65001 --to=65006`;
`-- --configuration`; `-- --inspection`; `-- --food-fixture`.
`-- --find-food` es búsqueda diagnóstica acotada, no gate funcional de generación.

## 9. Riesgos y STOP

- Android y valor experiencial pendientes; sin ZIP autorizado todavía.
- Mismos29 props/modelos en la muestra no garantizan mismos FPS: cambian
  visibilidad/culling y triangulación de navegación. No benchmark móvil realizado.
- Diagnóstico de acceso hace consultas acotadas al leer PROFILES/generar el
  resumen, no nuevo sistema permanente de búsqueda táctica por frame.
- HIGH interior no certificado; FOOD sólo módulo aislado, sin caso procedural
  en la muestra. No se amplía distribución/topología para forzar esos casos.
- Cruz central sigue despejada/expuesta. No se convirtió Varkhem en laberinto,
  no nuevos enemigos, recompensas, luces, senses, obstáculos de corredor ni IA.
- Funcionalidad lógica/cápsula/LOS estática no sustituye prueba de evasión real.
- Main/otros worktrees/ZIP P0-R2 intactos; sin stage/commit/push/merge.

STOP, listo para revisión del diff, no CLOSED/PASS experiencial.
