# Protocolo multi-IA y continuidad de sesiones

## Una tarea, un dueño, una base inmutable

1. Responsable humano/coordinador aprueba objetivo, base SHA, archivos/sistemas
   permitidos, prohibiciones y gates. Completar [plantilla](../tasks/TEMPLATE.md).
2. La IA verifica HEAD/status/worktrees y crea rama/worktree propios. No reset,
   clean, cambios de rama destructivos ni escritura sobre worktrees ajenos.
3. Registrar ownership en la ficha de tarea antes de programar. No asignar
   Enemy.gd/Encounter a dos escritores simultáneos. Un revisor sólo lee.
4. Ejecutar pruebas proporcionales. Validar fixture antes de clasificar IA/nav.
   Separar PASS/FAIL/INCOMPLETE funcional de EXIT_0/NATIVE_AV/otro error.
5. Entregar diff, informe, comandos/resultados, archivos afectados, límites y
   siguiente paso. STOP al cumplir alcance; no encadenar nuevas funcionalidades.
6. Revisión independiente contra base+SHA, no contra capturas antiguas. Integrar
   sólo con autorización en rama de desarrollo y comprobar árbol/ascendencia.
   main se mantiene protegida; publicación no equivale a aprobación de merge.

## Fuente compartida, sin depender del chat

Cada tarea usa docs/tasks/<ID>.md con estado, dueño y commit base. Los logs
pesados pueden quedar fuera, pero conservar resultados resumidos, comandos,
versión Godot, seeds y hash de datasets. Enlazar informes, no copiar toda historia.
Actualizar STATUS sólo al recuperar/aprobar/publicar, con evidencia y fecha.
No usar OneDrive para que dos IAs editen simultáneamente un mismo checkout.

El código B+C1 ya está compartido en GitHub con SHA verificado (ver STATUS).
Estas páginas tienen copia previa en Drive y recuperación local independiente;
su publicación GitHub sigue pendiente. Para cada entrega compartir
URL de rama + SHA exacto + ruta START_HERE.md + ficha cuando exista allí.
No remitir a START_HERE en un commit B+C1 que todavía no lo contiene.
Revisores web sin acceso
al repo privado necesitan acceso concedido por el usuario o extractos elegidos;
un enlace no concede permisos. No compartir tokens ni dumps con datos sensibles.
En paquetes documentales o de proyecto excluir .git tanto si es directorio
como si es archivo puntero de worktree. Nunca borrar el .git del checkout.

Código pendiente sin commit NO existe para otra IA que clone el SHA. Antes de
handoff externo se requiere recuperación autorizada o un diff explícito sobre
base conocida. No fingir publicación: verificar SHA remoto o marcar PENDIENTE.

Si la red del agente falla, la ficha deja un comando manual listo para el operador
local, no un servicio en segundo plano. Puede autorizarse un lote de commits
revisados para una única publicación, reduciendo intervenciones. No habilitar
publicación automática global ni trasladar permisos entre tareas por inferencia.

## Uso eficiente de cuotas gratuitas

- Tareas pequeñas y verificables; un solo cambio lógico por entrega.
- Revisor recibe archivos relevantes, diff y contrato; no todo el historial del chat.
- Un escritor y revisores independientes, no múltiples reimplementaciones.
- Priorizar documentación/publicación y una prueba Android integrada antes de
  seguir agregando IA/narrativa/mapas. No repetir auditorías/radios ya resueltos.
- Guardar estado antes de agotar una sesión: qué se ejecutó, qué falló, qué no
  se ejecutó. No prometer persistencia de memoria, herramientas o cuota entre IAs.

## Incorporación de una IA nueva (mensaje listo para adaptar)

«Repositorio RogueSpace. Lee AGENTS.md y START_HERE.md. Base exacta <SHA>,
rama destino <rama>, ficha docs/tasks/<ID>.md. Sólo puedes modificar <lista>.
Preserva otros worktrees y main. Verifica status antes de tocar archivos.
No publiques, merges ni commits salvo autorización específica. Entrega diff,
pruebas con funcional/proceso separados, riesgos y STOP. Si no tienes terminal
o Godot, declara revisión estática; no inventes ejecución.»

Para una IA revisora añadir «Sólo lectura; no implementar ni cambiar expectativas
de tests; distinguir defecto reproducido de hipótesis». Aprobar primero la tarea.
