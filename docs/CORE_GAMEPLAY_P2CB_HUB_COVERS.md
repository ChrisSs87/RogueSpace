# Varkhem P2-C-B — coberturas tácticas declarativas en hubs

Estado experimental, sin commit; Android pendiente. Base P2-B
`804dfcaf639e4f6ebc9407be7ba0eb9866fb83c3`.
Rama: `feature/varkhem-tactical-hub-cover-p2-c-b`.
Worktree: `core_gameplay_p2cb_worktree`.

## Contrato y alcance

Sólo `RoomEnvironmentProfileResource` opta por candidatos de distribución.
No cambia topología, slots/población, rutas, percepción, LogicalCover, combate,
recompensas, Ship ni Horvex. No coloca props en corredores. Sin configuración,
el builder mantiene el informe y comportamiento legacy. El mismo constructor
de cuerpo/bake/visual sirve a salas y candidatos; no hay otra regla de visión.

Campos nuevos:

- `distribution_cover_candidates`: Array[Dictionary], vacío por defecto.
  Cada entrada: `id`, `semantic`, `role`, `position_fraction` local XZ relativa
  al footprint realmente ensamblado. Coincidencia explícita de semántica y rol.
- `distribution_cover_probability`: 0 por defecto; Varkhem 0.65.
  Es una selección opcional, no una cuota: permite hubs sin muebles incluso
  cuando la geometría admite candidatos. No consume RNG de enemigos/salas.
- `max_covers_per_distribution`: 0 por defecto; Varkhem 1.

Varkhem habilita sólo CENTRAL_HUB/JUNCTION y reutiliza la consola militar
MEDIUM existente (1.8×1.1×0.9 m). No nuevas familias/modelos/materiales globales.
Dos candidatos en el hub actual16×16: centros XZ(-2.75,-2.4)/(+2.75,+2.4),
fracciones(-.171875,-.15)/(.171875,.15). Se selecciona prioridad determinista
y se instancia como máximo uno. La probabilidad/orden deriva de seed efectivo,
stable_id del perfil y node_id, en stream separado; no hay casos por seed.

## Seguridad geométrica

Cada candidato conserva la cruz libre completa de half-width1.8m (incluye
accesos cardinales), wall_margin.35m y reservas de todos los spawns/segmentos
de patrulla declarados, aunque ese slot no sea seleccionado. También se
comprueba el retorno de la ruta y separación de otros candidatos aceptados.
Reserva AABB.grow(.55), radio ya utilizado por el bake. No se rebaja tolerancia.

En16×16: MEDIUM deja |x| mínimo1.85 y |z| mínimo1.95; la caja expandida llega
a |z|3.4, sin invadir las líneas de patrulla |z|3.52. HIGH en la misma franja
alcanzaría3.55 e invade la reserva: no se usa. Las desigualdades se calculan
en runtime con dimensiones reales; no se supone que todos los futuros hubs
tengan la misma geometría. Si falla una condición, se rechaza; no se fuerza.

Un LogicalCover mantiene una BoxShape física y un CSGBox coincidente sin otro
cuerpo, usado por el bake existente. Console añade dos BoxMesh de detalle
dentro del envelope: por hub aceptado, +1 cuerpo/+1 fuente bake/+2 detalles.
No nuevos timers, luces o shaders. NavMesh real se vuelve a bakear, sin tocar
su implementación ni dibujar navegación manual.

## Geometría vs utilidad táctica

El fixture nuevo hereda gates de población, patrol, física, cápsula, suelo,
seams, containment, conectividad/transiciones y presentaciones existentes.
Añade carga efectiva del Resource, presupuesto/evaluación de hubs y probes
negativos de cruz, pared y tamaño HIGH incompatible. LogicalCover se comprueba
también bajo cuatro rotaciones y reflexión (contrato matemático, no otro bake).

Witness de LOS: guardia real del hub, origen ocular real, Player/cápsula/postura
reales, proyección<=.12m, path START↔centro protegido del hub y endpoint físico
sin colisión. Se usa ese punto real de circulación, no un bolsillo seleccionado
sólo porque queda detrás del prop.
Se consulta el raycast de producción sin modificarlo ni inyectar contacto/IA.
Se distingue LOS de pie libre y LOS agachado bloqueada por interposición.
Se registran distancia, FOV del snapshot, rango, postura y guardia;
LOS_WITNESS_PASS exige también alcance y FOV válidos en ese snapshot.

