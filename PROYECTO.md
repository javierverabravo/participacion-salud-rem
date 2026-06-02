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
| 60,4 % | 71,7 % | 91,6 % |
| Mediana de meses con registro | 12 | 7 | 3 |
| ICC barrera (peso del establecimiento) | 93,9 % | 65,8 % | 74,3 % |
| Varianza nivel comuna | 29,1 % | 17,5 % | 4,1 % |
| OR pobreza (+10 pp) | 0,59 (ns) | 0,85 (ns) | **0,58 (p<0,001)** |
| I de Moran (espacial) | 0,109 (p≈0) | 0,049 (ns) | 0,119 (p<0,001) |
| Mujeres entre participantes | 61,5 % | 66,5 % | 68,7 % |

- **Lo institucional manda en las tres** (ICC de la barrera 66–94 %): registrar
  depende del establecimiento, no del territorio.
- **El territorio NO pesa igual:** B (participación social) es el caso institucional
  puro (sin geografía, pobreza ns); A (OIRS) tiene geografía real (comuna 29 %,
  Moran significativo); C (satisfacción) es la **única** donde la **pobreza comunal
  predice** el registro (OR 0,58; p<0,001) y hay clústeres espaciales.
- **El subregistro crece de A a C** (60 → 72 → 92 %) y está en **filas ausentes**,
  no en celdas vacías.
- **Auditoría social (nacional):** fricción administrativa 11,0 reclamos/1.000;
  46,5 % de reclamos por espera; 14,7 % fuera de plazo; razón felicitaciones/
  reclamos 0,64; densidad democrática 9,1 participantes/100; cohesión intercultural
  0,72/1.000. (Denominador: proxy CASEN 2024; reemplazar por FONASA.)

---

## 5. Cómo reproducir (paso a paso)

Cualquiera que clone el repo y tenga R + Quarto puede llegar a las mismas
conclusiones:

1. Abrir la carpeta del proyecto en R/Positron.
2. En la consola de R: `source("R/99_run_all.R")` — descarga los datos del DEIS,
   construye el crosswalk A19b, agrega CASEN/FONASA, corre el motor sobre A/B/C y
   genera la síntesis. Deja todo en `productos/{A,B,C,sintesis}/` (~70 min).
3. (Opcional, per cápita real) Colocar `datos/externos/poblacion_inscrita_fonasa.csv`
   y re-correr `03` + `30`.
4. En la terminal: `quarto render` — genera el dashboard en `docs/`.
5. `git add -A && git commit -m "..." && git push` — publica en GitHub Pages.

El orden y las dependencias están en `R/99_run_all.R`. El esquema de numeración es
por grupos: **0x** datos, **1x** motor e indicadores, **2x** análisis por bloque,
**3x** síntesis, **99** maestro.

---

## 6. Backlog

- [x] Reformulación por bloques A/B/C (motor + runners + síntesis).
- [x] CASEN 2024, denominador FONASA, indicadores de auditoría social.
- [x] **Dashboard `index.qmd` reconstruido por bloque** (lee `productos/{A,B,C,sintesis}/`;
  páginas A/B/C + Síntesis + Metodología + Glosario). *Pendiente: renderizar con
  `quarto render` y revisar visualmente.*
- [ ] Conseguir el archivo FONASA de inscritos validados (portal JS sin URL estable)
  para pasar los indicadores de "por habitante" a "por inscrito".
- [ ] Publicar/actualizar GitHub Pages tras el render y verificar Actions mensual.
- [ ] (Mejora) Ingreso municipal SINIM para probar "capacidad" de gestión directa.

---

## 7. Notas de la sesión (jun 2026 · revisión de flujo)

- Se reconstruyó el dashboard a la estructura por bloques (antes leía los productos
  planos de la versión global, que ya no se generan).
- **El índice de git se corrompió** (`index file corrupt`, artefacto del mount). Se
  arregla en la terminal del usuario: borrar `.git/index` y `git reset` (reconstruye
  desde HEAD sin perder commits ni archivos).
- **Mount Windows E::** desde el sandbox no se puede `rm`/`mv` ni borrar archivos, y
  la herramienta Write puede dejar bytes nulos al final. Método fiable: escribir a un
  temporal y `cat tmp > destino` por bash (verificado sin NULs). La limpieza de
  archivos (borrar/mover) la hace el usuario.
- Productos planos de la versión global quedan en `_archivo_pipeline_global/` (por
  mover por el usuario); no afectan al repo (gitignored).
