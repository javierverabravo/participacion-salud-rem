# Boceto, Reformulación del dashboard (versión consolidada)

> Documento de diseño para aprobar ANTES de reconstruir `index.qmd`.
> Decisión: **reformular y REDUCIR**, no sumar páginas. De 12 pestañas a **6 de
> contenido + 2 de apoyo**. Cada pestaña, un propósito nítido.
> Lógica narrativa: **Norma, Registro, Brecha, Implicancia.**

## Principio

Un dashboard para autoridades debe contar **una historia con foco**, no ser
exhaustivo. Tesis que ordena todo: *la participación registrada es institucional,
no territorial ni socioeconómica; y lo que el sistema mide (el reclamo) no es lo
que la norma prioriza (la deliberación).*

## Estructura propuesta (6 + 2)

| # | Pestaña | Acto | Qué contiene | Fuentes |
|---|---------|------|--------------|---------|
| 1 | **Portada / Tesis** |, | Hero con la tesis, KPIs generales, serie temporal, e implicancias en una línea | kpis_generales, serie_mensual |
| 2 | **Norma vs. registro** | NORMA, REGISTRO | Marco legal + mecanismos de la Norma General; tabla puente mecanismo ↔ instancia REM ↔ volumen. Revela que el reclamo domina y la deliberación casi no se mide | temas, instancias |
| 3 | **Quién hace qué** | REGISTRO | Mapa de calor tipo de establecimiento × tema e × instancia | tipo_x_tema, tipo_x_instancia |
| 4 | **Territorial** | REGISTRO | Mapa + cruce **región × tipología de registro (perfiles) × tipo de establecimiento** | cobertura_region, region_x_perfil, region_x_tipo |
| 5 | **Brechas: subregistro, dato y equidad** | BRECHA | El 54%, el hallazgo "sin regla de consistencia", patrón de ceros, y desagregaciones de inclusión (sexo, identidad de género, pueblos originarios, migrantes, PRAIS) | estados_panel, equidad_*, genero |
| 6 | **Qué explica las diferencias** | IMPLICANCIA | Multinivel + determinantes + espacial + tipologías fundidos; cierra con conclusión institucional e implicancias de política | modelo_*, moran, lisa, tipologias_perfil |
| A | **Metodología** | apoyo | Pipeline Mermaid + tabla método ↔ convencional |, |
| B | **Glosario** | apoyo | Términos, incl. normativos (COSOC, CDL, CPP, CIRA…) | glosario |

## Desagregaciones disponibles en la A19b (verificado)

Fuente: `crosswalk/crosswalk_columnas_A19b.csv` (curado del diccionario) + manual REM.

- **Sexo:** Hombres / Mujeres.
- **Identidad de género:** Trans Masculino, Trans Femenina, No Binarie, No revelado.
- **Pueblos originarios · Migrantes · PRAIS** (transversales).
- **Grupos prioritarios** (solo OIRS): Niños/niñas/adolescentes, Gestantes.
- **Estructurales:** instancia de participación, línea de satisfacción, gestión del
 reclamo (generados / fuera de plazo / pendientes).
- **EDAD: no hay tramos etarios en la A19b.** Solo el corte grueso de grupo
 prioritario en OIRS. La equidad se construye con sexo, género, pueblos
 originarios, migrantes y PRAIS.

## Lo que falta para construir (en orden, verificando en Positron)

1. Correr `R/07_tipo_actividad.R`, genera `tipo_x_tema.csv` y `tipo_x_instancia.csv`
 (alimenta la pestaña 3). **Verificar que corre.**
2. Nuevo script para la pestaña 4: cruces `region_x_perfil.csv` y `region_x_tipo.csv`.
3. Con los datos listos y el boceto aprobado, reescribir `index.qmd` con las 6+2
 pestañas.

## Lo que NO cambia

El motor analítico: pipeline R (00 a 07), modelos y publicación automática vía GitHub
Actions. La reformulación es de narrativa y presentación.
