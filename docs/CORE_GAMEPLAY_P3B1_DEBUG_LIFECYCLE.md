# P3-B1 — Lifecycle de debug entre regeneraciones

Base: `8949f44567c44e03d162650798128ac3f44bcb65`.
Rama: `fix/core-gameplay-debug-lifecycle-p3-b1`.
Worktree: `C:/Users/chris/OneDrive/Documentos/RogueSpace/core_gameplay_p3b1_worktree`.
Estado: cambios locales **sin commit**, Android pendiente. Sin ZIP, push ni merge.
Referencia: auditoría P3-A preservada en su worktree y `../artifacts/core_gameplay_p3a`.

## Causa y ownership

`Stage6GProceduralPrototype._update_debug()` buscaba `Stage6GDebug` en raíz. Lo creaba bajo `Stage6GDebugLayer/Stage6GDebug`. La búsqueda posterior fallaba, por lo que cada llamada agregaba otro CanvasLayer + Label. Se invoca dos veces por generación: cuatro nodos nuevos. El padre Stage los mantiene vivos; no son nodos huérfanos, referencias de singleton ni caché de renderer. ProceduralInspection los oculta, pero ocultar no destruye nodos. La destrucción normal de la escena sí los elimina.

La UI debe vivir durante una escena, NO recrearse por sector. Se corrige el lookup anidado y se reutilizan ambos nodos. Si se elimina su Label, se recrea únicamente ese hijo dentro del mismo layer. No se limpian nodos por coincidencias genéricas de nombre ni se tocan nodos ajenos. No se necesita añadir señales de generación ni modificar su flujo. El botón PROFILES ya tiene creación guardada por su propio layer; su contrato permanece intacto.

`InfiltrationInspection.observed_states` contenía un último estado/transición por instance_id de enemigo, incluyendo IDs de generaciones terminadas. No era un historial completo de eventos. El único consumidor anterior era el propio overlay; P3-A sólo leía su tamaño. No se encontró consumidor de gameplay, persistencia o replay que dependiese de entradas de enemigos destruidos.

Clasificación:

| Elemento | Antes | Después |
|---|---|---|
| Layers/Labels repetidos | Acumulación no intencional de nodos vivos | Un par reutilizable por escena |
| Estados de enemigos retirados | Historial diagnóstico sin límite | Activos + archivo reciente configurable |
| Fuentes de luz, enemigos, agentes | Sin acumulación demostrada | Contratos preservados |
| Memoria de fuentes/fonts/renderer | Puede contener cachés legítimas | No se fuerzan liberaciones globales |
| Reportes del harness | Datos retenidos intencionalmente | Medición adicional con almacenamiento constante |

No se añade un recolector retroactivo para capas de una escena que ya estuviese ejecutándose con el script antiguo: el reinicio normal de escena libera esas capas; instancias nuevas no las duplican. Así se evita borrar UI ajena por heurísticas.

## Historial acotado

- `observed_states`: último estado/transición de cada enemigo actualmente presente; poda cada refresco diagnóstico (~0.2 s), incluso con overlay oculto. No se reduce su información para actores activos.
- `retired_state_history_limit`: export configurable, default **32**; 0 desactiva sólo el archivo retirado. El inspector ofrece rango 0–256. 32 guarda hasta cuatro grupos de ocho guardias, sin convertirse en almacenamiento permanente.
- `retired_state_history`: snapshots retirados, con estado/transición, seed, sector e instance_id. No conserva referencias a nodos.
- `retired_state_history_dropped`: cuenta descartes por truncamiento FIFO. Nunca se presenta el archivo acotado como historial completo.
- `get_debug_history_metrics()`: active/retired/límite/descartados/scope, disponible para auditorías sin texto adicional permanente en HUD.
- Al reemplazarse RuntimeContent se descartan sólo textos/rutas/ruido **del overlay** anterior. No se toca la memoria sensorial de Enemy ni las señales de ruido.

Un replay completo requeriría capturar externamente eventos y muestras durante la sesión; ese sistema no existe en este mapa de últimos estados y no se implementa aquí. Las evidencias previas P3-A no se modifican. Las auditorías pueden consultar/exportar el archivo reciente antes de descartes y deben registrar el contador de truncamiento. No hay borrado de progreso ni datos persistentes.

