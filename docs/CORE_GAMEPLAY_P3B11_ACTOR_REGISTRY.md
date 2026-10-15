# P3-B1.1 — ExplorationState actor registry lifecycle

## Recuperación y aislamiento

P3-B1 recuperada localmente en **c8f582d042f354db9c0411a3fe7dc799c2548c44**, rama `fix/core-gameplay-debug-lifecycle-p3-b1`. Incluye sus ocho archivos revisados: corrección UI Stage, archivo reciente de infiltración, dos fixtures/escenas, UID del fixture lifecycle e informe. No se cambió su implementación para recuperarla; su worktree queda limpio.

P3-B1.1: rama `fix/core-gameplay-actor-registry-p3-b1-1`, worktree `C:/Users/chris/OneDrive/Documentos/RogueSpace/core_gameplay_p3b11_worktree`, desde ese commit. Cambios SIN COMMIT. Main y otros worktrees preservados. Android pendiente; sin ZIP/push/merge.

## Causa reproducida

Enemy._ready registra cada enemigo en ExplorationState; el coordinador CombatEncounterManager se registra al iniciar. El singleton guarda Dictionary por instance_id, con WeakRef al actor y datos de timers/pausa. Los WeakRefs NO mantienen vivos nodos ni cuerpos físicos.

Antes, sólo se borraban referencias muertas dentro de `_refresh`, después del retorno `if next == _suspended`. Un reset sin cambio de suspensión no llegaba a esa poda. Cada generación agregaba ocho nuevas entradas y ocho WeakRef Objects en el sector medido; los enemigos anteriores sí se destruían. La escena no era el propietario del Dictionary: por eso también quedaban registros tras destruirla.

Reproducción independiente con debug OFF, sin encuentros automáticos ni snapshots retenidos: 100 regeneraciones físicas reales de 65003/GROUND_FLOOR. Nueve registros válidos constantes (ocho Enemy + coordinador), **46→846 obsoletos, +800 Objects**. Al destruir escena: sólo un actor válido, pero 854 registros obsoletos. No se confunde referencia débil con Enemy vivo.

## Corrección mínima

Único archivo productivo modificado: `autoloads/ExplorationState.gd`.

1. `_prune_invalid_actors()` sólo elimina registros cuyo `WeakRef.get_ref()` sea null.
2. Se ejecuta al registrar y al entrar en `_refresh`, ANTES del retorno por estado global sin cambios. Reset conserva sus flags y flujo originales; ahora su housekeeping no depende de una transición.
3. Cada actor tiene una sola conexión `tree_exited → _remove_invalid_actor(id)`, **CONNECT_DEFERRED**, que vincula sólo su ID, no una referencia fuerte al actor. Permite que la destrucción termine antes de examinar el WeakRef. Coste O(1) por aviso de salida; no barrido por frame.
4. Si el actor sólo salió temporalmente del árbol y sigue vivo, la limpieza NO lo elimina. Una conexión persistente permite recibir la posterior destrucción tras reentrada.
5. Registro repetido reutiliza la entrada. No reemplaza since/timers ni captura como originales los timers ya pausados por ExplorationState. Así se conserva la procedencia de la pausa.
6. No se añade una operación de desregistro indiscriminado de actores vivos. La rutina dead-only es idempotente; no actúa como resume ni cambia ownership.

Sin cambios de flags `_combat/_reward/_positioning`, condiciones de suspensión, callbacks de recuperación, velocidad, `_pause_actor`, restauración de timers, IA, percepción, navegación, combate, recompensas o generación. No se emiten nuevas señales de gameplay. Los barridos sólo ocurren en registro y operaciones de suspensión/reset, no desde `_process`, `_physics_process` ni `is_suspended()`.

## Medición equivalente antes/después

Godot `4.7.2.stable.official.ed1daf0bf`, consola Windows headless, misma APPDATA aislada de pruebas. Cada proceso usa la escena Varkhem real, seis regeneraciones de calentamiento, luego 100 regeneraciones de la misma seed. Player real quieto/distante, debug OFF. Se esperan 20 ticks después de generación para liberaciones/deferred; no se presenta ese plazo como latencia jugable ni se fuerza memoria a bajar.

Las muestras se escriben en JSONL. El harness conserva sólo primer/último conteo, agregados y una firma de determinismo, NO un array por regeneración. No logging por frame. Evidencias en `../artifacts/core_gameplay_p3b11`: before/after JSON, JSONL, CSV, logs, summary.json y ledgers.

