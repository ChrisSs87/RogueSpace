# V2.3-A3 — Balance de iluminación y sigilo

Auditoría del 15-10-2026. Sin cambios de producción, balance o Resources.
Rama conservada: `feature/varkhem-lighting-architecture-v2-3-a2`.
HEAD: `956fadad8837f165a39fc4c45724368f1a63e51d`; A2 continúa sin commit.
No ZIP, commit, push ni merge. NATIVE_SHUTDOWN_AV y Safe save failed abiertas.

## Método y alcance

Godot 4.7.2.stable.official.ed1daf0bf, headless, física/fixed-fps 60.
Fixtures nuevos exclusivamente diagnósticos; originales P2-C-D/E intactos.
Se reutilizaron sus rutas, bolsillos, input normal, colisiones, ruido, patrullas,
ticks sensoriales y criterios de resultado. No se buscaron posiciones nuevas.

Comparador `V23_A`: desactiva exclusivamente `biome_lighting` EN MEMORIA dentro
del proceso; conserva el modelo coherente A, ganancia 2 y ambiente legacy 1/5.
No modifica el Resource en disco. Es un control compatible con A, NO una batería
ejecutada sobre el worktree limpio A. La equivalencia luminosa se comprobó en
el diff: dirección DOWN, mismo falloff/oclusión y round(sum legacy) equivalente
a round(sum canonical/2). No se atribuyen otras diferencias históricas a A2.

Timing: Raptor real (`orco_picaro.tres`), 5 m, frente al jugador, suelo real,
Player real estabilizado, Enemy inmóvil para mantener orientación/distancia,
Timer sensorial normal activo. Sin forzar estados ni invocar evaluación visual.
La transición automática a combate se desactiva sólo en este fixture de medida.
Confirmación medida en ticks desde creación del guardia, incluyendo fase inicial
del Timer. Una ejecución por combinación: no es una distribución estadística ni
un benchmark wall-clock. O/R/E comparan un foco ACTIVADO; la selección procedural
de encendidos se mide por separado en sectores reales.

## 1. Exposición y confirmación visual

Formato exposición: **canónica 0–10 / efectiva entera 0–5**.

| Condición equivalente | A compatible | OPERATIVA | REDUCIDA | EMERGENCIA |
|---|---:|---:|---:|---:|
| Sin aporte directo / foco apagado | 2,00 / 1 | 3,00 / 2 | 3,00 / 2 | 3,00 / 2 |
| Foco a 10 m, fuera de alcance | 2,00 / 1 | 3,00 / 2 | 3,00 / 2 | 3,00 / 2 |
| Bajo luminaria activa | 7,10 / 4 | 8,10 / 4 | 7,08 / 4 | 6,06 / 3 |
| Confirmación sin focos, segundos | 6,82 | 2,22 | 2,22 | 2,22 |
| Confirmación bajo foco, segundos | 1,22 | 1,22 | 1,22 | 1,42 |

De pie/agachado dieron iguales valores en esos puntos. STEALTH sin interposición
no da invisibilidad. Primera sospecha visual ~0,22 s en casos expuestos.
Curva real [0;0,15;0,5;0,8;0,9;1], detection_time 1 s, intervalo 0,2 s.
El paso ambiente 2/10→3/10 cruza un umbral de redondeo: capacidad 0,15→0,50
(3,33 veces); tiempo observado 6,82→2,22 s (−67,4%, ~3,07 veces más rápido).
Las diferencias entre tiempo ideal y observado incluyen ticks/fase y acumulación
numérica; no se reinterpretaron como cambio de detection_time.

Cobertura interpuesta entre guardia y jugador, con foco encima del jugador:

| Obstrucción | De pie | Agachado | Todas las variantes |
|---|---|---|---|
| HIGH | LOS NO | LOS NO | Sin confirmación durante 8 s |
| MEDIUM | LOS YES | LOS NO | De pie: tiempo de foco; agachado: sin confirmación 8 s |
| LOW | LOS YES | LOS YES | Tiempo de foco en ambas posturas |
| Pared sólida | LOS NO | LOS NO | Sin confirmación durante 8 s |

