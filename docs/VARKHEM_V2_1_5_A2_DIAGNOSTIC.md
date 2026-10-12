# Varkhem V2.1.5-A.2 — detección y APPROACH

Estado experimental, sin commit. Rama `feature/varkhem-environmental-stealth-v2-1-5`,
HEAD `c79260642ec672beab241489da9262c1e104f4ac`. Se conserva A/A.1.

## Resultado y alcance

No se modifica producción: no se reprodujo un atasco con el guardia móvil
en los dos controles alrededor de LOW. No hay evidencia para cambiar
LogicalCover ni la elección de slots. No se afirma que los controles expliquen
todos los casos Android: se entrega instrumentación para capturar el caso real.

Los siete archivos de producción relevantes (Enemy, Player, LogicalCover,
EnemyResource, ambos Resources Varkhen y CombatEncounterManager) tienen el
mismo SHA256 que sus entradas en el ZIP A.1. Los cambios de producción que
aparecen en git status pertenecen a A/A.1 y no se descartan.

## Detección: condiciones distintas

`Enemy._passes_vision_baseline` comprueba distancia/FOV/LOS. Si falla,
`_evaluate_vision` devuelve NONE y reinicia `_sight_timer`. Si pasa,
acumula `perception_interval_sec * capability`, según luz en Player y
proximity override. Antes de `detection_time_sec` devuelve VISION_ALERT;
al alcanzar el umbral devuelve VISION_CHASE. No hay tirada aleatoria.

En el fixture a 8 m: luz 1/5, capacidad 15%, umbral 1 s equivalente;
necesita aproximadamente 6,67 s de exposición continua, más discretización
del Timer. FOV:YES/LOS:YES no demuestra que el umbral ya se alcanzó.
Moverse fuera del cono o interponer un obstáculo reinicia la racha.

Matriz sostenida, guardia inmóvil y orientado al jugador, percepción normal:

| Cobertura | De pie | Agachado |
| --- | --- | --- |
| HIGH | BLOCK / NONE | BLOCK / NONE |
| MEDIUM | PASS / VISION_CHASE | BLOCK / NONE |
| LOW | PASS / VISION_CHASE | PASS / VISION_CHASE |

Se deshabilita únicamente la transición a combate en esta matriz para no
confundir suspensión del mundo con exposición. Las pruebas APPROACH usan
la transición real. No se fuerza CHASE ni se invoca detección artificial.

Advertencia de contrato existente: `_on_perception_tick` considera contacto
válido también VISION_ALERT y solicita candidatura. APPROACH/COMBAT puede
ocurrir antes de VISION_CHASE. No se usa ese estado como prueba de exposición
confirmada ni se cambia esta regla en A.2.

## APPROACH

La escena A.1 tiene dos modos: COVER deshabilita explícitamente el
`_physics_process` del guardia, conservando su Timer sensorial; CHASE lo
habilita. En COVER se reproduce APPROACH a 7,4 m sin movimiento: es una
condición deliberada del fixture, no evidencia de fallo del navegador.
El tiempo local `_approach_elapsed` no avanza con physics deshabilitado.
El manager sí avanza y cancela limpiamente a los 10 s, quedando sin ownership.
No se atribuye esta explicación al caso Android sin comprobar el modo activo.

En los dos controles móviles LOW, el guardia alcanza COMBAT mediante movimiento
real: distancia final aproximadamente 2,99 m. El control cercano usa Player
z=-5,1 y Enemy z=2,3; el slot viable observado es aproximadamente
(7,165; 0,900; -3,85), con navegación válida. No atraviesa ni desactiva obstáculos.
En el control cercano se enumeran 12 opciones: 2 rechazadas por proyección
de navegación, 3 por LOS desde el slot y 7 válidas. El control móvil lejano
tiene 12/12 opciones válidas; el inmóvil tiene 1 ocupada y 11 válidas.

La elección existente es responsabilidad de `Enemy._compute_slot_target_position`,
no del manager: prueba 12 offsets angulares. `_is_valid_combat_slot` exige mapa
disponible, proyección lateral <=0,12 m, ruta, banda de combate, LOS desde el
slot y clearance de cápsula. El manager asigna participantes/ángulos y resuelve
el timeout. Ya existe búsqueda acotada de alternativas; no se añade otra.