| Medida | Antes, 100 regeneraciones | Después, 100 regeneraciones |
|---|---:|---:|
| Registros válidos | 9→9 | 9→9 |
| Registros obsoletos | 46→846 | 0→0 |
| Registros totales | 55→855 | 9→9 |
| OBJECT_COUNT | 3623→4423 | 3577→3577 |
| Nodos reales | 809→809 | 809→809 |
| Enemigos/agentes | 8/8 | 8/8 |
| Covers/luces lógicas | 5/5 | 5/5 |
| Layer debug/señales ruido | 1/9 | 1/9 |
| Resources/huérfanos | 325/0 | 325/0 |
| MEMORY_STATIC | 44.026→45.105 MiB | 43.996→44.174 MiB |
| Delta total memoria | +1.079 MiB | +0.179 MiB |
| Delta últimas 32 muestras | +266848 bytes | 0 bytes |
| Rango últimas 32 muestras | 266848 bytes | 0 bytes |

En las últimas 90 muestras corregidas, el rango fue **664 bytes**, frente al crecimiento continuado anterior. El salto inicial de memoria no se oculta: el harness conserva una firma de 20964 caracteres después del conteo inicial y hay buffers/cachés no atribuidos exactamente. No se identifica byte a byte todo el +0.179 MiB como un solo componente ni se afirma que sea fuga. Sí se observa un plateau posterior, sin crecimiento de Objects ni registros.

Tras destruir escena:

| Medida | Antes | Después |
|---|---:|---:|
| Registros válidos/obsoletos | 1/854 | 1/0 |
| Objects | 2713 | 1859 |
| Enemigos/agentes/covers/luces | 0 | 0 |
| Nodos del harness/autoloads | 12 | 12 |
| Conexiones ruido/huérfanos | 0/0 | 0/0 |

La diferencia de 854 Objects al destruir la escena coincide con los 854 WeakRef retirados, mientras valid actors y Resources coinciden. Esto sostiene la atribución del crecimiento de Objects al registro; no constituye atribución completa de toda memoria del motor. Las firmas de plan, placements, contenido, mobiliario y NavMesh fueron iguales antes/después y deterministas dentro de cada proceso.

Clasificación:

- **REGISTROS OBSOLETOS CORREGIDOS:** sí, en escenarios medidos.
- **OBJETOS ESTABLES:** sí, durante las 100 regeneraciones corregidas.
- **MEMORIA ESTABLE:** plateau observado tras el salto inicial; últimas 32 muestras idénticas. No garantía global de memoria plana en todas las situaciones.
- **ATRIBUCIÓN INCOMPLETE:** permanece para bytes exactos, cachés y memoria total del proceso/GPU. MEMORY_STATIC no equivale a PSS/RSS Android.

No se atribuye este hallazgo ni esta corrección a NATIVE_SHUTDOWN_AV.

## Controles A–J

El fixture nuevo combina generación con Player/Enemy reales y unidades mínimas CharacterBody3D+Timer para ownership. Las unidades usan las señales de propietarios reales como estímulo aislado, no simulan una victoria de cartas; los flujos reales se cubren en regresiones y el fixture de suspensión heredado.

| Caso | Evidencia dirigida | Resultado |
|---|---|---|
| A | 100 regeneraciones sin suspensión, debug OFF | PASS |
| B | Stage.regenerate iniciado con posicionamiento suspendido; reset original y nuevos actores activos | PASS |
| C | Actor eliminado mientras recompensa mantiene suspensión; registro borrado, otro actor sigue pausado | PASS |
| D | Actor nuevo durante suspensión recibe pausa | PASS |
| E | Señales combat start/end, contador de resume | PASS |
| F | Señales reward start/end y timers originales | PASS |
| G | Reset original restaura una vez; derrota real en batería compartida | Ver batería |
| H | COMBAT + REWARD + POSITIONING; cerrar un propietario no libera los otros | PASS |
| I | Cinco registros repetidos, una conexión, sin recapturar timers; desregistro muerto repetido | PASS |
| J | 100 regeneraciones consecutivas y destrucción normal de escena | PASS |

Además: actor válido fuera del árbol conserva entrada, reentra y recupera timers correctamente; un Timer prepausado continúa prepausado al reanudar. La limpieza dead-only sobre actor vivo no lo elimina. No se debilitan asserts existentes.

Reproducción del defecto: **PASS/EXIT_0** como control positivo. Código corregido: **PASS/EXIT_0**, sin errores de script. No implica certificación Android.