La exposición bajo foco permanece alta detrás de esa cobertura porque el objeto
interrumpe guardia→jugador, NO foco→jugador. No es una discrepancia: iluminación
y oclusión de visión son comprobaciones distintas. La oclusión estática de la
fuente ya fue validada en A2; no se repitió toda esa batería.

Movimiento lateral real, input normal, misma estrategia durante los primeros ticks:

| Variante | Exposición de pie | Agachado | Niveles observados | Confirmación |
|---|---:|---:|---|---:|
| A | 6,87–7,10 | 7,00–7,10 | 3/4 | 1,22 s |
| OPERATIVA | 7,87–8,10 | 8,00–8,10 | 4 | 1,22 s |
| REDUCIDA | 6,89–7,08 | 7,00–7,08 | 3/4 | 1,22 s |
| EMERGENCIA | 5,92–6,06 | 6,00–6,06 | 3 | 1,42 s |

El movimiento no añade luz por sí mismo. Postura modifica la visión/LogicalCover,
pero la iluminación se consulta en el origen físico del Player, no en la cámara.

## 2. Puntos equivalentes en sectores realmente ensamblados

Grid de centros y offsets locales ±2 m, filtrado por proyección NavMesh XZ ≤0,12 m.
Son puntos navegables de muestreo, NO certificación de refugio ni barrido corporal.
Mismos puntos y misma firma física/nav/población/covers en cada comparación.

| Sector | Variante | Puntos | Media 0–10 | Mín–máx | Sólo ambiente | Luces activas/instancias |
|---|---|---:|---:|---|---:|---|
|65003 GROUND|A|87|3,26|2–7,10|61|5/5|
|65003 GROUND|OPERATIVA|87|4,52|3–9,52|57|8/8|
|65003 GROUND|REDUCIDA|87|3,82|3–8,22|64|6/8|
|65003 GROUND|EMERGENCIA|87|3,43|3–6,06|71|3/8|
|65005 UPPER|A|61|3,08|2–7,10|45|3/3|
|65005 UPPER|OPERATIVA|61|4,60|3–8,12|37|6/6|
|65005 UPPER|REDUCIDA|61|3,28|3–7,08|56|1/6|
|65005 UPPER|EMERGENCIA|61|3,17|3–5,74|56|1/6|

REDUCIDA baja el nivel efectivo frente a OPERATIVA en 24/87 y 22/61 puntos;
EMERGENCIA en 29/87 y 22/61. Ningún punto supera OPERATIVA. En los restantes
predomina igualdad por ambiente/quantización, aunque la exposición continua baje.
Sí existen diferencias tácticas, pero NO en todos los puntos. REDUCIDA y EMERGENCIA
son idénticas lejos de focos: ambas tienen suelo global 3/10→2/5.

## 3. Infiltración real: mismas estrategias de P2-C-E

Todas estas secuencias usan STEALTH y bolsillos originales. PASS exige entrada,
espera y salida sin sospecha/confirmación. FAIL significa estrategia fallida,
NO defecto de producción ni imposibilidad de la seed.

| Estrategia | A | OPERATIVA | REDUCIDA | EMERGENCIA |
|---|---|---|---|---|
|65001 GROUND BARRACKS HIGH p0|PASS|PASS|PASS|PASS|
|65006 BASEMENT BARRACKS HIGH p0|PASS|PASS|PASS|PASS|
|65002 GROUND BARRACKS HIGH p0|FAIL VISION 2,18 s|FAIL 1,78 s|FAIL 1,78 s|FAIL 1,78 s|
|65003 GROUND BARRACKS HIGH p0|FAIL VISION 2,38 s|FAIL 2,18 s|FAIL 2,18 s|FAIL 2,18 s|
|65002 GROUND HUB MEDIUM p1|FAIL VISION 3,78 s|FAIL 3,38 s|FAIL 3,58 s|FAIL 3,78 s|
|65003 GROUND HUB MEDIUM p1|FAIL VISION 3,78 s|FAIL 3,18 s|FAIL 3,58 s|FAIL 3,58 s|

