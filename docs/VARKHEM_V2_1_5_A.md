# Varkhem V2.1.5-A — postura y coberturas lógicas (experimental)

Base: c79260642ec672beab241489da9262c1e104f4ac.
Rama: feature/varkhem-environmental-stealth-v2-1-5. Sin commit/publicación.

## Arquitectura

Player: STEALTH implica cápsula agachada; WALK/RUN solicitan postura erguida.
Cápsula original: radio 0.40 m, altura 1.70 m. Agachado: altura 1.10 m, mismo
radio y mismo apoyo de pies. Se duplica el Resource por Player para evitar
mutación compartida. No se mueve/rota el cuerpo al cambiar postura.
Head baja de offset Y +0.60 a 0.00 m, a 2 m/s (transición de 0.30 s).
No se altera pitch/yaw, ruido, velocidades ni oxígeno. Las dimensiones son
parámetros iniciales de postura, no categorías de cobertura.

Al solicitar levantarse se consulta la cápsula erguida real contra las capas
de colisión existentes, excluyendo sólo el propio Player. Sin espacio se
conserva postura y estado efectivo STEALTH; se reintenta al tener espacio.
Margen de consulta 0: inflarlo 1 mm incluía el suelo a la separación normal
de apoyo de aproximadamente 0.23 mm. No se achica la cápsula ni se desactivan
colisiones. El selector móvil conserva el modo solicitado; si el techo lo
impide, puede mostrar WALK/RUN mientras el estado efectivo sigue STEALTH.

LogicalCover: script para un StaticBody3D de prop dedicado. Asignar Category
HIGH/MEDIUM/LOW en Inspector y autorar visibility_volume (AABB LOCAL) ajustado
al espacio de interposición del objeto. El volumen no se infiere del modelo.
El cuerpo y su CollisionShape3D siguen siendo obstáculos físicos normales.
No poner el script en un cuerpo que también contenga una pared independiente:
la categoría gobierna toda la visibilidad de ese cuerpo.

- HIGH bloquea el segmento visual en ambas posturas.
- MEDIUM bloquea sólo cuando Player.is_crouched() es verdadero.
- LOW no bloquea visión.

Enemy conserva rango, FOV, iluminación y exposición progresiva como gates
previos. Sólo el test de LOS visual consulta LogicalCover: transforma el
segmento ojo→Head a coordenadas locales y verifica intersección real con el
volumen. Categoría no otorga invisibilidad fuera de esa interposición.
El raycast físico excluye los cuerpos etiquetados de cobertura para que el
alto del modelo no contradiga la categoría; las paredes/puertas no etiquetadas
siguen usando su colisión real. La consulta de LOS de slots de combate y la
navegación/clearance físico NO excluyen estos props.

El volumen es 3D, no una máscara infinita vertical. Autorarlo de manera
conservadora y comprobar alturas/planta/rotación: un volumen excesivo podría
ocultar fuera del objeto; uno pequeño puede dejar escapar el rayo. No hay
generación procedural de coberturas ni nuevos ruidos/iluminación.

## Datos de visión

Sólo Resources canónicos Varkhen:

- orco_melee: 7 m / 120° → 10 m / 105°.
- orco_picaro: 9 m / 120° → 10 m / 105°.

tile_size_m vigente = 1. Se usa el extremo inferior propuesto para probar
ampliación conservadora sin modificar START/población. Curvas de luz,
detection_time=1 s a capacidad completa y oído intactos. Con luz lógica 1 y
capacidad 15%, confirmar requiere unos 6.67 s; no debe confundirse ALERT con
CHASE. Recursos Horvex y demás especies intactos.

## Escenas

Manual: scenes/tests/VarkhemV215CoverTest.tscn.
Guardia real, Player real, navegación de prueba rodeando tres props físicos:
izquierda HIGH, centro MEDIUM, derecha LOW. Alturas visuales deliberadamente
distintas y no ordenadas por categoría: HIGH 1.3, MEDIUM 1.7, LOW 2.1 m.
Volumen lógico por prop: 2×3×1 m, base a nivel del suelo.
Espacio libre lateral; controles TouchControls, CombatUI y RewardUI existentes.
No cambia la escena de inicio productiva. Godot Android/Cardboard: usar MODE
WALK/RUN/STEALTH existente, sin botón separado de crouch. La comodidad real
del descenso de cámara requiere revisión en dispositivo.