## Pruebas dirigidas

Godot `4.7.2.stable.official.ed1daf0bf`, Windows headless, misma APPDATA de tests aislada utilizada anteriormente. No representa memoria total/FPS de Android.

`core_p3b1_debug_lifecycle_validation.tscn` usa la escena Varkhem real, sin subclase de Stage ni copia del bake. Player quieto/distante para evitar encuentros durante el test de regeneración. Se esperan 20 ticks después de generación: un refresco completo de overlay de 0.2 s y liberaciones pendientes; no se usa esta espera para medir tiempo hasta jugable.

Antes: ocho regeneraciones equivalentes OFF, ocho ON, seeds 65001–06 con sus nueve sectores y reinicio normal de escena. **28 snapshots, reproducción PASS/EXIT_0**. La primera ejecución tuvo error exclusivamente del parser PowerShell al recortar el prefijo JSON; sus datos/log se preservan como `before_wrapper_error.*`, sin atribuir código Godot desconocido ni contarla como validación integral. Se corrigió sólo el parser y se repitió el control antes de modificar producción.

Después: 50 equivalentes OFF + 50 ON; dos pasadas de seeds 65001–06/nueve sectores; límites de archivo 32/2/0; PROFILES, recreación de Label, conservación de nodo ajeno, TOP/PLAYER/MAP/ZOOM/FIT y reinicio de escena. **122 snapshots, PASS/EXIT_0**. Los límites prueban datos activos conservados y metadatos disponibles en snapshots retirados, además de contador de descartes. Una sola conexión del botón PROFILES.

### Antes/después en 65003 / GROUND_FLOOR

Los conteos de nodos recorren el árbol real, no un monitor retrasado.

| Medida | Antes (8 OFF / 8 ON) | Después (50 OFF / 50 ON) |
|---|---|---|
| Nodos equivalentes OFF | 819 → 847 (+4/regeneración) | 809 → 809 |
| Nodos equivalentes ON | 851 → 879 (+4/regeneración) | 809 → 809 |
| Layers debug OFF | 6 → 20 | 1 → 1 |
| Layers debug ON | 22 → 36 | 1 → 1 |
| Historial ON activo | 8 → 64 (incluía retirados) | 8 → 8 |
| Archivo retirado ON | No separado ni acotado | 0 → 32, luego estable |
| Descartes ON | No disponibles | 360 al final de ese bloque |
| Enemigos / agentes | 8 / 8 estables | 8 / 8 estables |
| Coberturas / luces lógicas | 5 / 5 estables | 5 / 5 estables |
| Conexiones de ruido | 9 estables | 9 estables |
| Resources / huérfanos | 325 / 0 estables | 325 / 0 estables |

Nueve firmas completas seed/sector iguales antes/después: plan, transformaciones, contenido, informe runtime, mobiliario y NavMesh. También se comprueba determinismo dentro de cada ejecución.

Al destruir normalmente la escena: 0 enemigos/agentes/covers/luces lógicas/layers debug, 0 conexiones de ruido, 0 huérfanos. Permanecen 12 nodos del harness/autoloads; no se exige un SceneTree vacío. Una escena nueva recupera el único layer esperado.

### Memoria y sesgos del observador

MEMORY_STATIC es heap reportado por Godot, no PSS/RSS total del proceso, Android o GPU. No se exige descenso inmediato de caches.

| Bloque | Antes, 8 muestras | Después, 50 muestras |
|---|---:|---:|
| OFF | 44.551 → 45.856 MiB | 44.153 → 44.658 MiB |
| ON | 51.189 → 52.466 MiB | 49.827 → 50.421 MiB |

El harness anterior/después conserva snapshots y firmas para auditoría: los bytes no están aislados de su propio almacenamiento. En las últimas ocho muestras después el delta fue 0.071 MiB en ambos modos, frente a ~1.3 MiB en ocho muestras antes. No se atribuye ese residual automáticamente a cachés o al harness: el control de almacenamiento constante siguiente demuestra crecimiento adicional que requiere clasificación separada.

