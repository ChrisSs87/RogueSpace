# Varkhem V2.3-B — identidad visual militar

2026-10-15. Rama `feature/varkhem-visual-identity-v2-3-b`.
Worktree `C:/Users/chris/OneDrive/Documentos/RogueSpace/varkhem_v2_3_b_worktree`.
Base exacta `7f487b6ce857e69dcdc53e1109f9c2ec2f4c9d69`.
SIN COMMIT, sin ZIP, push, merge ni consultas GitHub. Android/Cardboard pendientes.

## Preparación y límites

AGENTS.md e informes A/A2/A3/A4 revisados. La base incluye exposición canónica
0–10, perfiles/fuentes/sockets, variantes O/R/E, adaptador continuo A4, P0-R2,
recompensas/OMITIR, coberturas tácticas y lifecycle P3-B1/B1.1. No se incorpora
caché NavMesh ni experimentos Horvex/P2-C-F rechazados.

Se conservan las formas greybox existentes: no se agregan techos físicos,
habitaciones, conectores, muebles funcionales ni obstáculos. No se recoloca
ningún objeto de cobertura, patrulla, spawn o enemigo. No cambios de exposición,
potencia, alcance, dirección, energía, activación ni presupuesto de luces.

## Implementación

`RoomEnvironmentProfileResource.visual_style` es opt-in, null por defecto.
Sólo VarkhemRoomEnvironment activa VarkhemVisualStyle.tres. Después del paso A2
de materiales iluminados, VarkhemVisualStyler aplica presentación estática:

- Suelo gris verdoso neutro, paredes gris industrial, marcos y carcasas oscuros.
  Se elimina el dominante cian del greybox para leer mejor las luminarias y el rojo.
- Materiales compartidos por paleta DENTRO de cada generación, roughness0,85.
  Se conserva la emisión mínima de legibilidad resuelta en A2: ambiente×0,06.
  No se añaden aportes al LightingManager ni luces reales para esa legibilidad.
- Franjas pintadas de suelo/pared, un ArrayMesh batched por módulo. Sólo sobre
  suelo y paredes sólidas existentes, nunca sobre una puerta abierta. No marcan
  el camino correcto hacia EXIT ni inventan rutas alternativas.
- Un rótulo de pared por módulo semántico compatible; texto sin billboard ni
  no_depth_test. Stencil tenue legible, sin luz emitida al entorno ni sombras.
- Luminarias: difusor existente ampliado y carcasa simple sin collider/sombra.
  `set_active()` sigue siendo dueño del difusor y del SpotLight original.
- COMMAND_ROOM: paneles y marca táctica existentes conservados. El rótulo gigante
  flotante heredado se oculta, sin destruir su nodo, y se sustituye por señal
  de pared MANDO/CONTROL, por encima de los paneles existentes. Guardias pueden
  ocultar la señal según la línea de visión real; no se dibuja a través de ellos.

| Semántica real | Identidad |
|---|---|
|CORRIDOR/no semántica|Carriles laterales y franja funcional gris/oliva|
|BARRACKS|Oliva claro; BARRACAS/PERSONAL|
|ARMORY|Óxido/rojo apagado; ARMERIA/SEGURIDAD|
|FOOD_STORAGE|Ocre; DEPOSITO/SUMINISTROS, datos existentes preparados|
|PRISON|Rojo apagado; DETENCION/RESTRINGIDO|
|CENTRAL_HUB|Azul grisáceo; DISTRIBUCION/BASE|
|COMMAND_ROOM|Dorado militar; MANDO/CONTROL y paneles existentes|
|VARKHEM_ROOM/BASE_ACCESS|SERVICIOS/BASE y ACCESO/BASE|

No existe una nueva sala CONTROL: COMMAND_ROOM reutiliza esa función visual.
FOOD_STORAGE está definido en el arquetipo, pero no apareció en las cuatro
configuraciones de la matriz visual; su apariencia NO se declara validada allí.
PRISON usa datos existentes; su validación visual específica también queda pendiente.

