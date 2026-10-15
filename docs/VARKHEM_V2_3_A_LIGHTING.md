# Varkhem V2.3-A — iluminación visible y exposición lógica

Rama `feature/varkhem-v2-3`; base `9fb0e12b8bab3ef6ef238c1ee725a9fd7d75e321`.
Implementación local SIN COMMIT. Android/Cardboard pendientes. Sin ZIP, push ni merge.
Evidencia: `../artifacts/varkhem_v2_3_a/`. Se conserva el informe de preparación anterior.

## Discrepancias verificadas

Antes: RoomLogicalLight añadía 2 uniformemente en todo el footprint; la tira
visible era un BoxMesh unshaded, sin luz real. Gran parte del kit también era
unshaded: un foco real por sí solo no habría comunicado exposición/sombra.
La iluminación lógica no comprobaba oclusión desde la luminaria.

Player/HUD y Enemy ya consultaban LightingManager. Enemy exigía alcance/FOV/LOS,
incluyendo LogicalCover, y después acumulaba exposición según curva de especie.
Sospecha visual producía ALERT; visión confirmada CHASE. Nada de esto se reescribe.

Una primera captura real reveló otra discrepancia: el marcador semántico blanco,
sin collider, proyectaba una sombra gráfica inexistente para gameplay. En el modo
coherente se deshabilita la proyección de sombras de los tres roots de debug
conocidos y de decoración sin ownership físico. No se eliminan nodos ni colliders.

## Modelo y correspondencia

`RoomEnvironmentProfileResource.coherent_light` es opt-in; null conserva el legado.
Sólo `VarkhemRoomEnvironment.tres` lo activa. Reutiliza una fuente por luminaria
existente: no se cambian habitaciones, semánticas, mobiliario, spawns o patrullas.

| Dato | Aplicación |
|---|---|
| Transform y altura | Luminaria existente, montaje local 1.9 m; fuente/spot coinciden |
| Dirección | Cono hacia abajo, semicono 80°; orientación visual comprobada |
| Alcance | 7 m compartidos por SpotLight3D y consulta lógica |
| Intensidad lógica | `room_light_addition * logical_peak_per_room_unit`, 2 × 1.5 = 3 |
| Energía visual | Pico lógico × 0.4 = 1.2 unidades Godot |
| Color | `(0.85, 0.9, 0.7)`, compartido con la tira visible |
| Activación | `RoomLogicalLight.set_active()` gobierna aporte, foco y tira |
| Oclusión lógica | Raycast capa 1 hacia la posición real muestreada, sólo dentro de rango/cone |
| Oclusión visual | Sombra del spot y geometría física del kit; marcadores sin collider no inventan sombras |
| Legibilidad base | Emisión de material 0.12, sin cambiar ambient lógico global (1 en las muestras) |

La contribución es `pico * (1 - distancia / alcance)` dentro del cono y con camino
luminoso libre. LightingManager sigue sumando todas las fuentes + ambient y sólo
entonces redondea/limita a 0–5. El endpoint del raycast se acorta 3 cm para evitar
interpretar el propio suelo muestreado como pared. Player/Enemy y proxies de bake
no entran en esa máscara estática; no se alteran capas ni colliders.

Los Resources resueltos por sector se copian al construir la fuente; el perfil
efectivo sigue siendo autoridad, incluidos overrides de `room_light_addition`.
Cambiar configuración requiere regeneración; activar/apagar usa el método público,
no ocultar arbitrariamente un padre. No hay polling de perfiles ni animación de luces.

**No es equivalencia fotométrica/píxel a píxel.** La energía Godot, BRDF, normales,
filtrado de sombras y caída del spot no son una escala de niveles 0–5. La correspondencia
comprobada es fuente/posición/rango/dirección/activación y oclusión de geometría estática,
con calibración declarativa de energía. El color visible debe revisarse en Android.
Sombras de actores dinámicos, exposición de toda la silueta y geometría visual que no
coincida con su collider no tienen una simulación luminosa equivalente garantizada.
El subconjunto inicial es el kit CSG/cuerpos existentes; futuros meshes con colliders
como siblings requieren verificar explícitamente ownership de oclusión.

## Materiales y límites del cambio