### Combate con inspección activa

`core_p3b1_debug_combat_validation` hereda el fixture de suspensión V214 y conserva todas sus aserciones. Activa solamente el overlay: no modifica IA/percepción ni contratos del padre. Ejercita inicio, cartas/victoria, recompensa, regreso a exploración, derrota, reset y nueva generación.

**PASS/EXIT_0**: 150 ticks con combatientes, 30 de recompensa y 243 de exploración; máximo un layer, ninguna conexión duplicada del observador. Padre: dos inicios, dos finales y una recompensa, sin errores. El tiempo de muestreo no se interpreta como FPS.

## Archivos

Modificados:

- `scripts/world/Stage6GProceduralPrototype.gd`: únicamente `_update_debug`, reuso de layer/Label.
- `scripts/tests/InfiltrationInspection.gd`: lifecycle del overlay e historial acotado; se usa en la escena de experiencia, aunque reside bajo tests.

Nuevos: dos scripts y dos escenas de validación P3-B1, UID generado del fixture lifecycle, este informe. Runners, CSV, JSON y logs: `../artifacts/core_gameplay_p3b1/` fuera del checkout.

No cambios de generación, solver, bake, patrullas, percepción, combate, iluminación, rewards, guardado o recursos de especies. No se modifica ProceduralInspection ni se optimiza su formato/mesh por frame en esta tarea.

## Restricciones y pendientes

Android pendiente. Archivo retirado deliberadamente truncado y no persistente. No se certifica una fuga cero de toda memoria del motor. `NATIVE_SHUTDOWN_AV` y `Safe save failed` siguen abiertos; no investigados. No se declara resuelto el bajón transitorio Android al cambiar seed. P3-A identificó bake/probes como costes separados: no intervenidos aquí.

## Control de almacenamiento constante: problema independiente abierto

`--stream-memory`: seis regeneraciones de calentamiento del archivo reciente y 32 muestras equivalentes 65003/GROUND_FLOOR, debug ON. Cada muestra se escribe a JSONL sin añadirla al array del harness. Sólo se mantienen primer/último conteo y agregados; no logging por frame. **PASS funcional / EXIT_0** para sus asserts de cardinalidad y límites; NO es un assert de memoria cero.

- Nodos: 809 → 809.
- Enemigos/agentes: 8/8 estables; covers/luces: 5/5; layer debug: 1; señales: 9; Resources: 325; huérfanos: 0.
- Historial: 8 activos + 32 retirados, estable.
- MEMORY_STATIC: **49.394 → 49.673 MiB**, +291976 bytes en 32 regeneraciones posteriores al conteo inicial. Últimas ocho muestras: +67552 bytes.
- OBJECT_COUNT: **3656 → 3912**, +256 objetos = ocho por regeneración.

Esto descarta que TODO el crecimiento residual proceda de guardar snapshots. No son nuevos nodos ni Resources según los contadores. No se identifica cada clase nativa de los 256 objetos; no se atribuye la totalidad de bytes a un único propietario sólo por correlación.

Inspección de código identifica un mecanismo adicional preexistente en **autoloads/ExplorationState.gd**, idéntico a la base:

1. `Enemy._ready()` llama `ExplorationState.register_actor(self)`.
2. `register_actor()` agrega por instance_id un Dictionary con `WeakRef`, since y timers a `_actors`.
3. No hay unregister al retirar Enemy.
4. `reset_for_regeneration()` llama `_refresh()` con flags inactivos.
5. `_refresh()` retorna inmediatamente si `_suspended` no cambia; la poda de WeakRefs muertos está DESPUÉS de ese retorno.

Por tanto, regenerar sin transiciones de suspensión permite acumular registros de actores retirados en un singleton. Los WeakRefs NO mantienen vivos a Enemy ni sus cuerpos: por eso los conteos de escena permanecen correctos. El mecanismo de retención está demostrado por el código y concuerda con +8 objetos por regeneración; falta instrumentar el tamaño/clases de ese registro para atribuir exactamente todo el residual. Una transición real de suspensión puede podarlo, pero no convierte en acotado el caso de regeneraciones repetidas sin combate.