Éxitos completos: espera 23,42/23,40 s, total 39,73/39,68 s, iguales entre modos.
65001 BARRACKS no tiene guardia propio: su éxito no demuestra evasión de un
guardia situado dentro de la habitación.

Controles inicializados EN refugio HIGH p0 de65002/03: las cuatro versiones pasan
espera→salida, espera 23,42/23,40 s y total28,93 s. Interposición durante todos
los1405/1404 ticks de espera;21/22 eventos de ruido al salir, sin detección.
Esto NO demuestra acceso seguro a esos refugios.

Controles inicializados en HUB MEDIUM p1: todos fallan por VISION de otro guardia,
aunque hay interposición frente a al menos uno durante toda la espera observada.
Tiempos65002 A/O/R/E:1,38/1,18/1,38/1,38 s;
65003:1,38/1,18/2,18/2,18 s. Reducción de luz puede demorar detección, no corregir
protección unilateral insuficiente. No hubo ruido durante esas esperas.

Replays P2-C-D65001: cruce inmediato y cruce tras esperar3,6 s se conservan en
A/O/R/E:8 éxitos locales, cero frames de visión/confirmación,43/23 sonidos normales,
duraciones10,82/9,78 s. No son pruebas START→EXIT.

Respecto del histórico P2-C-E (iluminación anterior incluso a A), se conservan
los éxitos/fallos de estos casos, pero sus tiempos NO son directamente los de A:
por ejemplo, la habitación65002 histórica confirmaba≈1,38 s, A compatible2,18 s,
A2 1,78 s. No atribuir todas las diferencias acumuladas a ambiente3.

Infiltración de65003 BASEMENT,65004 GROUND,65005 GROUND/UPPER y65006 GROUND:
INCOMPLETE en A3, no repetida. El grid65005 UPPER no sustituye movimiento real.
No se muestrearon todas las fases, entradas, rutas alternativas ni velocidades.
Ninguna estrategia antes exitosa de la muestra se volvió fallida; sí hay una
reducción medible del tiempo de exposición tolerado en aproximaciones ya expuestas.

## 4. Coherencia y limitaciones

- Una misma RoomLogicalLight/modelo produce SpotLight y contribución lógica;
  activación visual/lógica coincidente en todos los focos auditados.
- OPERATIVA: mayor exposición y todas las luminarias seleccionadas activas;
  compatible funcionalmente con base operativa. Calidad visual militar: pendiente Android.
- REDUCIDA: menos fuentes/potencia y menor media real. No siempre cambia el nivel
  entero ni el tiempo de detección; bajo foco O y R empatan en este fixture.
- EMERGENCIA: menos fuentes, menor potencia y rojo autorizado. Zonas localizadas
  de aporte demostradas; oscuridad profunda NO: ambiente3 impide bajar de nivel2/5.
- Se revisaron capturas A2 OPERATIVA/EMERGENCIA, sin render nuevo: lámpara roja
  visible, pero suelo cian y legibilidad ambiental reducen la impresión de rojo.
- Escalas de gameplay, no lux ni equivalencia fotométrica. Atenuación lógica
  lineal/cone cutoff no replica exactamente shading/tonemapping/materiales Godot.
- Luz: raycast estático layer1 desde fuente al origen Player; visión: ojo→Head y
  reglas de LogicalCover/postura. Actores no proyectan oclusión luminosa lógica.
  El ambiente global no se ocluye. Sombras visuales no implican exposición cero.
