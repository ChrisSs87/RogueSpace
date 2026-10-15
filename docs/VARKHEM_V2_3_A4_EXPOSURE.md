# V2.3-A4 — Conversión continua de exposición

2026-10-15. Rama `feature/varkhem-lighting-architecture-v2-3-a2`.
HEAD `956fadad8837f165a39fc4c45724368f1a63e51d`.
A2, A3 y A4 sin commit. No ZIP, push ni merge. Android pendiente.

## Diagnóstico y consumidores

Antes: LightingManager.get_light_level_at hacía roundi(exposure/2), luego Enemy
indexaba light_detection_curve con ese entero. La exposición sí era continua;
la velocidad de acumulación perdía la fracción. Los saltos estaban en exposiciones
1,3,5,7,9/10. En3/10: capacidad0,15→0,50, no un cambio de LOS, FOV o detection_time.

| Exposición ambiental 0–10 | Nivel entero anterior | Capacidad anterior | Nivel continuo nuevo | Capacidad nueva |
|---|---:|---:|---:|---:|
|1|1|0,15|0,5|0,075|
|2|1|0,15|1|0,15|
|2,99|1|0,15|1,495|0,32325|
|3|2|0,50|1,5|0,325|
|3,01|2|0,50|1,505|0,32675|
|4|2|0,50|2|0,50|

La acumulación `_sight_timer += perception_interval_sec * capability` ya usa
floats. También los umbrales, mínimos y comparaciones de confirmación admiten
floats. No requieren índice entero más allá de acceder a los dos puntos vecinos
de la curva. La tabla Resource existente, sus valores y cadence no cambian.

| Consumidor | Contrato A4 |
|---|---|
|get_exposure_at|Canónico0–10, idéntico A2|
|get_light_level_at|Int0–5 intacto para compatibilidad, índices/tests/diagnósticos legacy|
|get_detection_light_level_at|Float0–5 continuo si hay perfil de bioma activo; cuantizado legacy si no|
|Enemy._evaluate_vision|Usa nivel de detección e interpolación de curva|
|Enemy.has_confirmed_visual_contact|Mismo adaptador/curva que acumulación, sin discrepancia al admitir|
|DebugHUD LIGHT y Enemy PLAYER LIGHT|Mismo nivel efectivo, dos decimales|
|get_exposure_diagnostic|Conserva level entero; añade detection_level efectivo|
|SECTOR_PROFILES.applied.ambient_observed|Ambiente canónico efectivo; ambient_observed_scale=10|
|SECTOR_PROFILES.applied.ambient_legacy_0_5|Propiedad anterior separada y etiquetada|

## Corrección mínima

Interpolación lineal entre floor(level) y el punto siguiente, con clamp a los
índices disponibles. Mantiene todos los puntos enteros y comportamiento de curva
vacía. No cambia estados, contacto, proximidad, ruido, sospecha mínima ni admisión.

La ruta continua es genérica y opt-in por perfil A2, no por nombre de especie,
seed o HUD. Varkhem tiene ese perfil; Ship/Horvex productivos no lo tienen y
conservan la cuantización previa, incluso con aportes legacy fraccionarios.
Los perfiles preparatorios Horvex/Nythari siguen sin activarse ni editarse.
Una futura activación deberá validar su balance, no asumir equivalencia legacy.

Ambiente Varkhem3, fuentes, sockets, variantes, presupuestos y distribución
permanecen exactamente iguales a A2. No cambian materiales, población, patrullas,
geometría, navegación, combate, mobiliario, recompensas o misiones.

## Confirmación real antes/después

Referencia antes: auditoría A3. Mismo Player/Raptor reales, guardia fijo a5 m,
FOV/LOS válidos, percepción normal por Timer, suelo y postura estabilizados.
Tiempo medido desde creación del guardia; incluye fase del Timer de0,2 s.
Control A compatible: profile=null sólo en memoria, sin editar otro worktree.

| Caso | A3 | A4 | Exposición canónica A4 |
|---|---:|---:|---:|
|Ambiente3, sin focos|2,22 s|3,22 s|3/10|
|Fuera de alcance de luminaria|2,22 s|3,22 s|3/10|
|Bajo foco OPERATIVA|1,22 s|1,22 s|8,10/10|
|Bajo foco REDUCIDA|1,22 s|1,22 s|7,08/10|
|Bajo foco EMERGENCIA|1,42 s|1,42 s|6,06/10|
|A compatible sin focos|6,82 s|6,82 s|2/10|