`EnemyResource.combat_approach_timeout_sec=6` no se usa para cancelar en el
código actual. El límite activo es
`CombatEncounterManager.global_encounter_timeout_sec=10`. Es una discrepancia
de configuración documentada, no corregida a ciegas. La cancelación por timeout
y la reentrada posterior se cubren además con las regresiones V2.1.4.1.
No se probó aquí una geometría donde todos los slots sean imposibles.

## Instrumentación nueva, sólo tests

- `scripts/tests/varkhem_v215_a2_validation.gd`: reutiliza el fixture A.1.
- `scenes/tests/varkhem_v215_a2_validation.tscn`: ejecución automática.
- `scenes/tests/VarkhemV215ApproachDiagnostic.tscn`: escena manual móvil.

Comandos, desde este worktree:

```powershell
& 'C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64_console.exe' --headless --path . scenes/tests/varkhem_v215_a2_validation.tscn -- --detection
& 'C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64_console.exe' --headless --path . scenes/tests/varkhem_v215_a2_validation.tscn
& 'C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64_console.exe' --headless --path . scenes/tests/varkhem_v215_a2_validation.tscn -- --near-cover
& 'C:/Users/chris/Downloads/Godot_v4.7.2-stable_win64_console.exe' --headless --path . scenes/tests/varkhem_v215_a2_validation.tscn -- --stationary
```

La escena manual arranca CHASE (PHYS:ON). HIGH/MEDIUM/LOW/OPEN restablecen el
carril. COVER/CHASE alterna el movimiento; DEBUG mantiene compacto/completo/oculto.
Se muestra razón visual, exposición/umbral, luz/capacidad, PHYS, tiempo de
APPROACH/encounter, slot y navegación. El log incluye posiciones, distancias,
contacto y estado. La prueba automática enumera los 12 candidatos, proyección,
ruta, LOS, clearance y colliders de ocupación. Son consultas diagnósticas:
no seleccionan ni confirman colocaciones en producción.

Para un atasco Android pendiente: capturar CHASE/PHYS:ON, STATE, NAV, SLOT,
posición del jugador y guardia, contacto y tiempos antes del timeout. Una
captura aislada FOV/LOS o un guardia COVER/PHYS:OFF no demuestra el defecto.
No se generó un ZIP A.2: el ZIP A.1 anterior no contiene esta instrumentación.

## Regresiones y límites

Batería de 16 ejecuciones: 16 resultados funcionales PASS; 15 EXIT_0,
1 NATIVE_AV (`stage5e_encounter_validation`, -1073741819 / 0xC0000005),
después de imprimir su resumen PASS. No se investiga ni se repite ese cierre.
No hay aprobación integral del proceso ni cierre de NATIVE_SHUTDOWN_AV.

Incluye comportamiento, escape, DROP parcial, cancelación, doble encounter,
combat/reset Stage6J, suspensión, fase A V213, combate 6C, SOUND/VISION,
navegación 5E, patrullas 5H, reentrada normal y SOUND persistente, paredes.
Resultados exactos en `artifacts/varkhem_v2_1_5/a2/ledger.csv`, fuera del proyecto.

Controles dirigidos adicionales, todos PASS / EXIT_0:

| Ejecución | Evidencia |
| --- | --- |
| `--detection` | 6/6 combinaciones, exposición sostenida normal |
| APPROACH móvil | alcanza COMBAT |
| `--near-cover` | alternativas rechazadas/válidas y alcanza COMBAT |
| `--stationary` | reproduce 7,4 m y cancela por timeout global |
| `varkhem_v215_cover_validation` | matriz, campo abierto, paredes, postura, navegación; ALERT visita 2 puntos, recorre 3,47 m y vuelve a PATROL |
| Escena manual, smoke headless | carga el diagnóstico y controles, cierre normal con `--quit-after 180`; no equivale a prueba visual Android |

Los logs definitivos son `verified_*.log`, `cover_alert_full.log` y
`manual_scene_smoke.log`. Un intento previo de launcher construyó mal el
argumento de escena y abrió MainFortress; se interrumpió y no se cuenta como
ejecución de este gate. Se conserva `latest_detection.log` para trazabilidad.
No se cambió producción para resolver ese error de invocación.

Preservación: 0 diferencias SHA256 en los 2.727 archivos del manifiesto de
otros worktrees y 0/554 en el manifiesto V2.1.3. `git diff --check` sin errores
(sólo advertencias de normalización LF/CRLF ya presentes).

Queda pendiente validar el atasco móvil observado por el usuario con la
instrumentación; no se inventa una corrección. Sin cambios de alcance/FOV,
START, población, arquitectura, otros worktrees, commit, push ni merge.