## Variantes y coherencia

OPERATIVA conserva todas las fuentes seleccionadas activas. REDUCIDA conserva
el apagado/potencia A2; no se simula reducción oscureciendo el mundo por separado.
EMERGENCIA conserva fuentes rojas localizadas y pinta franjas/rótulos ALERTA en
el escenario existente. Las franjas son pintura identificadora, no nuevas luces.

Todas las adiciones son MeshInstance3D/Label3D sin física ni source proxies,
con cast_shadow OFF. No pueden bloquear raycasts, navegación o luz lógica.
Las paredes/covers físicos siguen proyectando sombras según A2. No se añade
SSAO, partículas, glow, shaders, posprocesado, animaciones o fuentes de ruido.
La emisión de lectura y los rótulos no equivalen a exposición lógica; el sistema
comparte las mismas fuentes activas, no pretende correspondencia fotométrica.

## Validación funcional

- Matriz comparativa final:65001/02/03 GROUND y65006 BASEMENT, O/R/E; baseline A4
  (visual_style=null sólo en memoria), B y repetición B:36 generaciones objetivo.
 65006 incluye además la generación previa de GROUND para llegar a BASEMENT.
  PASS/EXIT_0: misma firma de módulos, topología, contenido/población/patrullas,
  covers, NavMesh/vértices/polígonos; exposición idéntica en centros y offsets;
  transform, energía, color, alcance, cono, sombras y activación de cada fuente
  iguales. Luces visuales=fuentes lógicas. Repeticiones sin acumulación de nodos.
-14 regresiones acotadas: curva A4; percepción O/R/E; DROP; P0-R2 close/wall_close/
  pair Horvex; combate/reset; debug/combate P3-B1; Varkhem físico65001–65006 y
  determinismo (9 sectores,28 ensamblajes); Ship3 tamaños; Horvex66001–03/8 sectores;
  matriz visual.14 PASS funcionales,13 EXIT_0/1 NATIVE_AV después del PASS close.
- La matriz final reforzada se ejecutó nuevamente después de terminar la
  presentación: PASS/EXIT_0 (`validation_final.log`), sin relajar asserts.
- Replays reales A4/B:65001 BARRACKS HIGH p0 conserva secuencia completa PASS,
  39,73 s;65003 misma estrategia conserva FAIL por VISION a2,18 s.4 EXIT_0.
  Son dos éxitos y dos FAIL de ESTRATEGIA, no regresiones ni rutas imposibles.
  No se repitió toda A3 ni se certifica infiltración completa de cada sector.

No se volvieron a modificar IA, percepción, FOV, LOS, ruido, combate ni recompensas.
Los fixtures originales conservan sus aserciones. No certificación integral ni Android.

## Evidencia visual

Artefactos locales en `../artifacts/varkhem_v2_3_b/`:

- OPERATIVA_A4/B.png, REDUCIDA_A4/B.png, EMERGENCIA_A4/B.png:
  misma BARRACKS65001, cámara y960×540. Luminaria/carcasa, franja y rótulo visibles;
  rojo de EMERGENCIA se lee sobre superficie neutra. REDUCIDA sigue más tenue,
  aunque un punto concreto puede recibir luz de otra fuente activa.
- command_final_OPERATIVA/REDUCIDA/EMERGENCIA.png: COMMAND65003. Captura frontal
  incluye guardia real, que oculta parcialmente el rótulo; no se lo elimina para
  fingir visibilidad. Paneles/marca táctica y franja diferencian la sala.
- ARMORY_65002_OPERATIVA.png, CORRIDOR_65003_OPERATIVA.png:
  identidad de seguridad y circulación longitudinal.
- TOP_65003_A4/B.png: mismas posiciones y footprint, comparación global.

13 vistas finales seleccionadas: todas captura válida/EXIT_0. Render Mobile de
escritorio RX570, no dispositivo Android. Cámaras congeladas y debug oculto sólo
en el probe para aislar presentación; no es un control de juego ni de UI táctil.
Primeras capturas/rótulos oscuros y Command con billboard se conservan como
evidencia de iteración, no como resultado final.

