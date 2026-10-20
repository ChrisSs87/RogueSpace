# Qué enviar a cada IA — 2026-10-20

Leer [AI_CONTEXT](ROGUESPACE_AI_CONTEXT.md) y [AI_HANDOFF](ROGUESPACE_AI_HANDOFF.md).
[DocumentosDrive](https://drive.google.com/drive/folders/1lvcoZe49SnP__2p1kO_M9A_WmMpAsW-g).
[PACKAGES](https://drive.google.com/drive/folders/1xNt8Rf_M_hQrobTg4Zvn8MKHF1seS1bS).
Verificados con cuenta conectada;no se cambiaron permisos ni se garantiza acceso
público/desde otra cuenta. Confirmar acceso de cada IA antes de asignar.

**Revisión,no proyectos Godot importables.** Sin.git,.godot,credenciales,builds
o proyecto entero. ORIGINfijaversiones yMANIFESThashporarchivo. No superponer
SOURCE/<rama> para integrar. COMMONes instantánea documental71f5044e2e74375296a49e1f5a13f52f457f4857;
handoff/índiceexternos contienen cierreposterior. Contextocomún breve se repite
intencionalmente para adjuntosautosuficientes DeepSeek,no duplicación del juego.

|Paquete|Archivos|Bytes|Base funcional|
|---|---|---|---|
|[RogueSpace_AI_NARRATIVE_20261020.zip](https://drive.google.com/file/d/1VXSqkQoROd-FGqjmvRom9h8h1qiyVMHZ/view?usp=drivesdk)|16|66578|motion5a49cbd|
|[RogueSpace_AI_HORVEX_ART_20261020.zip](https://drive.google.com/file/d/1QXGVq6CxEgonC0bt2UzJUDtpR-6zDWKI/view?usp=drivesdk)|16|69279|ceilinged661c8+F16700e93|
|[RogueSpace_AI_OXYGEN_COMBAT_20261020.zip](https://drive.google.com/file/d/1WCKdy4iGFdWQ_X3dtW2VoWrjuygMZ5_J/view?usp=drivesdk)|20|53843|oxygen75c1148|
|[RogueSpace_AI_CODE_REVIEW_20261020.zip](https://drive.google.com/file/d/1L5-jLOwthsXkslQEBsa4nZemznfoMjW9/view?usp=drivesdk)|18|68359|integración31044975+F16700e93|

SHA256,en orden:

- NARRATIVE:`CD5985262B6676F64DF1B48614A42BF5E015602D38865283A821418EB3312265`
- HORVEX_ART:`7562A9677264F3522D8448DCF5977432F22F3789891075D26895A5BCB67C58D6`
- OXYGEN_COMBAT:`338156DCE01AD0E44854FD4465614007786972B5442F4553E7A29B307A95C6AB`
- CODE_REVIEW:`327FC5DBFECE593E0E0D072BAA8208A77A0BB9EA7C9C839DE838BE270BBDBC41`

CRC ymanifestcomparados contra bytesfuente:PASS. Subida/metadataDrivePASS y
los4ZIPdescargados realmente tienenSHA256idéntico. No se infiere sólo del tamaño.
Ubicación local exacta: `C:/Users/chris/OneDrive/Documentos/RogueSpace/artifacts/master_queue_20261020/review_packets/`
seguida del nombre de tabla. PACKAGES.json registra fuentes/hashes;script
build_review_packets.py en carpeta superior usa whitelist yno sobrescribe ZIP.
Las descargasverificadas se llaman download_<DISCIPLINA>.zip.

## Gemini — narrativa y arte

Acceso indicado:Drive,NOasumirGitHub. Enviar URLsdecontexto yNARRATIVE/HORVEX_ART.
IncluyenJSON/SVGplaceholderlocales,capturasmono/preview800×480,scripts/fixtures,
informes ymapas de centrosF1. No son especificacionesGemini ausentes niPNGcanónicos.
Pedir revisión de legibilidad/subtítulos yassets reales para fases deAvispa/paneles,
sin alterarhitbox/HP/percepción/cámara. Entregar licencia/origen de arte. Preview
2ojos no equivale aCardboardvalidado;mapa de centros no es geometría renderizada.

## DeepSeek — O₂/combat

Sin acceso persistente:descargar OXYGEN_COMBAT yadjuntar en cada sesión con el
encargo. Incluye6fuentesmodificados,CEM/EventBuscontexto,fixture,findings,checkpoint
ylogs finales/costes/doble. Auditar reentrancia run_ended,costecombat_ready,
suspensión/abort ydenegación de rewards tras terminal. Separar defecto demostrado
de hipótesis. Guardado adisco ausente:no inventar SaveManager ni modificar costes.

## Claude/Copilot — código

Confirmar acceso aChrisSs87/RogueSpace,rama ySHA. Rama documental pública no trae
31044975 ni experimentos. B+C1público2e6e669 es otra versión. EnviarCODE_REVIEW y
paqueteespecífico:SOURCE/integrationcontieneP0+DEBUG,SOURCE/F1contieneplanner/
director/stage/matrices. Son versionesindependientes,NO capassuperponibles.
Pedir hallazgos citandofunción/archivo/SHA,prueba reproducible eimpacto;no solicitar
auditar código ausente del remoto ni autorizar merge/push automático.

## Codex/coordinación

Basesfuncionalesindependientes31044975. Unownerporarchivo,alcance escrito,
checkpointdurable,pruebas conterminal yproceso separados. No usarF1porcomodidad.
LospaquetesNOincluyen toda la dependencia paraejecutarGodot:se requiere clon
completo delSHAcitado. V2/V3 no pruebanAndroidV4niCardboard. Integración yLATEST
siguen protegidos;lospaquetes de revisión no son aprobación funcional global.
