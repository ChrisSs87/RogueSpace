# V2.3-A2 — perfiles globales y variantes declarativas

## Recuperación y estado

V2.3-A recuperada LOCALMENTE en **956fadad8837f165a39fc4c45724368f1a63e51d**,
rama `feature/varkhem-v2-3`, worktree limpio. Incluye únicamente los 20 archivos
aprobados de iluminación, fixtures, UID y documentación de A/preparación.
Su validación Android sigue pendiente; recuperar no implica certificación integral.

A2: `feature/varkhem-lighting-architecture-v2-3-a2`,
`C:/Users/chris/OneDrive/Documentos/RogueSpace/varkhem_v2_3_a2_worktree`.
Base exacta: el commit anterior. A2 queda SIN COMMIT. Sin ZIP, push ni merge.
Main y las demás ramas no se integran. NavMesh cache P3-B3 continúa excluida.

## Recursos y consumidores

| Recurso | Contrato |
|---|---|
| BiomeLightingProfileResource | ID, arquitectura, ambiente 0–10, presupuesto, catálogo, reglas y variantes autorizadas |
| LightingSourceResource | Tipo de montaje, potencia 0–10, energía visual, alcance, dirección, color, enabled y puente de ganancia de habitación |
| LightingVariantResource | Fuentes autorizadas, probabilidad de encendido, multiplicador de potencia, color opcional y mínimo activo |
| RoomEnvironmentProfileResource.biome_lighting | Referencia opt-in, resuelta mediante el override sectorial ya existente |
| ModuleDefinitionResource.lighting_sockets | Puntos locales declarados id/mount/position/basis; sin efecto sobre assembler |
| RoomLightModelResource | Snapshot render/lógica reutilizado por RoomLogicalLight; dirección ahora configurable |

Los catálogos están en `resources/lighting/`: tres perfiles y nueve tipos de fuente.
Varkhem: `military_ceiling`, `military_wall`, `military_console`.
Horvex: `bioluminescence`, `natural_opening`, `luminous_tissue`.
Nythari: `torch`, `candelabrum`, `brazier`.

| Bioma | Ambiente 0–10 | Estado |
|---|---:|---|
| Varkhem | 3 | Consumido por VarkhemRoomEnvironment |
| Horvex | 1 | Datos preparatorios; NO conectado al Horvex productivo |
| Nythari | 2 | Datos preparatorios; sin dungeon, población ni percepción inventadas |

Las fuentes preparatorias tienen colores/alcances propios; no se crean escenas
de bioluminiscencia, aberturas, antorchas o braseros. Validación de esquema no
equivale a validación física de esos biomas.
Horvex productivo conserva ambiente legacy 1/5 (equivalente 2/10); el nuevo 1/10
del catálogo NO se aplica automáticamente. Su futura activación requerirá balance
y validación propios, sin inventar capacidades sensoriales.

## Pipeline único

Resolución sectorial existente → perfil de ambiente efectivo → validación de
arquitectura/variante → BiomeLightingBuilder → RoomLogicalLight/SpotLight3D →
LightingManager → adaptador de curva existente → Enemy.

`architecture_id` se compara con el ID real del arquetipo, no texto de HUD.
La variante se selecciona con `Stage6GProceduralPrototype.lighting_variant_id`;
vacío usa `default_variant` del perfil. Cambiarla requiere regenerar. IDs,
fuentes o sockets incompatibles no originan generadores alternativos.

LightingSocketProvider obtiene puntos de techo y pared desde el footprint real
del kit actual y puntos de consola sólo desde mobiliario CONSOLE realmente
creado. El montaje lateral queda separado del centro de la abertura de puerta.
Las fuentes no tienen collider y no participan del bake.
Columnas, aberturas y estructuras orgánicas requieren sockets declarados en el
ModuleDefinition real. No se infieren objetos inexistentes; su validación de host
visual/altura queda pendiente de sus futuros assets. El adaptador automático
techo/pared está calibrado para el kit Varkhem actual, no para cualquier edificio.

La selección usa RNG local con namespace seed/perfil/nodo/regla/socket. No usa
tiempo, posición del Player, estado de enemigos ni RNG de topología/mobiliario.
Misiones, facciones, objetivos y población no forman parte de este distribuidor.

## Reglas Varkhem