**LOS_WITNESS_PASS no equivale a PASS táctico dinámico.** El snapshot no sigue
todos los guardias durante ciclos completos ni certifica llegada/salida bajo
exposición/ruido. Incluso puede tener FOV:NO en ese instante: se registra,
no se gira el enemigo para fabricar una detección. El resultado dinámico es
**INCOMPLETE**, no una promesa de infiltración perfecta o de evasión justa.

## Observabilidad

`current_room_environment_report.distribution`: hub, candidatos examinados,
posición, geometry_valid, aceptación final, razón de rechazo/omisión/budget,
instanciados y estado táctico INCOMPLETE. Se publica también en el panel
expandible PROFILES existente mediante `get_sector_profile_metrics()`.
El HUD normal no gana texto permanente ni controles nuevos. Los witnesses
sólo viven en resultados del fixture, no ejecutan consultas adicionales cada
frame en juego.

## Comparación dirigida

| Seed/sector | Enemigos antes/después | Props antes→después | Hub MEDIUM local XYZ |
|---|---:|---:|---|
|65001 GROUND|6/6|2→2|ninguno, omisión opcional|
|65002 GROUND|4/4|4→5|(+2.75,.55,+2.4)|
|65003 GROUND|8/8|4→5|(+2.75,.55,+2.4)|
|65003 BASEMENT|8/8|2→2|sin hub semántico|
|65004 GROUND|4/4|2→3|(-2.75,.55,-2.4)|
|65005 GROUND|6/6|4→5|(+2.75,.55,+2.4)|
|65005 UPPER|4/4|2→2|sin hub semántico|
|65006 GROUND|6/6|2→3|(-2.75,.55,-2.4)|
|65006 BASEMENT|6/6|2→2|sin hub semántico|

24→29 props: 12HIGH/17MEDIUM. Cinco de seis hubs con una consola; uno sin
cobertura; tres sectores sin hub conservan sus salas. Ningún enemigo nuevo,
ninguna cobertura antigua desplazada o eliminada.

## Evidencia y comandos

Godot4.7.2 console, headless. Logs separados en
`../artifacts/core_gameplay_p2cb/`; no sobrescriben evidencia P2-B.
`compare_baseline.ps1` compara los nueve sectores con P2-B: payload runtime,
población/asignaciones, módulos, template, semánticas, profundidades, seeds,
retries/backtracks y props legacy; firmas Ship/Horvex aparte.

Prueba dirigida:
`Godot --headless --path . scenes/tests/core_p2cb_hub_cover_validation.tscn -- --from=65001 --to=65006`

Se conservan los ensayos de desarrollo. `hubs.log` no cuenta como validación:
una serialización con comentarios # dejó candidatos sin cargar. Se corrigió
el Resource y se añadió assert para impedir ese falso positivo.
`hubs_configured.log` ensaya candidatos previos; el candidato positivo tocaba
la cruz por redondeo. Los centros finales2.75 dejan margen explícito sin cambiar
la reserva1.8. No se usa el ensayo anterior como certificación final.

## Cierre de validación (2026-10-13)

94 procesos de la batería final con resumen funcional PASS: **88 EXIT_0 /
6 NATIVE_AV / 0 FAIL funcionales**. No son 94 seeds ni aprobación integral.
Importación inicial separada: EXIT_0, sin parse errors; registró el diagnóstico
preexistente Safe save failed, no investigado ni silenciado. Los ensayos de
desarrollo descritos arriba no se suman a estos94.

| Grupo | PASS funcional | EXIT_0 | NATIVE_AV |
|---|---:|---:|---:|
| P1-A lifecycle/reset/ADN con contrato P1-B |26|26|0|
| P1-B abort/idempotencia/ownership |10|7|3|
| P1-C resolución/OMITIR/UI |14|11|3|
| P0 admisión/READY, Varkhen y Horvex |14|14|0|
| Regresiones percepción/patrol/DROP/combate/reset/ADN/O2/runtime |24|24|0|
| Física Varkhem, Ship y Horvex |3|3|0|
| Nuevo gate hubs + perfiles P2-B + observabilidad |3|3|0|

AV registrados, código original -1073741819 (0xC0000005): P1-B abort_repeat,
player_destroyed, ui_destroyed; P1-C skip, abort_choice,
abort_pending_after_skip. Sus resúmenes funcionales terminaron antes del exit
anormal. Sin atribución causal ni nueva investigación; no se normaliza el exit.

`hub_certification.log`: **6 runs /9 sectores PASS geométrico/EXIT_0**;
0 overlaps aceptados, 0 errores de seams, containment, cápsula/suelo,
navegación y transiciones, máximo backtracking0 en la muestra. Cada módulo y
conector activo conserva rutas navegables; el builder runtime valida también
spawns/rutas de todos los guardias seleccionados con cápsula y mapa reales.

