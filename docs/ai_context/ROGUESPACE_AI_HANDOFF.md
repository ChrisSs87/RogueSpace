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
|0 contexto y publicación|EN CURSO|docs/roguespace-ai-context desde main;SOLO estos3MD;Drive+GitHub verificables|
|1 derrotaO₂|NOT STARTED|rama independiente desde31044975,noF1;auditar antes;STOP si falta contrato persistente|
|2 motioncomics|NOT STARTED|otra rama desde31044975;MVP aislado,presentación no determina gameplay|
|3 Avispa techo|NOT STARTED|otra rama desde31044975;escenaopt-in,noResourceglobal/generador|
|4 calidadF1|NOT STARTED|sólo lectura6700e93;QA móvil y recomendaciones,no solver/retries|
|5 paquetes porIA|NOT STARTED|documental;adjuntables para DeepSeek,rutasDrive para Gemini|

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