- Command Room: foco de pared prioritario, potencia 8/10, alcance 14 m.
- Destinos y hub semántico: luminaria de techo, potencia 6/10, alcance 7 m.
- Consolas reales: aporte suplementario 2/10 y 3 m, sólo donde ya existe esa familia.
- Circulación: candidatos de techo en CORRIDOR según profundidad con stride 3.
- START, EXIT y BASE_ACCESS excluidos. Sin colocación por casillero.
- Una luminaria primaria por módulo; suplementos consumen el mismo presupuesto.
- Máximo configurable **8** luminarias por sector, contando las apagadas. No se
  crea una contribución activa invisible al agotar el presupuesto.
- Rechazos por presupuesto, primario existente o combinación no autorizada se
  conservan en el reporte. No se añaden muebles para fabricar sockets.

El depósito conserva un punto funcional; barracas/armory pueden añadir consolas
si existen. No se garantiza amueblar/iluminar adicionalmente todos los espacios.
Las posiciones, selección de módulos, conectividad y rutas permanecen iguales.

La primera configuración de pared de 10 m falló el contrato funcional del centro
de Command Room: desde un montaje lateral, la distancia real en el kit grande
reducía excesivamente su aporte. Se ajustó el alcance del Resource a 14 m y se
repitió el gate completo. No se debilitó el assert ni se añadió excepción de seed.

## Variantes

| Variante | Probabilidad de encendido | Potencia | Color | Mínimo activo |
|---|---:|---:|---|---:|
| OPERATIVA | 1.00 | ×1.0 | Fuente original | 0 (todas las habilitadas encienden) |
| REDUCIDA | 0.65 | ×0.8 | Fuente original | 0 |
| EMERGENCIA | 0.50 | ×0.6 | Rojo (1, .12, .08) | 1 |

Las listas permitidas son explícitas. El mínimo EMERGENCIA se agregó al observar
una muestra con todos los focos apagados: se activa determinísticamente el primer
candidato ya seleccionado y autorizado, nunca se supera presupuesto ni se habilita
un Source.enabled=false. Si no existe candidato habilitado con potencia visual,
se informa conflicto y la generación no se presenta como válida.
Una luminaria apagada permanece como objeto visible oscuro; su Spot está oculto
y su contribución lógica es cero. No hay parpadeo ni oscilación por frame.

## Exposición y migración 0–10

`LightingManager.get_exposure_at()` es la suma canónica continua limitada a 0–10:
ambiente del perfil + fuentes activas con distancia, dirección y oclusión estática.
Las fuentes legacy se adaptan ×2. `get_light_level_at()` conserva la API 0–5:
`round(exposure / 2)`, limitada a 0–5. NO hay un segundo sistema de detección.
`set_ambient_light_level()` conserva sus unidades legacy; los perfiles nuevos
configuran su ambiente mediante `configure_biome()`, no mediante ese setter.

La ganancia legacy `room_light_addition` sigue funcionando mediante una referencia
de 2 unidades. Potencia efectiva = clamp(potencia × ganancia/referencia × variante,
0,10); energía visual se ajusta proporcionalmente, no se confunde con exposición.
Hay una única consulta de contribución por fuente. El diagnóstico no mide píxeles.

El contexto de ambiente se asocia al propietario de la escena y se limpia al
salir, protegido por ID frente a un propietario posterior. Cada nuevo sector
configura explícitamente perfil o fallback legacy. Sólo hay un contexto de bioma
activo; composiciones espaciales híbridas simultáneas no están implementadas.

Enemy/Player/LogicalCover no se modificaron. Se mantienen FOV/LOS, ruido,
iluminación progresiva, ALERT/CHASE, última posición conocida y admisión P0-R2.
Una cobertura puede bloquear LOS con exposición alta; agacharse no otorga
invisibilidad. Las sombras de luz usan geometría física, no categorías HIGH/MEDIUM/LOW;
esas categorías siguen gobernando exclusivamente el contrato visual existente.

### Balance respecto de A