RoomEnvironmentBuilder duplica materiales de instancias Varkhem, habilita respuesta
per-pixel y conserva color/geometría. No modifica materiales .tres compartidos en disco.
La iluminación mínima usa emisión para legibilidad, no una nueva fuente de exposición.
No se añaden luces a corredores ni a espacios antes excluidos (BASE_ACCESS).
Hay 2–5 spots por sector en las nueve muestras, una luz por luminaria existente,
sin parpadeo, animaciones ni nuevas luces por enemigo/objeto. Cada spot proyecta
una sombra; el coste móvil de esa elección sigue pendiente y no se declara barato
por haber pasado una medición de escritorio.

LightingManager sólo agrega diagnóstico público; su agregación productiva anterior
no cambia. Enemy, Player, LogicalCover, CombatEncounterManager, RewardManager,
Navigation y Resources Ship/Horvex no se modifican. Stage6G añade únicamente un
hook opt-in de sombras de debug y observabilidad de iluminación aplicada en PROFILES.

## Debug

DebugHUD conserva LIGHT del mismo getter productivo. Con percepción debug activada
añade fuente principal por etiqueta semántica y estado/COVER/LOS del enemigo más
cercano, muestreado cada 0.2 s. No crea nodos ni conexiones nuevas. La API mantiene
también el path completo para distinguir fuentes con la misma etiqueta.
PROFILES publica posición, dirección, perfil efectivo, intensidad, alcance,
activación y sombras de las fuentes realmente creadas.

Una cobertura HIGH puede bloquear visión aun con exposición 4: iluminación del
jugador y LOS del guardia son variables diferentes. Agacharse no concede oscuridad
ni invisibilidad automática; MEDIUM conserva su contrato de postura/interposición.

## Pruebas dirigidas

`varkhem_v23_lighting_validation` usa Player/Enemy reales, suelo/colliders reales y
Timer normal de percepción. Guardia inmóvil sólo para aislar FOV; no se fuerza CHASE.
Verifica fuente montada/rango/energía/dirección, exposición bajo foco y fuera de rango,
oclusión por pared, activación compartida, ALERT progresivo y CHASE confirmado,
confirmación conservada al apagar la fuente, HIGH/MEDIUM/LOW de pie/agachado,
pared contra LOS y desplazamiento real mediante input con variación de exposición.
Los barridos adicionales de puntos son muestras espaciales, no pruebas de recorrido seguro.
PATROL móvil, investigación, persecución y navegación se cubren por los harnesses existentes.

Ejemplos observados: bajo foco nivel 4; al apagarlo nivel 1 conservando CHASE con LOS
válido y exposición ya confirmada; al alejarse lateralmente niveles 4→3→2→1.
HIGH bloquea ambas posturas; MEDIUM sólo agachado; LOW ninguna. Oscuridad no permite
atravesar paredes ni modifica admisión P0/P0-R2.

## Validación y evidencias

- Batería general: 31 PASS funcionales, 30 EXIT_0 y 1 NATIVE_AV (paredes, después del PASS).
  Incluye los seis Stage5 obligatorios, coberturas/sospecha, APPROACH, DROP/reentrada,
  suspensión, victoria/derrota/reset, emboscada, ADN, O2, P0-R2, abort P1-B,
  OMITIR P1-C y perfiles P2-B. `regression_ledger.csv`.
- Repetición final dirigida: debug/combate P3-B1, P3-B1.1 (100 regeneraciones) y luz:
  3 PASS / 3 EXIT_0. `recovery_ledger.csv`.
- Físicos Varkhem/Ship/Horvex: nueve sectores 65001–65006 y determinismo
  65001/03/05/15/20; Ship tres tamaños; Horvex 66001–66003/ocho sectores.
  `final_ledger.csv` y repetición de cierre `closure_ledger.csv`.

Selección final de gates funcionales: **37 PASS / 36 EXIT_0 / 1 NATIVE_AV**
(31 generales + 3 dirigidos + 3 físicos de cierre). Los ocho ensayos A/B de
generación/render se informan adicionalmente, todos PASS/EXIT_0; no se confunden
con certificación Android ni se ocultan los ensayos fallidos iniciales.
- A/B de generación: dos procesos por modo, 28 generaciones medidas por proceso,
  todos PASS/EXIT_0. Baseline sólo desactiva coherent_light dentro del proceso de test.
  No cambia Resources en disco. `performance_ledger.csv` y `generation_summary.csv`.