## Archivos y pendientes

Modificado: `autoloads/ExplorationState.gd` (19 líneas añadidas, una reemplazada).
Nuevos: `core_p3b11_actor_registry_validation.gd/.tscn` y UID, este informe. Godot generó también el UID faltante del fixture heredado `core_p3b1_debug_combat_validation.gd`; es metadata de test, no cambio de comportamiento. No cambios de Enemy, CombatManager, RewardManager, templates, geometría ni otros worktrees.

La importación de editor terminó EXIT_0, registrando el `Safe save failed` preexistente; no se investigó ni corrigió. Android pendiente. NATIVE_SHUTDOWN_AV abierta. No garantía de liberación inmediata de cachés ni de mejora de FPS Android.

## Regresiones finales

69 controles compartidos + control P3-B1 de combate con inspección = **70 PASS funcionales, 64 EXIT_0, 6 NATIVE_AV**. Cero FAIL funcionales y cero INCOMPLETE de ejecución. Los dos procesos independientes de reproducción/validación registry completaron además PASS/EXIT_0. Total de ejecuciones contabilizadas: **72 PASS funcionales, 66 EXIT_0, 6 NATIVE_AV**. El baseline es un control positivo del defecto anterior, no certificación del código anterior.

| Grupo | Ejecuciones |
|---|---:|
| P0-R2 Varkhem/Horvex | 11 |
| P1-B abort/lifecycle | 10 |
| P1-C recompensas/OMITIR | 14 |
| Física Varkhem/Ship/Horvex | 3 |
| Perfiles/hubs P2-B/P2-C-B | 3 |
| P2-C-C habitaciones/configuración/inspection | 4 |
| Compartidos navegación/percepción/DROP/combate/reset/ADN/oxígeno | 24 |
| Combate con debug activo P3-B1 | 1 |

Varkhem físico: seeds 65001–65006 y nueve sectores; Horvex 66001–66003; Ship tres tamaños. No se cambiaron sus Resources. El control heredado de combate verificó 150 ticks con combatientes, 30 de recompensa y 243 de exploración; una sola capa, sin conexiones duplicadas. Flujos reales de cartas/victoria, recompensa, derrota/reset completaron sin errores.

NATIVE_AV (-1073741819 / 0xC0000005) posteriores a resultados funcionales en `abort_repeat`, `abort_after_finish`, `scene_change`, `skip_accept`, `abort_choice` y `rooms`. No se interpretan como EXIT_0 ni aprobación integral. No se investigaron; su frecuencia no se usa para atribuir una causa o declarar la incidencia resuelta.

Los ledgers conservan clasificación funcional y código de proceso por separado. `ATRIBUCIÓN INCOMPLETE` de bytes no se oculta bajo los PASS de aserciones; es una limitación del análisis, no una ejecución omitida.

## Preservación / reproducción

P3-B1 mantiene `c8f582d042f354db9c0411a3fe7dc799c2548c44`, worktree limpio. P3-B1.1 tiene el mismo HEAD y sus cambios sin commit. Main continúa `8bc3e890d5983700db9465fa41c3607cb3b831a9`.

Los **otros 23 worktrees** mantienen HEAD/rama/status, y **3388 archivos** controlados conservan sus hashes. Incluye la recuperación P3-B1, código/diagnósticos protegidos y ZIPs anteriores. `preserve.ps1 -Mode after`: cero diferencias de estados y archivos. `git diff --check`: limpio.

ZIP P2-C-C intacto: SHA256 `034576E00D2FD1A3D65968F1B2C05FC39A7A5444C512A391B73FC00ABFE29214`.
ZIP P0-R2 intacto: SHA256 `265E79BF8DE384E9759BED8DFEF4B5EC1D04CB542F9D228A115FA67D9C61381B`.

Desde este worktree:

```powershell
& '../artifacts/core_gameplay_p3b11/run_registry.ps1'
```

El runner configura APPDATA de pruebas y clasifica marcador, errores de script y salida por separado. `--baseline` se utilizó antes del parche contra el código recuperado, no debe ejecutarse como expectativa de crecimiento sobre la corrección. `summarize.py` consolida resultados; todos los logs/JSONL permanecen disponibles.

**STOP.** P3-B1.1 SIN COMMIT. No ZIP Android, push ni merge. Android pendiente; NATIVE_SHUTDOWN_AV y Safe save failed abiertas. Sin afirmaciones de rendimiento móvil ni fuga global de memoria resuelta.
