# PROYECTO.md — Brief de continuidad (handoff)

> Documento para retomar el proyecto en una nueva sesión de Cowork. Resume qué
> es, qué está hecho, las decisiones clave y el trabajo pendiente. **Para
> continuar, abre una sesión nueva en esta misma carpeta y escribe:**
> *"Lee PROYECTO.md y README.md y continuemos desde el backlog."*

## 1. Qué es

Análisis estadístico reproducible de la **participación ciudadana en salud** en
Chile, usando los Resúmenes Estadísticos Mensuales (REM 2025) del DEIS-MINSAL, con
un dashboard interactivo en Quarto publicado en GitHub Pages y actualizado
automáticamente cada mes vía GitHub Actions.

- Repo: https://github.com/Arleq89/participacion-salud-rem
- Dashboard: https://arleq89.github.io/participacion-salud-rem/

**Tesis:** la participación registrada es un fenómeno **institucional** (del
establecimiento y su gestión), no territorial ni socioeconómico.

## 2. Estado actual (hecho)

- Pipeline en R consolidado (`R/00`–`R/06` + `99_run_all.R`), idempotente y
  parametrizable por año (`REM_ANIO`).
- Datos: REM (descarga automática), base maestra de establecimientos (tipo,
  dependencia, nivel, coords; 100% match), pobreza comunal CASEN-SAE (100% match).
- Análisis: modelo hurdle mixto, multinivel de 3 niveles, autocorrelación
  espacial (Moran/LISA), tipologías (k-means).
- Dashboard (`index.qmd`) con 9 pestañas, lee solo `productos/`.
- README en formato artículo científico con fórmulas y referencias.
- Publicado en GitHub Pages; workflow de Actions mensual configurado.

## 3. Decisiones técnicas clave (no repetir errores)

- **Codificación REAL de los CSV del REM = UTF-8 (con BOM), no Latin-1.**
- Leer CSV grandes con `data.table::fread`, separador `;`.
- `CodigoPrestacion` se lee como **texto** (calza con el crosswalk).
- Participación = sección **REM-A19b** (93 códigos activos), 3 temas: OIRS,
  participación social, satisfacción usuaria.
- Cada `Col01–Col50` significa algo distinto **según la sección** → ver
  `crosswalk/crosswalk_columnas_A19b.csv` (curado desde el diccionario).
- NO se colapsan NA a 0: el subregistro está en **filas ausentes**, no en NA.
- Modelos pesados (`glmer`): verificar SIEMPRE convergencia (NaN, SE gigantes,
  dispersión ~0) antes de creer resultados. `truncated_nbinom` colapsó por cola
  extrema → se usó descomposición logística + log-lineal / lme4.

## 4. Hallazgos principales

- Cobertura 63%; 37% nunca registra; subregistro establecimiento-mes 54%.
- Tipo de establecimiento explica "quién participa" (Hospital/CESFAM ~100%;
  urgencias/postas mucho menos) → brecha estructural, no de gestión.
- Varianza: establecimiento 49%, comuna 18%, región ~1%. Pobreza comunal NO
  significativa. Moran no significativo (sin clústeres espaciales).
- 4 perfiles (k-means): reclamos-OIRS (CESFAM urbano) vs. participación social
  comunitaria (postas rurales), etc.

## 5. Backlog (próximos pasos, priorizados)

1. **Autoexplicatividad.** Glosario de términos (cobertura, subregistro, OR,
   p-valor, ICC, hurdle, Moran) + tooltips/definiciones en los KPIs y en las
   interpretaciones del dashboard. Aclarar cada KPI: "cobertura *de qué*",
   "participan *en qué*", "subregistro *respecto a qué*".
2. **Diagrama del pipeline** (formato **Mermaid**) en el README y en una pestaña
   "Metodología" del dashboard.
3. **Rediseño visual** del dashboard: tema/branding, CSS propio, página de
   portada (landing) con la tesis y el hallazgo principal arriba, gráficos más
   pulidos e interactivos.
4. **Productos de difusión:** policy brief en PDF (1–2 págs.) para autoridades, y
   un texto/figura para LinkedIn.
5. **Escalamiento analítico:** buscador por establecimiento; comparación
   interanual cuando haya más años; sumar ingreso municipal (SINIM) para probar
   "capacidad" y explicar el efecto comuna (17.5%).
6. **Opcional:** empaquetar el pipeline como *plugin* de Cowork reutilizable.

## 6. Cómo correr todo

```r
install.packages(c("here","readxl","data.table","lme4","ggplot2","plotly",
                   "DT","sf","spdep","chilemapas"))
source("R/99_run_all.R")   # descarga + procesa + analiza
# luego en terminal:  quarto render
```