De pie/agachado conservan esos tiempos si están expuestos. Movimiento lateral
real probado en todas las variantes; no se añade luz por moverse ni invisibilidad
por STEALTH. HIGH bloquea ambas posturas, MEDIUM sólo agachado, LOW no bloquea;
paredes bloquean. Casos bloqueados no confirman durante8 s de observación.

Sweep ambiental nuevo:2/10 confirma6,82 s;2,99/3/3,01 confirman3,22 s;4 confirma
2,22 s. No se impuso un tiempo objetivo. La curva es continua, aunque el muestreo
sensorial de0,2 s conserva escalones pequeños en tiempos medidos.

Efecto secundario explícito:1/10 produce0,075, por debajo del mínimo de sospecha
Varkhem0,1; sin foco ni proximidad no genera sospecha/confirmación durante8 s.
Antes el redondeo lo elevaba a0,15. Se conserva ese mínimo configurado: A4 no
promete continuidad de todas las decisiones donde existen umbrales propios.
Ambiente productivo sigue siendo3, no1; apagar focos no cruza ese mínimo.
Se conservan las reglas previas para exposición inferior al mínimo y las
comprobaciones frescas de LOS/cobertura, sin añadir excepciones de contacto.

## Infiltración: mismos recorridos A3/P2-C-E

STEALTH, posiciones originales, movimiento/colisiones/ruido/guardias normales.
FAIL aquí es de ESTRATEGIA, no regresión ni demostración de ruta imposible.

| Caso | OPERATIVA A3→A4 | REDUCIDA A3→A4 | EMERGENCIA A3→A4 |
|---|---|---|---|
|65001 GROUND BARRACKS HIGH p0|PASS→PASS|PASS→PASS|PASS→PASS|
|65006 BASEMENT BARRACKS HIGH p0|PASS→PASS|PASS→PASS|PASS→PASS|
|65002 GROUND BARRACKS HIGH p0|FAIL1,78→1,98 s|FAIL1,78→1,98 s|FAIL1,78→1,98 s|
|65003 GROUND BARRACKS HIGH p0|FAIL2,18→2,18 s|FAIL2,18→2,38 s|FAIL2,18→2,38 s|
|65002 GROUND HUB MEDIUM p1|FAIL3,38→3,38 s|FAIL3,58→3,58 s|FAIL3,78→3,58 s|
|65003 GROUND HUB MEDIUM p1|FAIL3,18→3,18 s|FAIL3,58→4,18 s|FAIL3,58→4,18 s|

La interpolación puede subir o bajar capacidad respecto del punto redondeado
anterior según la fracción; NO es una reducción global de detección.65002hub/E
confirma0,2 s antes que A3; se registra, no se oculta ni se cambia la estrategia.
No se volvió fallida ninguna estrategia antes exitosa de la muestra.

No se certifica START→EXIT ni toda fase de patrulla;65001 BARRACKS carece de
guardia propio. Otros cinco sectores de referencia no tienen secuencia completa
repetida en A4; los gates físicos no sustituyen esa evidencia de infiltración.

## Archivos productivos A4

- autoloads/LightingManager.gd: adaptador de detección y diagnóstico efectivo.
- scripts/enemies/Enemy.gd: interpolación y dos consumidores visuales; formato debug.
- scripts/ui/DebugHUD.gd: nivel efectivo y ambiente real, sin panel nuevo.
- scripts/world/Stage6GProceduralPrototype.gd: sólo snapshot de ambiente efectivo.

Nuevos tests/escenas A4: curve_validation, exposure_audit, sector_validation.
A3 original y sus resultados se conservan. Runners/artefactos en
`artifacts/varkhem_v2_3_a4`; originales de los cuatro archivos antes de A4 en
`before_files.json`. Documentación histórica CORE/CURRENT no reescrita.

## Validación y rendimiento

| Batería final | Funcional | EXIT_0 | NATIVE_AV |
|---|---|---:|---:|
|Curva/adaptadores/scope legacy|1 PASS|1|0|
|Sweep ambiente1/2/2,99/3/3,01/4|6 PASS|6|0|
|Exposición/cobertura/postura/movimiento|64 PASS|64|0|
|Secuencias completas, mismas estrategias|8 PASS /16 FAIL de estrategia|23|1|
|Refugio→espera→salida|8 PASS /8 FAIL de estrategia|15|1|
|Cruces P2-C-D65001|8 éxitos locales|7|1|
|Regresiones compartidas|35 PASS|33|2|
|Físicos Varkhem/Ship/Horvex|3 PASS|3|0|
|Grid/firma/ambiente efectivo, dos pasadas|2 PASS|2|0|
|Generación aislada, dos pasadas|2 PASS|2|0|
|TOTAL|137 satisfactorios;24 FAIL de estrategia|156|5|