- Comentarios legacy de LightingManager todavía dicen “sin raycasts” y “no
  sincronizado”: no describen la ruta opt-in actual. Se documenta, no se corrige.
- Discrepancia de observabilidad confirmada: SECTOR_PROFILES.applied.ambient_observed
  sigue mostrando1 (propiedad legacy) en O/R/E, mientras lighting_profile.ambient_10
  declara3 y las consultas reales producen3/10→2/5. No significa ambiente ignorado:
  ese campo legacy no representa el valor efectivo. Proponer corregir su etiqueta
  o consumidor en otra tarea; ninguna modificación productiva aquí.

## 5. Procesos, preservación y rendimiento

| Batería | Resultado funcional | EXIT_0 | NATIVE_AV |
|---|---|---:|---:|
|Exposición/timing/covers,64 combinaciones|64 PASS|63|1|
|Grid sectorial y firmas|1 PASS,8 filas|1|0|
|Secuencias completas|8 PASS /16 FAIL de estrategia|23|1|
|Espera/salida de refugio|8 PASS /8 FAIL de estrategia|16|0|
|Cruces P2-C-D|8 éxitos locales|5|3|
|Total|89 controles/estrategias satisfactorios;24 estrategias fallidas|108|5|

113 procesos. Cero errores de script/ERROR en los logs, cero FAIL de regresión
demostrado. Todos los NATIVE_AV después de marcador funcional/resultado terminal:
REDUCIDA ambient de pie; REDUCIDA65006BASE secuencia; cruces inmediatos A/O/E.
Código exacto -1073741819 (0xC0000005). No certificación integral, no investigación.

705 archivos preexistentes de A2: hashes idénticos antes/después.
27 otros worktrees y4741 archivos del manifiesto previo: cero diferencias.
Diff check limpio. Main intacta. Sólo se añadieron fixtures/escenas A3 y artefactos;
las pruebas originales, los cambios pendientes A2 y sus Resources están intactos.

No se repitió la batería general A2 ni sus benchmarks: no hay cambios productivos.
Referencia A2 (NO medición nueva A3): generación351,04 ms A/358,00 ms A2;
queries1000START3,8–8,1 ms; render RX570960×540 limitado por VSYNC≈16,67 ms;
100 regeneraciones con nodos/objetos estables. No prueba rendimiento Android.

## 6. Recomendación

**REVISAR ambiente3 antes de congelar balance**, no modificarlo automáticamente.
Conservar arquitectura/fuentes/coberturas. El valor3 cae exactamente en el salto
de redondeo al nivel2 y acelera mucho la confirmación ambiental, mientras limita
la diferencia de sombras entre variantes. No es un fallo de percepción.

Siguiente comparación de balance propuesta, NO realizada: ambiente2/2,5/3 con
mismos puntos/estrategias y medición Android de legibilidad y tiempo de reacción.
Elegir después un valor configurable; no retocar IA, FOV ni reducir contacto para
compensar. Una futura curva continua requeriría autorización distinta porque
cambiaría el contrato compartido de percepción.

Android/Cardboard pendientes: contraste real, exposición percibida de lámparas
rojas, comodidad STEALTH, ruido/movimiento manual, margen temporal para infiltrarse,
sombras GPU, resolución binocular, térmica y FPS al regenerar. Sin estimar FPS móvil.

## Evidencia y reproducción

En esta carpeta: `input_manifest.json`, cuatro `*_ledger.csv`, logs y JSON de
cada estrategia, `sector_exposure.log` con puntos/fuentes/firmas completas.
`run_audit.ps1 -Group exposure|staged|hold|controls` reproduce cada subbatería.
Grid: escena `res://scenes/tests/a3_sector_exposure.tscn`.
Nuevos tests: a3_exposure_audit, a3_sector_exposure, a3_staged_audit y snapshots
a3_p2cd_reference/a3_p2ce_reference. No reemplazan fixtures originales.

STOP. No avances V2.3-B, sin implementación de balance.
