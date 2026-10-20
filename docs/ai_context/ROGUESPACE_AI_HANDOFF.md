# ROGUESPACE_AI_HANDOFF

Fecha2026-10-20. Fuente de coordinación portable, no STATUS alternativo ni
aprobación de integración. V=verificado archivos/Git local en esta tarea;
R=evidencia anterior leída;U=observación comunicada por usuario;P=pendiente.
Ver [contexto](ROGUESPACE_AI_CONTEXT.md) y [README](README.md).

## Inventario por SHA, no por nombre de carpeta

|Línea|Rama/SHA verificado local|Estado|
|---|---|---|
|Estable|main 8bc3e890d5983700db9465fa41c3607cb3b831a9|V:intacto;no incluye automáticamente desarrollos recientes|
|B+C1|develop/varkhem-v2-3-gameplay 2e6e6691441fced41b3664b65ece729f9392c21f|V:publicado,percepción/luz/control;no P0limpieza posterior|
|Integración|integration/varkhem-v23-bc1-p0-debug 31044975c0f62c4e2e6b3d5393fa422454826f4d|V:local,P0limpieza+ENCDEBUG+continuidad;bundleportable anterior comunicado|
|Horvex H1–H3|fix/horvex-organic-recovery-h1-h3 e294658104cc0fdb003855c4a85499a2f4223712|R:orgánico/población/selector;referencia protegida|
|Horvex D.3|experiment/horvex-branch-chambers-v1d3 2589da75bd6d1c87893284ad51b904f583c20599|V/R:base técnica,no aprobación visual general|
|Horvex E|experiment/horvex-labyrinth-v1e c7e45b0d7d9c5705a2c62b49150e019d9d36b88f|V/R:rechazado,66041Deep físicoFAIL,sinZIP|
|Horvex F|experiment/horvex-spatial-topology-v1f f49edffcf735e415dcb1aa2d64aea04db69f9783|V/R:8/12,montaje66041DeepPASS,4planesrechazados,sinZIP|
|Horvex F.1|experiment/horvex-spatial-topology-v1f1 6700e933d720710ee2185c1cc363593b0b6aa873|V/R:12/12+4/4PASS técnico,NOintegrado|
|Visión18m|experiment/enemy-vision-18m-p1 1665347c26f4f73048aff30301dd11b8ed8f7cb8|R/U:candidato aparte,no integración|

Worktrees bajo `C:/Users/chris/OneDrive/Documentos/RogueSpace/`:
varkhem_bc1_p0_debug_integration_worktree,horvex_recovery_h1_h3_worktree,
horvex_v1d3_worktree,horvex_v1e_worktree,horvex_v1f_worktree,horvex_v1f1_worktree.
V1D original y official_repo/V1B.3A contienen cambios ajenos protegidos: no limpiar.
C2radio2,0m sigue separado/provisional. CachéNavMeshP3-B3/P2-C-F rechazados.

## Verificación remota actual

Consulta real `git ls-remote --heads origin` acotada desde Windows,EXIT_0:
main8bc3e890 y develop/varkhem-v2-3-gameplay2e6e669 confirmados.
Destino docs/roguespace-ai-context AUSENTE al preparar la publicación.
develop/varkhem-v23-bc1-p0-debug AUSENTE en esa consulta:la integración31044975
NO debe presentarse como disponible en GitHub. No publicar código para compensarlo.
Ramas experimentales locales no se asumen remotas. Acceso de lectura no prueba
permiso de push;el resultado de publicación documental se agrega al cierre.

## V1F.1: pruebas y riesgos concretos

Verificados checkpoint,summary.json,validation.json y package_verification.json
del worktreeF1. Resultados previos NO reejecutados en la TAREA0:
12/12sectores objetivo66041/66038/66039/66040/66054/66037×Upper/Deep y4/4extras
66042/66055;geometría/nav/cápsula/slots,población5/8,determinismo PASS.
10regresiones PASS.26procesosGodot:20PASSfuncionales,3diagnósticos completos,
**3importacionesINCOMPLETE**,26EXIT_0,0NATIVE_AVen esa serie.

Imports incompletos exactos:import_console.txt (worktree nuevo),
reference_import_console.txt (copia F para diagnóstico),package_import_console.txt
(ZIP extraído). Los tres devolvieronEXIT_0,pero registran preferencias/editor
settings sin ruta y Safe save;otros runtime fallan al escribir user://logs.
No se ocultaron ni se declaró importación limpia. NATIVE_AV histórico no resuelto.
Logs en artifacts/horvex_v1f1_20261020,normalmente fuera de Git.