161 procesos finales. Cero FAIL de regresión y cero INCOMPLETE en estos controles;
esto no convierte escenarios de infiltración no ensayados en PASS. Un piloto
unitario adicional `curve.log` precedió a `curve_final.log`: pasó otros contratos,
pero su fuente no generaba realmente aporte fraccionario (intensity es int).
Se corrigió sólo el fixture usando intensity1 y falloff0,75, con assert explícito
de exposición3,5/10. El piloto se conserva y no cuenta en los161 finales.

Regresiones: Stage5E/F/G/H, DROP, escape/doble, HIGH/MEDIUM/LOW, sospecha visual,
APPROACH, cancelación total y reentrada, SOUND/VISION, suspensión, victoria/reset,
emboscadas positivas/negativas, ADN, oxígeno, contenido runtime, P0-R2 close/wall/
pair Horvex, abort P1-B, OMITIR P1-C, perfiles P2-B, debug P3-B1, registry P3-B1.1
y percepción A2 O/R/E. Todos los asserts existentes se conservaron.

Varkhem físico:65001–65006, nueve sectores y controles de determinismo;28
ensamblajes por pasada. Ship tres tamaños; Horvex66001–66003, ocho sectores.
Firmas físicas/nav/covers/población se conservan entre variantes y repeticiones.
Los592 registros de punto/exposición del grid comparados con A3 tienen cero
diferencias canónicas; no cambian las fuentes para compensar el nuevo adaptador.

100 regeneraciones:823 nodos,3651 objetos,9 actores válidos/0 obsoletos,
8 enemigos/agentes/luces,5 covers estables. Memoria46.661.550→46.939.794 bytes;
últimas32 muestras idénticas46.939.794. No demuestra ausencia de cualquier fuga
del proceso ni resuelve la incidencia nativa.

Los5 NATIVE_AV ocurrieron DESPUÉS de resultados terminales: P0-R2 wall_close y
P1-C skip_accept después de PASS; cruce inmediato A compatible después de éxito;
hub65003 A compatible completo/hold después de FAIL de estrategia. Código
-1073741819 (0xC0000005), sin normalización ni investigación. No aprobación integral.
Cero SCRIPT ERROR/ERROR en logs finales.

Rendimiento de escritorio, no Android:

- Dos pasadas aisladas de28 ensamblajes: medias342,21/355,68 ms, máximos459/521 ms.
  Referencia histórica A2 mismo harness:353,61 ms, máximo473. Media conjunta A4
  348,95 ms: no evidencia de aumento sostenido, tampoco prueba de mejora causada
  por A4. Máximo521 registrado sin ocultarlo. No medición controlada pareada de
  todo el proceso antes/después; la primera regresión física concurrente dio
  372,39 ms y se conserva, pero no se usa para atribución de rendimiento.
- En12 pares de queries bajo aporte luminoso real (dos sectores, O/R/E, dos
  pasadas),5000 consultas: adaptador entero48,31 ms promedio; continuo48,14 ms.
  Rangos32,01–66,45 /30,49–66,73 ms. Ambos consultan las mismas fuentes/raycasts;
  orden entero→continuo fijo, no benchmark estadístico ni evidencia de aceleración.
- Interpolación:100.000 llamadas48,99 ms (~0,49 μs/call) en fixture unitario.
  No se extrapola a FPS ni GPU móvil. Sin luces, raycasts o nodos nuevos en producción.
- Grid:65003/GROUND,65005/UPPER,148 puntos navegables equivalentes por modo.
  El tiempo reportado de65005 incluye generación de DOS sectores hasta UPPER;
  no se mezcla con tiempos unitarios de65003 ni se suman etapas solapadas.

`ambient_observed` verificado contra get_ambient_exposure():3/10 en O/R/E,2/10
en A compatible; propiedad legacy1/5 separada. DebugHUD y Enemy muestran el mismo
nivel continuo de detección, conservando level entero en diagnósticos compatibles.

Preservación: de705 archivos preexistentes A2, sólo cambian los cuatro productivos
enumerados; Resources y A3 intactos.27 otros worktrees y4741 archivos verificados
sin diferencias. Main intacta, diff check limpio, index sin staging nuevo.
Los cambios A4 se dejan sin commit junto a A2/A3 para revisión.

## Riesgos pendientes

NATIVE_SHUTDOWN_AV abierta y separada; Safe save failed abierta. No se investigan.
Sin certificación integral ni Android. Contraste visual, tiempos de reacción
manual, sombras, GPU/térmica y Cardboard requieren dispositivo real.
No ZIP ni commit. STOP después del informe; no avanzar V2.3-B.