- Render Mobile real en Radeon RX 570, 960×540, cámara/sector idénticos, dos pares,
  120 frames por proceso después de 30 de preparación: cuatro PASS/EXIT_0.
  `render_ledger.csv`, `render_baseline.png` y `render_coherent.png`.

En la comparación de 28 ensamblajes, firmas físicas/proxies/vértices/polígonos son
idénticos al baseline de preparación al excluir el tiempo del log. Los gates de
entorno mantienen conectividad, seams, containment, colisiones, población y contenido.

## Coste observado, NO Android

| Medición de escritorio | Baseline | Coherente |
|---|---:|---:|
| Generación, media de dos pasadas de 28 | 342.34 ms | 355.70 ms |
| Máximo de esas pasadas | 471 ms | 489 ms |
| Frame medio render real, dos pasadas | ~16.665 ms | ~16.665 ms |
| P90 frame | 17.12–17.16 ms | 17.08–17.10 ms |
| Draw calls reportadas, vista concreta | 25 | 25 |

Incremento observado de generación: ~13.36 ms (~3.9%); no atribución exclusiva a GPU
o raycasts. Los 1000 queries con 2–5 fuentes tardaron 2.16–4.83 ms totales; un
microbenchmark de 10.000 consultas bajo foco tardó ~27.5 ms. Son consultas repetidas
en escritorio, no coste Android ni duración de un frame normal.
La fuente no tiene `_process` ni `_physics_process`: se configura una vez y se
consulta por demanda. Sombras/rendering siguen teniendo coste aunque la luz no se mueva.

El render está limitado por sincronización/display (~16.67 ms): **no demuestra coste
GPU nulo, margen de rendimiento ni 60 FPS Android**. Los monitores headless de proceso/
physics se conservan como datos brutos, no como medición de GPU o CPU aislada.
Android requiere comparar la misma vista/seed, frame time, memoria GPU, temperatura,
sombras y legibilidad con device real. XR/Cardboard continúa sin certificación.

100 regeneraciones: nodos 814→814, objetos 3617→3617, registros 9 válidos/0 obsoletos
en ambos extremos; fuentes y señales estables. Memoria reportada +187196 bytes
(~0.18 MiB): no se afirma fuga ni atribución de bytes; no se fuerza limpieza de cachés.

## Ensayos fallidos conservados y limitaciones

No se borran los primeros logs: error de tipado del fixture de luz (interrumpido),
error de tipado del builder (FAIL/EXIT_1), fixture de métricas que buscaba un Player
inexistente en el gate físico (FAIL_FIXTURE/NATIVE_AV), parser del render probe
(FAIL_FIXTURE aunque el motor devolvió EXIT_0), y P3-B1.1 sin argumento output
(INCOMPLETE/interrumpido tras fallar escritura final). Se corrigieron los errores
de esta implementación/runner sin relajar asserts ni modificar tests heredados.
El JSONL del último caso se preservó como `registry_missing_output.jsonl`.

La primera importación terminó NATIVE_AV; la importación final terminó EXIT_0.
Safe save failed preexistente se registra aparte. No se atribuye una causa a esos AV.
**NATIVE_SHUTDOWN_AV ABIERTA; SAFE SAVE FAILED ABIERTA; ANDROID PENDIENTE.**
Ningún PASS seguido de AV equivale a certificación integral.

## Archivos

Producción: LightingManager.gd (diagnóstico), RoomEnvironmentProfileResource.gd
(opt-in), VarkhemRoomEnvironment.tres, RoomLogicalLight.gd, RoomEnvironmentBuilder.gd,
Stage6GProceduralPrototype.gd (hook/PROFILES), DebugHUD.gd y nuevo RoomLightModelResource.gd.
Tres scripts/escenas nuevos: lighting_validation, environment_validation y render_probe;
UID correspondientes. Informe nuevo, sin modificar CURRENT ni main.

STOP al entregar. Sin paquete móvil; requiere revisión de modelo y pruebas Android.