Corrección F1 d2c2bf1:preflight tallo/fork/dos salidas,antes de consumir frontera.
Sin másintentos,márgenes menores,solver global ni prefijo largo.
Tradeoffs:ramas de4–7nodos;algunas bajan8→4;66037Upper2→1fork secundario.
Ruta crítica32–47%;66041Deeprecta46→62m;extras hasta71m.0circuitos,no confundir
árbol ramificado con loops.16siluetasdistintas no certifican calidad jugable.

O₂66041real aislado:crítica23,55,desvíos41,31,extensa103,24solicitado(cap100).
IA desactivada sólo para medir locomoción;combates hipotéticos documentados aparte.
O₂cero aún permite continuar. No existe derrota/guardado ambiental global validado.
FDeep8Avispas en ramales a≥15,2m de ruta,fuera de visión11m;0combates reproducido.
F1Deepencuentroindividual con centinela en ruta;no se certifica ratio de dobles.

## Artefactos móviles

F1 ZIP fuentec79435e7c572d9511ba5ef1263aeb959cc1ee772,documentación final6700e93:
`RogueSpace_Horvex_V1F1_TEST_MOBILE.zip`,775111bytes,822archivos.
SHA256 `0A9F680AA639B86D23677BF4ED267D049855EFDDBCC746136A192674CB65BF4C`.
[Drive experimental verificado](https://drive.google.com/file/d/1gRQ_Ro4qjpXEU4uHEZL5t3aBSYVa_sRy/view?usp=drivesdk).
CRC/extracción/referencias y descarga conhashidéntico confirmados en evidencia.
Fuente limpia;único override del paquete:main_scene→HorvexSpatialV1FExperienceTest.
Arranque extraídoPASS/EXIT_0;no prueba Android/Cardboard en esta sesión.
LATEST permanece intacto, no asumir que apunta aF1. Otros ZIP/hash se omiten si
no se verificaron ahora;solicitar manifiesto antes de redistribuirlos.

## Cola maestra, responsables y dependencias

|Tarea|Estado al iniciar|Base/alcance/aceptación|
|---|---|---|
|0 contexto y publicación|PASS|docs/roguespace-ai-context desde main;SOLO estos3MD;Drive+GitHub verificados|
|1 derrotaO₂|PARTIAL|experiment/oxygen-defeat-v1,75c114870b98bb92bd2d1b1ea2dea79f000190a2;runtimePASS,persistenciaBLOCKED|
|2 motioncomics|PARTIAL|experiment/motion-comics-v1,5a49cbd43c6d5ff6224575a899f23b8fb5ed0877;MVPaisladoPASS,sin integración/VRcert|
|3 Avispa techo|PARTIAL|experiment/horvex-ceiling-wasp-v1,ed661c874a99b3b5f3efa2c42988e845c9a7a6f7;secuenciaPASS,QA móvil/rearme pendientes|
|4 calidadF1|PASS INFORME|sólo lectura6700e93;ver revisión de16casos abajo;no prueba móvil nueva|
|5 paquetes porIA|PASS|4ZIPenDrive,CRC/manifest ydescargaSHAidénticos;índiceWHAT_TO_SEND_EACH_AI.md|

Cada tarea debe dejar commit+checkpoint incluso ante bloqueo. No encadenar
bases funcionales:ninguna tarea independiente hereda F1 accidentalmente.
Tras cada una,actualizar este HANDOFF sólo desde la rama documental o producir
suplemento separado para evitar contaminación. No se autorizó integración.

Abiertos:NATIVE_AV,cierre nativo/Safe save,congelamiento doble original(candidato
con pruebaAndroidpositiva,no resolución universal),calidadespacial/O₂,presión
Horvex,Cardboard,CommandRoom,linterna,Suraan,Avispa techo no implementados aún.

## Incorporación de otra IA

Gemini:enviar carpetaDriveAI_CONTEXT y archivos exactos de la tarea;no GitHub.
Claude/Copilot:confirmar acceso y SHA;si necesitan31044975/F1,adjuntar fuentes
o respaldo autorizado porque GitHub B+C1 no los contiene. DeepSeek:adjuntar
contexto+handoff+fuentes/fixtures concretos cada sesión. Nadie deduce implementación
por un diseño. Declarar archivos,autoridad,base,pruebas,riesgos y condición STOP.

## Cierre TAREA0 — disponibilidad comprobada

Push normal autorizado completadoEXIT_0. SHA remoto verificado inicialmente
`64213b67bd8e9dda10650b440905c1bf0e811bff`;los commits siguientes sólo actualizan
estos documentos. Main remoto permanece8bc3e890, sin merge/PR/forcepush.
[Rama documental](https://github.com/ChrisSs87/RogueSpace/tree/docs/roguespace-ai-context/docs/ai_context).
Los3archivos se consultaron por conectorGitHub;no sólo se asumió éxito del push.

[CarpetaDriveAI_CONTEXT](https://drive.google.com/drive/folders/1lvcoZe49SnP__2p1kO_M9A_WmMpAsW-g)
creada en la carpeta oficial RogueSpace, sin mover/borrar archivos previos.
Tres subidas y readbackmetadata MIME/tamaño/parent verificados:
[README](https://drive.google.com/file/d/1_S4PuFgDJssLFV5bZ8AMmgEs8wezMlS5/view?usp=drivesdk),
[AI_CONTEXT](https://drive.google.com/file/d/1FSGEM6t28X__zkyho9zd8_ePZmjqmt4d/view?usp=drivesdk),
[AI_HANDOFF](https://drive.google.com/file/d/1j7cPFYlqMBCtNsy1l2K6SJ9_zfzmx4_C/view?usp=drivesdk).
Lectura textualREADME confirmócontenido;fetchtextualContextseinterrumpiópor demora
sin repetirindefinidamente. Su disponibilidad se confirmópor metadata, no por
comparación byte-a-byte de descarga. Son archivosmarkdown originales,noDocs
convertidos. Se usan IDsestables al actualizar;no hay servicio automático instalado.
La víaGitWindows con acceso de red sí funcionó hoy;esto no demuestra que el
fallo histórico getaddrinfo haya desaparecido de todos los entornos.

## Cierre TAREA1 — O₂

Base31044975,commits6ba8dae(runtime6archivos) y75c1148(fixtures+checkpoint).
Worktreeoxygen_defeat_v1_worktree limpio. RunState.is_run_terminal/end_run y
señalrun_ended,guardas de combate/rewards,suspensiónterminal,UIderrota existente.
Cinco controles finalesPASS/EXIT_0:agotamientoPlayerreal,admisiónconO₂insuficiente,
repetición/late_win,recompensapendiente,cierrecombate,recargaescena,nueva run;
regresionescoste,mobilepair,OMITIR yC1. ImportaciónEXIT_0conSafe save,INCOMPLETE.
PrimerfixturePASSconcoroutines por teardownprematuro;corregido sólo fixture y
repetido sin esos errores. No esconder la primera consola.
No SaveManager/guardado-run en base:DISKPERSISTENCEBLOCKED,no formato inventado.
Falta prueba en dispositivo y contrato ambiental/guardado general. No integración.
docs/tasks/VERIFICATION_FINDINGS.md yOXYGEN_DEFEAT_V1_CHECKPOINT.md en su rama.
Logs artifacts/master_queue_20261020/oxygen. Checkpoint es suplemento a esta ficha.

## Cierre TAREA2 — motion comics

Base31044975,5a49cbd,worktreemotion_comics_v1_worktree limpio. Cero archivos
existentes modificados. NuevoMotionComicPlayer,JSON2paneles,SVGplaceholder,
demo yfixtures.12checksPASS/EXIT_0 (dos ejecuciones),dos capturas800×480
deescritorioEXIT_0revisadas. ImportaciónNATIVE_AV(-1073741819),INCOMPLETE.
Pausa/avance/skip,cut/fade,paneo/zoom,subtítulos,fallbackassets,terminalúnica y
restauraciónde caller probado. AudiorealdispositivoNOprobado. La captura cierra
temprano y genera cancelación esperada;no es finalización normal de secuencia.
No pausa global del mundo ni guardado de vistos;calleradaptaownersexternos.
Previewdoble2D no equivale aXR/Cardboard;controlesmonoscópicos,rigpendiente.
docs/tasks/MOTION_COMICS_V1_CHECKPOINT.md;artifacts/master_queue_20261020/motion.

## Cierre TAREA3 — techo

Base31044975,ed661c8,worktreeceiling_wasp_v1_worktree limpio;sin Enemy.gd,
xenomorfo.tres,generador,combate ni percepción global modificados. HP30/visión11m.
Opt-inCeilingWaspV1 hereda temporizador/estímulos originales;bloquea candidato/
emboscada antes de suelo válido. Raytecho,descenso físicovertical,navanchor sólo
en suelo. Timeoutocupado→BLOCKED,sin rearmadoautomáticoimplementado.
Cuatro casos finalesPASS/EXIT_0(visión,sonidooculto,sintecho,aterrizajeocupado);
regresionespairHorvex/percepciónPASS/EXIT_0. Repeticiónvisión ydemobootEXIT_0.
ImportaciónEXIT_0conSafe saveINCOMPLETE. NoAndroid,navegacióntecho,spawnreal,
animaciones finales,proporción de dobles ni medida móvil. Demo reutiliza controles
Touch/CombatUI/RewardUI. docs/tasks/CEILING_WASP_V1_CHECKPOINT.md;
artifacts/master_queue_20261020/ceiling. Revisar antes de cualquier integración.

## TAREA4 — calidad V1F.1, revisión no destructiva

Fuente6700e93:comparison.json/csv,runtime.json,validation.json ycheckpoint.
Leídos ahora,sin ejecutar nuevamente los16mapas,sin editarF1o solver.

|Seed|Sector|Módulos|Crítica|Forks secundarios|Profundidadramal|Rectamáxima m|ms|
|---|---|---|---|---|---|---|---|
|66041|Upper|34|47,1%|3|4|50|481|
|66041|Deep|44|34,1%|2|5|62|663|
|66038|Upper|34|41,2%|2|5|27|500|
|66038|Deep|44|36,4%|4|7|56|696|
|66039|Upper|34|44,1%|4|5|52|457|
|66039|Deep|44|34,1%|3|7|46|668|
|66040|Upper|34|32,4%|2|7|46|488|
|66040|Deep|44|31,8%|6|6|58|700|
|66054|Upper|34|38,2%|2|7|27|460|
|66054|Deep|44|38,6%|2|6|44|702|
|66037|Upper|34|44,1%|1|4|50|471|
|66037|Deep|44|34,1%|2|5|27|698|
|66042|Upper|34|44,1%|1|4|54|498|
|66042|Deep|44|36,4%|3|6|71|745|
|66055|Upper|34|47,1%|1|5|35|518|
|66055|Deep|44|38,6%|4|7|62|710|

PASStécnico heredado/R,NO nuevoPASSAndroid. Tres imports incompletos detallados
arriba;V1F.1NOintegrada. No haycircuitos;16firmasdistintas no excluyen repetitividad.
La prioridad inicial favorece tallos rectos cuando las curvas no admiten fork;
riesgo de forma ortogonal/peine persiste. Profundidades8→4/7→5 yfork2→1 son
regresiones locales de variedad,no fallos de nav;no aumentar el mapa para ocultarlo.
Recta66041Deep46→62 yextra66042Deep71 requieren inspección de experiencia.

Puestos/rutas:V1FDeep4parejas fuera de ruta quedaron≥15,2m (visión11m),sin
encuentro;F1Deep tiene2centinelas+3parejas yactiva1individual enrutacrítica.
La selección de slots sobre nueva topología cambió,NO el presupuesto5/8. Faltan
recorridos completos de ramales yratio de dobles reales,no confundir grupos con
encuentros. O₂crítica23,55/desvíos41,31/extensa103,24:fixturelocomociónconAIoff,
combates estimados aparte;no run completa ganada ni O₂derrota integrado enF1.

RecomendacionesNOimplementadas:1)revisar variedad angular contextual conservando
preflight,márgenes y1intento;2)ponderar puestos en cámaras próximas a rutas y
ramales funcionales conservando presupuesto/contacto;3)gates de profundidad y
longitud de rectas basados enQA,antes de añadir bucles/tamaño/retries.

Protocolo QA móvil reproducible (P,NOejecutado):descargarZIPF1verificarSHA/ORIGIN;
registrar dispositivo,Godot,renderer,resolución.66041U/Dprimero,luego66038/39,
66037yextras66042Deep;mismaestrategiaWALK yotra exploratoria porseparado.
Registrar START/EXIT,colisiones,cámaras/ramales,tiempos,O₂antes/despuéssector,
posición deAvispas,CMparticipantes/objetivo,primera muerte/recompensa ylogs.
No resetear O₂ entresectores para medir presupuesto. Detener ante caída/bloqueo,
sin declarar imposible una ruta por una estrategia fallida. Cardboard requiere
sesión independiente sin giro forzado;no sustituir V4 por capturas de escritorio.

## Cierre TAREA5 y checkpoint global

[Índice de envío](WHAT_TO_SEND_EACH_AI.md):4ZIPcompactos conORIGIN,MANIFEST,
contexto,fuentes y evidencias. AI_CONTEXT/PACKAGESverificada;4subidas nuevas,
metadatareadback ydescarga real conhash idéntico. No sonproyectosGodotimportables
ni TESTMOBILE,no se tocóLATEST. COMMONdentrodeZIPfija commit71f5044,anterior a
cerrar publicación;estehandoff/índiceexterno contienen estadofinal. No reconstruir
paquetes para crear una falsa autorreferencia de hashes.

Tareas1–3 recuperadas en ramas independientes desde31044975,sin publicación de
código ni integración. Task4lee6700e93sin cambios. Sólo rama documental recibe
pushnormal. ActualizarDriveconlosmismos3IDs ysubiríndice;verificarGitSHA/metadata.
NingunaPR/tag automático. NATIVE_AVmotion,importaciones no limpias,persistencia
ausente yCardboard siguenabiertos;no cerrar por tener capturas/EXIT_0.

Próximaacción:revisión externaOXYGEN_COMBAT ycontrato persistente antes de
integrar;revisión de ownershipmundonarrativo;QAvisual/táctil techo sinspawn.
Nada autoriza merge,visión18m,C2nuevos,suspendernavencombateo reemplazarZIPestable.