A tenía ambiente equivalente a 2/10 (1/5). A2 Varkhem usa 3/10, que el adaptador
redondea a 2/5. Con las curvas actuales esto cambia capacidad .15 → .50 en un
punto sin otras fuentes: confirmación ideal aproximada 6.7 → 2 s con LOS/FOV
continuos, sin proximidad override ni ruido. Los ticks reales siguen siendo 0.2 s.
No se cambiaron curvas, alcance 10 m, FOV 105° ni detection_time de 1 s.
REDUCIDA y EMERGENCIA afectan exposición real, pero dos valores canónicos pueden
caer en el mismo nivel 0–5; no se fuerza una diferencia artificial de detección.
La iluminación roja no es una medida fotométrica de luminancia humana: materiales,
gamma, sombras y dispositivo necesitan revisión visual, especialmente en Android.

## Matriz final de variantes

Nueve sectores, cuatro pasadas por run (OPERATIVA/REDUCIDA/EMERGENCIA/OPERATIVA).
36 registros; repetición de OPERATIVA determinista. Misma geometría/navmesh,
contenido, spawns, patrullas y coberturas entre variantes.

| Seed / índice sector | Luminarias | Activas O/R/E | Enemigos |
|---|---:|---|---:|
| 65001 / 0 | 7 | 7 / 6 / 5 | 6 |
| 65002 / 0 | 8 | 8 / 5 / 4 | 4 |
| 65003 / 0 | 8 | 8 / 6 / 3 | 8 |
| 65003 / 1 | 7 | 7 / 6 / 6 | 8 |
| 65004 / 0 | 6 | 6 / 5 / 5 | 4 |
| 65005 / 0 | 8 | 8 / 5 / 4 | 6 |
| 65005 / 1 | 6 | 6 / 1 / 1 | 4 |
| 65006 / 0 | 8 | 8 / 2 / 2 | 6 |
| 65006 / 1 | 8 | 8 / 6 / 4 | 6 |

Los fixtures verifican catálogo original intacto, combinaciones inválidas, mínimo
sin sobreescribir enabled, potencia/energía configurada frente a aplicada,
activación compartida, escala legacy, cleanup de escena y determinismo.

## Regresiones y evidencia

- `regression_ledger.csv`: **35 PASS funcionales / 33 EXIT_0 / 2 NATIVE_AV**.
  Los AV ocurrieron después de PASS en suspensión y combat/reset. Incluye los
  seis Stage5 obligatorios, percepción/coberturas, APPROACH/DROP/reentrada,
  combate/reset, emboscada, ADN/O2, P0-R2, abort P1-B, OMITIR P1-C y perfiles P2-B.
- Percepción con Player/Enemy reales en las tres variantes: Timer normal,
  HIGH/MEDIUM/LOW, posturas, pared, contacto progresivo, pérdida/recuperación,
  activación y movimiento. No se fuerzan estados ni encuentros.
- P3-B1 debug/combate: capa única, sin señales duplicadas. P3-B1.1: 100
  regeneraciones, nodos 823→823, objetos 3651→3651, 9 registros válidos/0 obsoletos.
  Memoria reportada +278244 bytes (~.27 MiB), sin atribución de fuga ni limpieza forzada.
- Varkhem físico: nueve sectores 65001–06, determinismo 65001/03/05/15/20;
  `physical_retry.log`, PASS/EXIT_0. Las 28 firmas físicas/proxies/vértices/polígonos
  coinciden exactamente con A al excluir tiempo de log.
- START dinámico 65001/65005: tres sectores, dos ciclos completos de patrulla,
  sin detección del Player inmóvil, PASS/EXIT_0 (`start.log`).
- Ship tres tamaños y Horvex 66001–03/ocho sectores: PASS/EXIT_0, sin cambios en
  sus Resources (`cross_ledger.csv`).
- Variantes: `variants_delivery.log`, PASS/EXIT_0, 36 registros.
- Datos finales medidos y hashes: `measured_inputs.csv` y `measurement_ledger.csv`.

Selección final de controles funcionales: **40 PASS / 38 EXIT_0 / 2 NATIVE_AV**
(35 compartidos + variantes + físico Varkhem + START + Ship/Horvex).
Cuatro procesos de medición y seis probes gráficos adicionales: PASS/EXIT_0.
Las ejecuciones históricas fallidas o con AV permanecen diferenciadas; no se
presenta esta selección como ausencia global de cierres o certificación integral.