Automática: scenes/tests/varkhem_v215_cover_validation.tscn.
Matriz de seis combinaciones, lateral abierto, paredes normales, techo real
con registro físico previo, recuperación al retirarlo, ciclo móvil mediante
contrato público, rotación de cámara inalterada, ruta sobre NavigationMap y
confirmación progresiva del jugador agachado expuesto a 8.5 m. Su plazo se
deriva de la capacidad de luz real. No fuerza estados de detección/CHASE.
Durante la matriz se inmoviliza sólo el movimiento del guardia para aislar
LOS; su Timer de percepción permanece activo. Movimiento/encounter completo
se valida adicionalmente con regresiones existentes, no se presenta esa
matriz como prueba de locomoción del guardia.

## Límites

- Sin distribución procedural, integración de props con módulos ni bake nuevo
  de producción. Colocar props futuros requerirá incluir sus colisiones en el
  pipeline de navegación y validar espacios, no modificar el solver.
- Consulta lineal de los props etiquetados por tick sensorial; suficiente para
  esta escena pequeña, sin garantía de rendimiento para cientos de coberturas.
- No hay muestreo de silueta/porcentaje de exposición: un segmento y categoría
  declarativa. Comportamiento parcial en bordes requiere evaluación manual.
- Player comparte postura global; los rangos cambiados son sólo Varkhen.
  Coberturas son genéricas para cualquier Enemy si se autoran en su escena.
- NATIVE_SHUTDOWN_AV sigue abierta e independiente. Safe save failed del editor
  sigue documentada; no se cambia configuración del SO/editor para ocultarla.
- Bajón FPS transitorio al cambiar seed sigue pendiente, no investigado aquí.

Resultados exactos, logs históricos de desarrollo y ledgers:
artifacts/varkhem_v2_1_5, fuera del proyecto. No CLOSED/PASS Android, ZIP,
commit, push ni merge en esta etapa.

## V2.1.5-A.1 — separación manual y ALERT acotado

La observación Android de MEDIUM de pie no se reprodujo con FOV válido:
la matriz A previa y la ampliada A.1 pasan. El raycast físico visual ya
excluía los cuerpos LogicalCover antes del feedback; no se altera esa regla
ni la de paredes. Se agrega diagnóstico de categoría/interposición y una
prueba con FOV inválido que demuestra NONE/FOV:NO/COVER:N/A, seguida de
readquisición normal al restaurar el FOV. No se atribuye esa causa al caso
Android sin una reproducción equivalente.

VarkhemV215CoverTest ahora arranca en COVER: guardia inmóvil, orientación
fija -Z, Timer sensorial normal. HIGH/MEDIUM/LOW/OPEN reinician un fixture
limpio en cada carril. COVER / CHASE alterna con un guardia móvil real.
VarkhemV215ChaseTest arranca directamente en CHASE. DEBUG alterna
compacto → completo original → oculto. Compacto: STATE/DIST/FOV/LOS/COVER/
POSTURE; COVER N/A significa que distancia/FOV impidieron evaluar LOS.
BLOCK/PASS indica interposición lógica y su efecto, no visión confirmada.
La confirmación sigue dependiendo de exposición y luz.

Antes: ALERT llegaba a LAST KNOWN (o recibía NO PATH), quedaba quieto hasta
lose_target_timeout_sec y retornaba a PATROL/IDLE.
Ahora: sólo los dos Resources Varkhen optan en alert_search_point_count=2.
EnemyResource define defaults inertes count=0 para otras especies; radio
inicial 1.5 m, pausa 0.4 s, giro 120°/s. Al comenzar búsqueda se prueban
hasta ocho direcciones fijas alrededor de LAST KNOWN, relativas a la mirada.
Se aceptan como máximo dos puntos distintos con proyección cercana, ruta
real en NavigationServer3D y cápsula física libre. No usa Player ni RNG.
Si no hay puntos viables, mantiene inspección limitada por timeout.

El movimiento usa _move_toward_point existente; mira hacia cada objetivo
durante la pausa y hacia su desplazamiento físico al avanzar. NO PATH omite
ese punto, no insiste infinitamente. Todo cabe dentro del timeout existente
de 5 s; no lo extiende ni garantiza visitar dos puntos en cualquier geometría.
Si acaba antes, observa durante el tiempo restante. Nueva VISION/SOUND
descarta los puntos y conserva la actualización sensorial normal de LAST
KNOWN. Suspensión de combate sigue congelando tiempo/posición/timers.
No se cambia CHASE, APPROACH, DROP ni la protección de reentrada.

El harness V213 conserva todas sus comprobaciones pero registra la llegada
a LAST KNOWN como evento acumulativo: inspeccionar después un punto cercano
no borra evidencia de que llegó. No exige permanecer estacionado en A.
El harness nuevo comprueba llegada, dos puntos deterministas, desplazamiento
físico (~3.47 m en fixture abierto), orientación, retorno y memoria sin
omnisciencia mediante ticks normales. Las escenas manuales no sustituyen la
revisión Android. Resultados y logs A.1 en artifacts/varkhem_v2_1_5/a1.