**STOP de ampliación. No se modifica ExplorationState, Enemy ni suspensión de combate.** Es un propietario compartido distinto de los dos defectos de debug autorizados; no se encadena una reparación nueva. No se vincula este hallazgo a NATIVE_SHUTDOWN_AV.

Propuesta mínima para una autorización posterior: podar entradas cuyo `WeakRef.get_ref()` sea null durante registro/reset, independientemente de que cambie la suspensión; conservar todos los actores vivos, flags, timers, callbacks y reglas de COMBAT. Validar registro vivo/retirado explícitamente, 100 regeneraciones con almacenamiento constante, destrucción de escena, posicionamiento, victoria/derrota/recompensas y ausencia de señales duplicadas. El orden exacto de destrucción/reset y la limpieza al salir de escena deben verificarse antes de implementar.

Clasificación final: **lifecycle debug PASS funcional; estabilización total de objetos/memoria INCOMPLETE** por este mecanismo independiente. No se promete memoria plana del proceso ni se oculta el residual.

## Regresiones finales

69 regresiones compartidas: **69 PASS funcionales, 65 EXIT_0, 4 NATIVE_AV**, cero FAIL funcionales y cero INCOMPLETE de ejecución en esa batería.

| Grupo | Casos |
|---|---:|
| P0-R2 Varkhem/Horvex | 11 |
| P1-B abort/lifecycle | 10 |
| P1-C resolución/OMITIR | 14 |
| Física Varkhem/Ship/Horvex | 3 |
| P2 perfiles/hubs | 3 |
| P2-C-C habitaciones/configuración/inspection | 4 |
| Compartidos: navegación, percepción, DROP, combate/reset, ADN, oxígeno | 24 |

NATIVE_AV (-1073741819 / 0xC0000005) después de resultados funcionales en `abort_repeat`, `scene_change`, `close_races`, `abort_after_skip`. No investigados ni tratados como EXIT_0. Se conserva `all_ledger.csv` y cada log.

Controles propios: reproducción baseline, 100 regeneraciones/122 snapshots, combate con overlay y streaming de memoria: cuatro ejecuciones **PASS/EXIT_0** para sus aserciones declaradas. Total contabilizado: **73 PASS funcionales, 69 EXIT_0, 4 NATIVE_AV**. El positivo baseline prueba el defecto anterior, no aprobación del código anterior. El criterio funcional de streaming sólo cubre lo afirmado arriba; el crecimiento de memoria se registra aparte como pendiente, no se convierte en PASS de memoria plana.

La carga inicial de editor terminó EXIT_0. No se modificó ni relajó ninguna aserción de la batería existente. La ejecución inicial con fallo del parser del runner queda fuera de estos conteos; evidencias preservadas. El script de preservación inicialmente incluyó por error el worktree propio al comparar separadores Windows; al normalizar rutas, el único cambio esperado era P3-B1. No hubo cambios de otros worktrees.

## Preservación y entrega

HEAD continúa en `8949f44567c44e03d162650798128ac3f44bcb65`. Main continúa en `8bc3e890d5983700db9465fa41c3607cb3b831a9`. `git diff --check` sin errores. Los **otros 22 worktrees** mantienen HEAD/rama/status; **2736 archivos** controlados mantienen SHA256, incluidos los cambios no commiteados de P3-A/Horvex/Varkhem y ambos ZIP anteriores. `preserve.ps1 -Mode after`: cero diferencias de estado y cero diferencias de archivos.

ZIP P2-C-C preservado: SHA256 `034576E00D2FD1A3D65968F1B2C05FC39A7A5444C512A391B73FC00ABFE29214`.
ZIP P0-R2 preservado: SHA256 `265E79BF8DE384E9759BED8DFEF4B5EC1D04CB542F9D228A115FA67D9C61381B`.

Riesgos: truncamiento deliberado del archivo retirado; validación visual Android pendiente; retención adicional del registro compartido de actores pendiente de autorización; incidencia nativa y Safe save failed abiertas. El debug se valida funcionalmente en escritorio, no como mejora demostrada de FPS Android.

**STOP. Cambios sin commit para revisión. No ZIP, push, merge ni modificaciones adicionales.**
