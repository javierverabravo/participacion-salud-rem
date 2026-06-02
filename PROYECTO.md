# PROYECTO.md — Brief de continuidad (handoff)

> Documento para retomar el proyecto en una nueva sesión de Cowork. Resume qué
> es, qué está hecho, las decisiones clave y el trabajo pendiente. **Para
> continuar, abre una sesión nueva en esta misma carpeta y escribe:**
> *"Lee PROYECTO.md y README.md y continuemos desde el backlog."*

## 1. Qué es

Análisis estadístico reproducible de la **participación ciudadana en salud** en
Chile, usando los Resúmenes Estadísticos Mensuales (REM 2025) del DEIS-MINSAL.
El A19b tiene tres familias de actividad distintas; se analizan **sección por
sección** (bloques A, B y C) con un motor reutilizable, y se sintetizan en
indicadores de **auditoría social** con denominador poblacional.

- Repo: https://github.com/Arleq89/participacion-salud-rem
- Dashboard: https://arleq89.github.io/participacion-salud-rem/

**Tesis:** la decisión de registrar es un rasgo **institucional** (del
establecimiento) en las tres secciones, pero el **territorio y la pobreza no
pesan igual**: son más relevantes en OIRS y, sobre todo, en satisfacción usuaria.

---

## 2. Estado actual — pipeline por bloques (jun 2026)

El pipeline se **reformuló completamente** respecto a la versión global previa.
Ahora analiza la A19b **sección por sección** (bloques A / B / C) con un motor
de funciones reutilizable, agrega datos CASEN 2024 y un denominador FONASA, y
produce indicadores de auditoría social.

### Scripts activos (`R/`)

```
00_descarga.R         Descarga REM 2025 + base maestra de establecimientos
01_procesamiento.R    Crosswalk A19b → bloques A/B/C; tabla larga; universo estab×mes
02_datos_comunales.R  Pobreza comunal CASEN 2024 (ingresos + multidim., SAE, lector robusto)
03_fonasa_inscritos.R Población inscrita validada FONASA (lector flexible; degrada con NA si falta)
10_engine.R           Motor reutilizable por bloque: panel, KPIs, cobertura, serie, equidad,
                      subsecciones, hurdle mixto (glmer+lmer), multinivel 3 niveles, espacial,
                      tipologías k-means. tryCatch + modelo_estado.csv por convergencia.
11_indicadores.R      Indicadores de auditoría social (I_fa, T_se, I_dd, I_ci + extras)
20_analisis_A.R       Bloque A · OIRS (45 códigos; runners del motor)
21_analisis_B.R       Bloque B · Participación social B.1+B.2 (26 códigos)
22_analisis_C.R       Bloque C · Satisfacción usuaria C.1+C.2 (22 códigos)
30_sintesis.R         Comparativo A/B/C + tipologías cross-tema + auditoría social
99_run_all.R          Maestro: ejecuta 00→03→10→11→20→21→22→30 en orden
exploratorio/         Scripts de la fase global previa (archivados, no en el pipeline)
```

Productos en `productos/{A,B,C,sintesis}/` (generados por 99_run_all.R; ignorados
por git localmente, re-comprometidos por GitHub Actions después de cada ejecución).

---

## 3. Decisiones técnicas clave (no repetir errores)

- **Codificación CSV = UTF-8 con BOM** (no Latin-1). Leer con `data.table::fread`,
  separador `;`, `CodigoPrestacion` como texto.
- **El subregistro está en filas ausentes**, no en NA. No colapsar NA a 0.
  El panel completo (estab × mes) se reconstruye en `01_procesamiento.R`.
- **Modelo hurdle → descomposición en dos partes separadas** (`glmer` logística
  para barrera + `lmer` log-lineal para intensidad positiva). `glmmTMB` con
  NB-truncada de objeto único **no converge** por la cola extrema (miles vs.
  medianas de pocas unidades). Siempre verificar convergencia: NaN, SE gigantes,
  dispersión ≈ 0.
- **Motor parametrizado** (`10_engine.R`): las funciones reciben `blq` ("A","B","C")
  y usan `tryCatch`; si un modelo no converge escribe el motivo en
  `productos/<bloque>/modelo_estado.csv` y el pipeline continúa.
- **Edit/Write en el mount Windows** puede corromper archivos grandes (artefacto
  de sincronización). Preferir `Write` completo y verificar con `Read`, no con bash.
- **Crosswalk de columnas** (`crosswalk/crosswalk_columnas_A19b.csv`) es insumo
  curado a mano; SÍ se versiona (no se regenera). Los productos NO se versionan
  localmente (sí los recrea Actions).
- **CASEN 2024 comunal** disponible y auto-descargable desde el Observatorio Social
  (URLs en `02_datos_comunales.R`). Reemplaza CASEN 2020.
- **FONASA inscritos**: URL inestable (portal JS). Colocar el archivo manualmente
  en `datos/externos/poblacion_inscrita_fonasa.csv`; el script `03` lo detecta
  automáticamente. Sin el archivo, usa población CASEN como proxy.

---

## 4. Hallazgos principales (versión por bloques)

| Indicador | A · OIRS | B · Part. social | C · Satisfacción |
|---|---:|---:|---:|
| Cobertura (% estab.) | 49,9 % | 51,1 % | 24,4 % |
| Subregistro estab-mes | 60,4 % | 71,7 % 