## Coste observado

| Medición comparable | A4 | B |
|---|---:|---:|
|BARRACKS65001: luces instanciadas|7|7|
|Nodos de esa escena|676|705 (+29)|
|Objetos de ese render|3341|3288 (3285 en E)|
|Draw calls, misma vista local|23|30 (+7)|
|Vista superior65003: luces|8|8|
|Draw calls, misma vista superior|187|220 (+33)|
|Nodos vista superior|826|860 (+34)|
|Objetos vista superior|3672|3599|

En la matriz: +29/+30/+34/+31 nodos según escenario; una malla de marcas por
módulo, una carcasa por fuente existente y2–5 rótulos. Los objetos bajan58–80
en esas muestras; no equivale a reducción garantizada de memoria. Los materiales
se reutilizan y no se retiene una caché estática entre sectores.

Pasada aislada final de generación+nav-ready: escenarios de un sector399,50 ms
baseline/396,85 ms B promedio; no evidencia de coste sostenido mayor, tampoco
optimización demostrada. Incluyendo escenarios de DOS sectores65006:507,82/506,24 ms,
máximos838,97/851,35 ms. No mezclar esos máximos con el tiempo de un único sector.
Memoria estática puntual B−baseline:−35.076 a+129.592 bytes en los ejemplos;
no es prueba de fuga ni benchmark estable de memoria/GPU.

Frame medio~16,65–16,68 ms con VSYNC/driver; máximo30,55 ms en REDUCIDA B local,
registrado sin atribución causal. Vistas adicionales llegan a199 draw calls según
frustum. No se extrapolan los7 draws locales a todo el sector ni se declara margen
para Cardboard. Límites geométricos derivados:≤12 triángulos de pintura por módulo,
12 por carcasa; texto depende de glifos. No son garantías de rendimiento.

## Archivos y preservación

Productivos modificados: RoomEnvironmentProfileResource.gd,
VarkhemRoomEnvironment.tres y RoomEnvironmentBuilder.gd (hook opt-in).
Nuevos: VarkhemVisualStyleResource.gd/UID, VarkhemVisualStyle.tres,
VarkhemVisualStyler.gd/UID. Fixtures nuevos: v23b_visual_validation,
v23b_render_probe y v23b_staged_audit, con sus escenas. Este informe.
Se conservan UID de las dos clases productivas nuevas. Se retiraron únicamente
ocho UID temporales creados al importar harnesses A3/A4 que no los versionaban;
Godot puede regenerarlos. No se eliminó ningún archivo previo de otro worktree.

Se preservan pilotos con errores propios de esta implementación/harness:
Color .tres sin alpha explícito; variable footprint duplicada en render probe;
asignación directa a preload constante en wrapper staged. Se interrumpieron
procesos que no podían cargar la escena, se corrigieron esos errores localizados
y se conservaron logs. No se cuentan como PASS ni se ocultan los fallos anteriores.

28 otros worktrees/5463 archivos protegidos sin modificaciones. Main y A4 intactos.
No se tocó LightingManager, Enemy, Player, familias/candidatos de covers, perfiles
de luces, ModuleDefinitions, solver ni datos de población. Sin staging ni commit.

## Pendientes

Android/Cardboard: contraste en pantalla real, texto y confort visual, sombras,
draw calls/GPU, térmica y cambio de seeds. Puede requerir simplificar señalización
o carcasas tras medir; no introducir luces ni alterar exposición para compensar.
El kit sigue sin remodelación de techos/arquitectura: cualquier intervención
estructural o distribución nueva requiere otra autorización. Revisión visual
específica de FOOD_STORAGE/PRISON y más fases de patrulla: INCOMPLETE.
NATIVE_SHUTDOWN_AV y Safe save failed siguen ABIERTAS, sin investigación.
STOP. No paquete móvil, publicación, merge ni siguiente fase automática.