Determinismo repetido:65001/65003/65005/65015/65020, cubriendo informe de
colocación/categoría/variante, contenido y NavMesh. El preflight verifica
ambos candidatos geométricamente válidos en los hubs actuales; selección
opcional y presupuesto son motivos separados de rechazo, no fallos geométricos.
Las probes negativas de cruz, pared y HIGH/patrulla, y la compatibilidad MEDIUM
bajo4 rotaciones/reflexión pasan sin reducir reservas.

Los cinco hubs con consola tienen **LOS_WITNESS_PASS**: Player real accesible
en el centro protegido, cápsula sin colisión, path START↔hub, guardia relevante
a≈4.98m con FOV:YES, LOS de pie:YES / agachado:NO e interposición comprobada.
No se modifica posición/orientación/estado del guardia ni se inyecta detección.
**Táctica dinámica: INCOMPLETE**, incluso con estos cinco witnesses positivos;
no se midieron ciclos conjuntos, exposición acumulada, ruido y ventanas de cruce.

Comparación reproducible:0 diferencias no intencionadas en9 sectores.
Población/slots/rutas/payloads runtime y props legacy idénticos. Firmas de
assembly idénticas a P2-B:28 capturas Varkhem,4 Ship,25 Horvex (incluyen
inicializaciones/repeticiones, no son cantidad de seeds independientes).
Ship cubre3 tamaños; Horvex66001–66003 cubre8 sectores y determinismo.
El NavMesh Varkhem sí cambia donde hay nueva consola: es el resultado esperado
del bake físico, no un cambio de generador o de contrato de navegación.

P2-B permanece en804dfca, limpio; main en8bc3e890d5983700db9465fa41c3607cb3b831a9.
2727 archivos del manifiesto de otros worktrees verificados:0 diferencias.
Horvex experimental conserva sus26 entradas de status; Varkhem V2.1.3 sus23;
no reset/clean, commit, ZIP, push o merge. P2-C-B queda con nueve archivos
productivos/tests/documentación modificados o nuevos, sin stage/commit.

### Archivos de la entrega

Producción: RoomEnvironmentProfileResource.gd, VarkhemRoomEnvironment.tres,
RoomEnvironmentBuilder.gd, Stage6GProceduralPrototype.gd (sólo diagnóstico).
Test existente: varkhem_v215_b_environment_validation.gd conserva protección
de módulos; sólo admite distribución explícitamente configurada y aceptada,
MEDIUM, manteniendo excluidos BASE_ACCESS/COMMAND_ROOM.
Nuevos: core_p2cb_hub_cover_validation.gd + .uid + .tscn; este informe.
Scripts/ledgers/logs auxiliares en artifacts/core_gameplay_p2cb, fuera del repo.

## Pendientes / Android

- Utilidad dinámica INCOMPLETE: comparar exposición y acceso al refugio con
  todos los guardias, fases completas, Player real en ambos sentidos y ruido.
- Android: legibilidad de la consola, utilidad del agachado, navegación táctil,
  frame pacing del bake y coste de geometría; no se declara FPS ni aprobación.
- Coberturas de corredor fuera del alcance; no aplicar esta política por arrastre.
- No garantía de que cualquier run pueda completarse evitando todos los combates.
- NATIVE_SHUTDOWN_AV y Safe save failed siguen abiertas; no investigadas aquí.
- Sin commit, ZIP, push o merge. STOP al entregar para revisión.

## Recuperación y TEST MOBILE autorizados posteriormente

El usuario autoriza un commit LOCAL de recuperación de este estado, sin cambios
productivos adicionales. Se verificó ascendencia lineal P0 → P1-B → P1-C →
P2-B; P2-C-B conserva las cinco etapas integradas. Los resultados94/88/6 se
mantienen como evidencia previa, no se repite ni se declara certificación integral.
NATIVE_AV ABIERTO / SAFE SAVE FAILED ABIERTO / ANDROID PENDIENTE.

Paquete autorizado: RogueSpace_CORE_P2CB_TEST_MOBILE.zip en la raíz sincronizada.
Fuente: commit de recuperación; se excluyen informes/caches/Git/worktrees.
Sólo la configuración de entrada del paquete cambia a la escena existente
VarkhemV213ExperienceTest.tscn, que conserva controles táctiles, vistas, mapa,
infiltration debug y PROFILES. No se cambia project.godot del worktree.
El manifiesto del ZIP registra el SHA fuente y esta adaptación de empaquetado.
