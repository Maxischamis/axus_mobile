# Skill: Axus Mobile — Convenciones del repositorio

## Propósito
Definir las convenciones, requisitos y reglas específicas del proyecto Axus Mobile para asegurar coherencia, calidad y seguridad en el desarrollo Flutter/Dart del repositorio.

## Alcance
- Workspace-scoped: esta skill aplica sólo a este repositorio (`axus_mobile`).
- Se enfoca en Flutter/Dart, Riverpod, Firebase, Material 3 y la arquitectura usada por el proyecto.

## Entradas esperadas
- Objetivo de la tarea o PR (1-2 oraciones).
- Archivos modificados o creados.
- Tests agregados o impactados.

## Salida esperada
- Checklist de cumplimiento para PRs.
- Sugerencias de corrección y pasos de remediación para incumplimientos.

## Convenciones de código
- Formato: usar `dart format` en todo el código antes de commitear. Respetar `analysis_options.yaml`.
- Estilo: seguir las reglas recomendadas por Dart; preferir nombres descriptivos, funciones pequeñas y `const` cuando aplique.
 - Evitar `setState`: no usar `setState` en widgets; usar Riverpod y providers para el manejo de estado.
 - No duplicar código: extraer utilidades y widgets compartidos para mantener DRY.
 - Documentar funciones públicas: todas las funciones públicas deben incluir doc comments y ejemplos cuando aplique.
 - Aplicar SOLID y Clean Architecture en nuevas funcionalidades.
 - Priorizar rendimiento y medir antes de optimizar.
 - Explicar cambios grandes: añadir entrada en `docs/DECISIONS.md` y resumen técnico en el PR.
 - No romper compatibilidad: seguir SemVer, documentar breaking changes y proporcionar guía de migración.

## Arquitectura y organización
- Estructura de carpetas: mantener `lib/models`, `lib/providers`, `lib/views`, `lib/widgets`, `lib/services`.
- Separación de capas: UI (views/widgets) ↔ lógica de estado (Riverpod providers) ↔ servicios/repository ↔ modelos.
- Inyección de dependencias: usar Riverpod para proveer servicios y repositorios; evitar singletons globales fuera de providers.

## State management (Riverpod)
- Preferir `StateNotifier`/`StateNotifierProvider` o `AsyncNotifier` para lógica compleja.
- Los providers deben ser unit-testables y no contener lógica UI.
- Mantener providers finos y composables; evitar grandes providers monolíticos.

## Firebase
- Configuración: los credenciales deben estar en `google-services.json`/`GoogleService-Info.plist` fuera del control de versiones cuando son sensibles (usar variables de CI o secretos del repositorio si corresponde).
- Reglas de seguridad: documentar y versionar reglas de Firestore/Storage en el repo (`firebase.json` y reglas).

## Material 3 y UI
- Usar Material 3 con el tema centralizado en `axus_theme.dart`.
- Preferir Widgets inmutables y `const` where possible; evitar rebuilds innecesarios.

## Tests
- Cobertura mínima objetivo: definir en PR (p. ej. nuevas features deben incluir tests unitarios y widget tests básicos).
- Tipos de tests: unitarios para business logic, widget tests para UI crítica, integración/driver para flujos end-to-end cuando sea necesario.

## Linting y análisis estático
- Seguir `analysis_options.yaml`; corregir `dart analyze` warnings antes de merge.
- Evitar `// ignore:` salvo justificación en el PR.

## Commits y PRs
- Mensajes de commit: usar estilo imperativo y referenciar ticket si aplica (ej: "Add login form validation (#123)").
- PRs deben incluir: descripción, checklist de cambios, pruebas añadidas, pasos para QA y capturas si impactan UI.

## CI/CD
- Asegurar que la pipeline corre `dart analyze`, `dart format --set-exit-if-changed .`, `flutter test` y builds relevantes.

## Seguridad
- Nunca incluir secretos en el repo. Usar variables de entorno/secret managers.
- Validar inputs y reglas de seguridad en Firebase.

## Performance
- Preferir `ListView.builder`/`SliverList` para listas largas.
- Evitar cargas pesadas en `build()`; mover a providers/servicios.
- Usar caching de imágenes y assets cuando corresponda.

## Localización
- Preparar strings para internacionalización; evitar texto embebido en widgets.

## Documentación
- Mantener README actualizado con pasos de setup (Android/iOS), comandos útiles y variables de entorno requeridas.
- Documentar decisiones arquitectónicas en `docs/ARCHITECTURE.md` o similar.

## Agent behavior (para agentes AI que trabajen en este repo)
- Restricciones: no ejecutar comandos en entornos locales por defecto; sugerir comandos en texto y esperar confirmación humana.
- Permitir solo herramientas no destructivas automáticamente (lectura/format), y listar exceptions explícitas si aplica.
- Proveer prompts de ejemplo y casos de uso permitidos: sugerir patrones de refactor, revisar PRs según convenciones.

## Checklist de PR (ejemplo)
- [ ] `dart format` aplicado
- [ ] `dart analyze` sin warnings relevantes
- [ ] Tests añadidos/actualizados según impacto
- [ ] Documentación actualizada si aplica
- [ ] Secrets no incluidos

## Ejemplos de prompts para agentes
- "Revisa el PR y comprueba que cumple las convenciones de Axus Mobile: formato, tests, uso de Riverpod y no inclusión de secretos." 
- "Sugiere optimizaciones de rendimiento para `home_page.dart` enfocándote en rebuilds y listas." 

## Revisión e iteración
- Si hay ambigüedades en una convención, abrir issue con propuesta y discusión técnica.
- Actualizar este `SKILL.md` según decisiones de arquitectura o cambios en dependencias.

---
Este archivo define únicamente las reglas específicas del repositorio Axus Mobile. Para estándares generales (técnologia-agnóstica), crea una Skill Personal separada.