La expectativa literal de P2-B de luz 2/5 en todas las habitaciones con override
no representaba el nuevo ambiente ni las fuentes por función. Se conserva el
assert exacto, calculando el valor configurado de ambiente/modelo aplicado, junto
con ganancia=1 y todas las aserciones de población, determinismo y snapshot.

El fixture negativo inicialmente modificó Sources externos compartidos después
de una copia insuficiente del perfil: `variants_closure.log`, FAIL/EXIT_1.
Se corrigió únicamente el aislamiento del test con copias explícitas de Sources
y variantes y un assert de integridad del catálogo original. No se cambió
producción para satisfacer ese FAIL. El caso anterior permanece archivado.

También se conserva la primera prueba de alcance insuficiente (FAIL/EXIT_1),
el primer wrapper gráfico con marcador incorrecto (INCOMPLETE del wrapper,
probe válido/EXIT_0) y una matriz anterior PASS funcional/NATIVE_AV
(`variants_certification.log`). No se convierten retrospectivamente en EXIT_0.

## Rendimiento y Android

Fuentes sin `_process` ni `_physics_process`, sin simulación de patrullas para
distribuir luz, sin caché NavMesh y sin cambios al bake. Ambiente no crea una luz
dinámica. Presupuesto limita todas las instancias; sólo las activas se renderizan.
Se conservan sombras por foco para oclusión, con coste móvil aún no certificado.

Consultas de 1000 exposiciones en START, con 6–8 fuentes: aproximadamente
3.8–8.1 ms según variante; son loops repetidos en escritorio, no frame time móvil.
En dos pares A/A2, cada proceso mide las mismas 28 generaciones y gates físicos;
resultados y tiempos por pasada se conservan en `measurement_*.log`.

| Modo | Medias de las dos pasadas (28 cada una) | Media conjunta | Máximo |
|---|---|---:|---:|
| A | 353.04 / 349.04 ms | 351.04 ms | 472 ms |
| A2 | 356.50 / 359.50 ms | 358.00 ms | 491 ms |

Diferencia observada ~6.96 ms (~2.0%), no atribuida exclusivamente a iluminación
ni extrapolada a Android. Mismo harness, mismo proceso de bake y mismas seeds;
baseline A se obtiene desactivando sólo el perfil A2 en memoria, preservando el
modelo coherente A. Cero diferencias entre los hashes de inputs medidos y entregados.

Render real Mobile/Radeon RX 570, 960×540, 120 frames después de preparación:
seis probes PASS/EXIT_0 (A, O/R/E y dos vistas superiores). Medias ~16.66–16.67 ms,
limitadas por sincronización. Vista local: 25 draw calls en todos los casos;
superior: 161 A → 164 A2 en la seed 65001. NO demuestra coste GPU nulo, margen
para Cardboard ni 60 FPS Android. No se midieron memoria GPU ni térmica del teléfono.
Capturas `render_*.png` y `render_final_ledger.csv` conservadas sólo como evidencia.

## Extensión ScenarioVariant, sin implementación ajena

Un futuro ScenarioVariant deberá componer referencias independientes a arquitectura,
ocupación/población, iluminación, modificaciones visuales y objetivo. Esta etapa
implementa únicamente el enlace arquitectura/perfil/variante de iluminación,
validado por IDs y sin duplicar plan ni assembler. Ocupación, facciones alternativas,
misiones, escenarios híbridos y mobiliario desordenado siguen NO IMPLEMENTADOS.
Los sockets orgánicos/aberturas/columnas necesitan assets y fixtures propios antes
de afirmar utilidad física o exposición correcta en esos futuros entornos.

## Archivos y pendientes

Producción modificada: LightingManager, ModuleDefinitionResource,
RoomEnvironmentProfileResource, RoomLightModelResource, VarkhemRoomEnvironment,
DebugHUD, RoomEnvironmentBuilder, RoomLogicalLight y Stage6G.
Nuevos: tres clases Resource, doce Resources de catálogo/perfil, BiomeLightingBuilder,
LightingSocketProvider y cuatro fixtures con escenas/UID. P2-B test adapta únicamente
su expectativa luminosa al contrato nuevo. CORE/CURRENT y los demás worktrees intactos.

**ANDROID PENDIENTE; NATIVE_SHUTDOWN_AV ABIERTA; SAFE SAVE FAILED ABIERTA.**
No aprobación integral, no ZIP y no commit A2. STOP al entregar.
