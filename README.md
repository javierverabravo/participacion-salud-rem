# Participación Ciudadana en Salud · REM-A19b Chile

> Análisis reproducible de la participación ciudadana en la red pública de salud de Chile, a partir de los Resúmenes Estadísticos Mensuales (REM) del DEIS-MINSAL. Todo el procesamiento está en R; el resultado es un tablero web y un informe técnico.
>
> **Autor:** Javier Vera Bravo · [@Arleq89](https://github.com/Arleq89) · **Datos:** REM 2025 (DEIS-MINSAL).
>
> 📊 **Dashboard en vivo:** <https://arleq89.github.io/participacion-salud-rem/>

Este documento no es solo una guía de instalación. Está escrito para que **otra persona pueda entender cómo se construyó el proyecto de principio a fin**: qué preguntas lo motivaron, qué encontramos al abrir los datos, qué decisiones cambiaron las conclusiones, qué caminos probamos y descartamos, y qué aprendimos en el camino. Si vienes llegando, léelo como una historia; si vienes a reproducirlo, salta a [Cómo reproducir todo](#cómo-reproducir-todo).

---

## La pregunta que originó el proyecto

La Ley 20.500 y la Norma General de Participación Ciudadana obligan a los establecimientos de salud a abrir espacios de participación: oficinas de reclamos (OIRS), consejos de desarrollo local, cabildos, mediciones de satisfacción usuaria. Todo eso se reporta mes a mes en el REM, sección **A19b**.

La pregunta de partida fue simple de enunciar y difícil de responder: **¿dónde "vive" la variación de la participación?** ¿Participa más una comuna que otra por ser más pobre, más rural, de cierta región? ¿O la diferencia está en el establecimiento mismo y en cómo se gestiona? Saber esto cambia la política pública: si el problema es territorial, se interviene por región; si es institucional, se interviene establecimiento por establecimiento.

Para responderla había que pasar de un formulario administrativo de millones de filas a indicadores y modelos que separaran señal de ruido. Esa es la historia que sigue.

---

## Capítulo 1 · Abrir los datos (y la primera sorpresa)

El REM se descarga del [repositorio de datos abiertos del DEIS](https://repositoriodeis.minsal.cl/) (el listado de carpetas está deshabilitado, pero los ZIP se bajan directo, p. ej. `https://repositoriodeis.minsal.cl/DatosAbiertos/REM/SERIE_REM_2025.zip`) como un ZIP anual (~153 MB) con cinco series CSV (A, BS, BM, P, D) y los diccionarios. La participación vive casi toda en la **Serie A** (~7,1 millones de filas, 738 MB), donde cada fila es un establecimiento × mes × prestación, con 50 columnas de valores (`Col01`…`Col50`).

Lo que descubrimos al caracterizar las celdas también marcó el rumbo: en las columnas de la Serie A, **~39 % están vacías (NA), ~24 % son ceros y ~37 % son positivas**. Esa mezcla de NA, cero real y positivo es justamente el corazón del problema del subregistro (Capítulo 3).

---

## Capítulo 2 · Entender el instrumento antes de modelar

El A19b no es una tabla homogénea: es un formulario con **secciones que miden cosas distintas y tienen layouts de columnas distintos**. Confirmamos en el diccionario que "SECCIÓN B" y "SECCIÓN C" son encabezados paraguas **sin códigos**; las secciones-hoja reales son cinco:

- **A**, OIRS: reclamos, consultas, felicitaciones, sugerencias, solicitudes.
- **B.1**, actividades de participación según *instancia* (consejos, cabildos, indígena, jóvenes…).
- **B.2**, *sesiones* según *línea de acción* (cuentas públicas, presupuestos participativos, diálogos…).
- **C.1**, líneas de satisfacción y humanización.
- **C.2**, sesiones según línea de acción de satisfacción.

Agrupamos esto en tres **bloques temáticos**, **A** (OIRS), **B** (=B.1+B.2), **C** (=C.1+C.2), porque cada uno se entiende en su propia lógica y no tiene sentido forzarlos a la misma plantilla.

Para pasar de códigos a significado hubo que **construir dos crosswalks a mano** desde el diccionario, porque los códigos de celda del A19b (`19xxxxxx`) **no coinciden** con el `CodigoPrestacion` del CSV (`09xxxxxx`):

1. `crosswalk_participacion_A19b.csv`, qué prestación es participación y a qué bloque/sección pertenece (**93 códigos activos**).
2. `crosswalk_columnas_A19b.csv`, qué mide cada columna `Col01…Col50` dentro de cada sección (sexo, identidad de género, pueblos originarios, migrantes, PRAIS, instancia, total…).

**Decisión de datos importante que limita lo que se puede afirmar:** en el A19b los participantes (sexo, género, pueblos originarios, migrantes, PRAIS) y las instancias son **columnas marginales independientes**, no una tabla cruzada. Es decir, el formulario dice "hubo 30 actividades de cabildo" y por separado "participaron 200 mujeres", pero **no** dice cuántas mujeres en cabildos. Por eso el análisis de equidad es **marginal por subsección**, no un cruce instancia × participante: cruzarlos sería inventar datos.

---

## Capítulo 3 · El hallazgo que cambió todo: dónde está el subregistro

La intuición inicial era que el subregistro estaría en las **celdas vacías** (NA) dentro de las filas. Al revisarlo, resultó falso: solo ~0,7 % de los valores totales son NA. **El subregistro está en las filas que no existen**: de 2.983 establecimientos, solo ~1.882 registran alguna participación y ~1.100 **nunca** aparecen.

Esto obligó a un cambio metodológico de fondo: no basta con leer las filas que están; hay que **reconstruir el panel completo establecimiento × mes** (el "universo" de quién pudo haber registrado) y comparar contra lo efectivamente reportado. Y una regla de oro que se mantuvo en todo el pipeline: **nunca colapsar NA a 0**, porque "no sabemos" y "fue cero" son cosas distintas que el modelo debe tratar aparte.

Resultado del panel: ~60 % de las combinaciones establecimiento-mes están ausentes en OIRS, ~72 % en participación social y ~92 % en satisfacción. Con intermitencia alta (mediana de 3 de 12 meses registrados por par establecimiento-prestación).

---

## Capítulo 4 · El viaje del modelado (incluyendo lo que descartamos)

Modelar conteos con muchísimos ceros y una cola larguísima es traicionero. Aquí está lo que probamos, en orden, y por qué terminamos donde terminamos.

**Lo que se descartó de entrada.** Se decidió **no usar AHP ni PCA clásico**: el AHP impone pesos subjetivos a un fenómeno que queremos *medir*, no *ponderar*; y el PCA sobre datos de conteo con ceros estructurales produce componentes difíciles de interpretar. En su lugar, la familia de métodos elegida fue: modelos de conteo de panel, *hurdle* para el exceso de ceros, autocorrelación espacial (Moran/LISA) y agrupamiento por composición (k-means).

**El modelo que falló.** El primer intento "elegante" fue un *hurdle* de binomial negativa truncada en un solo objeto (`glmmTMB`, `truncated_nbinom2`/`nbinom1`). **No convergió**: la cola extrema (máximos de miles con mediana 4) colapsa el parámetro de dispersión y la matriz Hessiana deja de ser definida positiva. *Lección que quedó grabada: siempre verificar convergencia, NaN, errores estándar gigantes, dispersión ≈ 0, antes de creerle a un modelo.*

**La solución estable.** Separar el *hurdle* en **dos modelos**: una **barrera** (regresión logística: ¿registra o no?) y una **intensidad** (modelo lineal sobre el log del valor en los positivos: ¿cuánto, dado que registra?). Equivalente conceptualmente, pero numéricamente robusto. Luego se le añadieron **efectos aleatorios por establecimiento** (`lme4`), que convergieron limpio.

**El refinamiento multinivel.** Como la pregunta era *dónde vive la variación*, el modelo final es **multinivel de tres niveles** (establecimiento ⊂ comuna ⊂ región), que reparte la varianza sin subestimar el error. Aquí apareció el resultado central: el **ICC de la barrera es altísimo** (66 a 94 % según sección), registrar es, sobre todo, un **rasgo estructural y estable del establecimiento**, no del territorio.

---

## Capítulo 5 · Traer el mundo exterior: pobreza y población

Un registro sin denominador no se puede comparar entre territorios. Se sumaron dos fuentes externas:

- **Pobreza comunal CASEN 2024** (estimación de áreas pequeñas, ingresos y multidimensional), que se auto-descarga. Cruce 100 % con las comunas del REM. Reemplazó a una versión 2020 previa.
- **Población inscrita validada FONASA 2025** como denominador real per cápita (16,9 millones de beneficiarios por comuna). El portal de FONASA no expone una URL estable, así que este archivo se deja manualmente en la carpeta y el pipeline lo autodetecta (y degrada con elegancia si falta).

Con el denominador se construyeron los **indicadores de auditoría social**: fricción administrativa (reclamos OIRS ×1.000 inscritos), severidad de espera, tasa fuera de plazo, densidad democrática (participación ×100 inscritos) y cohesión intercultural (actividades interculturales ×1.000).

---

## Capítulo 6 · Lo que encontramos

Las piezas encajan en una conclusión coherente: **la participación es un fenómeno institucional, no territorial ni socioeconómico**, con matices importantes por sección.

- **Tipo de establecimiento explica casi todo "quién participa".** Hospitales y CESFAM ~100 %; postas rurales ~60 %; urgencias (SAPU/SUR) casi 0. El ~37 % que "nunca participa" es **estructural** (urgencias y niveles que por diseño no tienen instancias de participación), no necesariamente desidia. Por eso el modelo distingue **ceros estructurales** de **subregistro** real.
- **El territorio no pesa igual en las tres secciones.** Es casi nulo en participación social (B), real en OIRS (A, la comuna pesa ~29 %) y **socioeconómico en satisfacción usuaria (C)**: es la **única** sección donde la pobreza comunal predice el registro (OR ≈ 0,58 por +10 pp de pobreza, p < 0,001). Las comunas más pobres registran menos satisfacción usuaria.
- **La variación territorial es municipal, no de la red ni de la región.** Al modelar el Servicio de Salud (la red de gestión, 29 servicios) como nivel, explica casi nada (0 a 2 % de la varianza), igual que la región. Donde sí vive la diferencia territorial es en la **comuna** (cerca de 29 % en OIRS): comunas de un mismo Servicio de Salud registran muy distinto. La autocorrelación espacial de OIRS se suaviza al agrupar por servicio, pero la red no homogeniza a sus comunas.
- **La dependencia administrativa NO marca diferencia.** Probamos explícitamente si quién administra el establecimiento (municipal vs. servicio de salud) explica la varianza: una vez conocidos tipo y nivel, la dependencia añade prácticamente nada (≤ 0,7 pp) y sus coeficientes salen no significativos. Era una hipótesis razonable, y el dato la rechaza.
- **OIRS no es "reclamos".** Dominan abrumadoramente las **consultas** (16,8 millones) frente a reclamos (138 mil) y felicitaciones (142 mil). La razón felicitaciones/reclamos real es ≈ 1,03. Presentar A como "reclamos" distorsiona; cada tipo de solicitud se entiende en su propia escala.
- **Las líneas de acción son más inclusivas que las instancias.** En equidad por subsección, B.2 y C.2 registran mucha más participación de pueblos originarios y migrantes (8 % y ~5 %) que B.1 y C.1 (~2 % y ~1 %). La inclusión étnica/migrante vive en una subsección concreta.

**Implicancias de política:** fijar metas de registro **por establecimiento y tipo**, no por región; usar los **Servicios de Salud** como unidad de mejora; **validar la sección de participación social** en el instrumento (hoy sin regla de consistencia, lo que habilita subregistro); y atender el **sesgo socioeconómico específico de satisfacción usuaria**.

---

## Capítulo 7 · Del análisis al tablero (y su rediseño)

El primer entregable fue un **dashboard Quarto** estático (publicable gratis en GitHub Pages) que lee solo las tablas de `productos/`. Tras una ronda de comentarios, se rediseñó con una idea rectora: **que lo entienda cualquier persona sin formación técnica**. Los cambios principales:

- **Orden pedagógico de páginas:** Metodología, Glosario, Resumen, **Territorio**, A, B, C, Síntesis, Nivel y robustez. Primero se explica cómo leer, después se muestra.
- **Glosario con doble definición** (técnica y "en palabras simples") y **tooltips de ayuda** en cada indicador, que explican qué significa y cómo se calcula al pasar el mouse.
- **Cada sección en su propia lógica:** A separa consultas/reclamos/felicitaciones; B distingue B.1 (instancias) de B.2 (líneas de acción) con su perfil de participante; C corrige la lectura de cobertura vs. pobreza.
- **Nueva página Territorio** con la mirada región por región (cobertura, pueblos originarios y migrantes por bloque), insumo de un futuro mapa interactivo.
- Correcciones de presentación (superposición en móvil, ejes encimados) y verificación de convergencia visible en `modelo_estado.csv`.

En paralelo se decidió construir, sobre los **mismos** productos, una futura **app Shiny** para la exploración interactiva real (filtros por región, segmentación dinámica), dejando el Quarto como versión estable y publicable.

---

## Cómo reproducir todo

Requisitos: **R ≥ 4.3** y, para publicar el tablero, **Quarto**. Paquetes: `here`, `data.table`, `readxl`, `lme4`, `ggplot2`, `plotly`, `DT`, `bslib`, `sf`, `spdep`, `chilemapas`.

```r
# Desde la raíz del proyecto, en R:
source("R/10_run_all.R") # pipeline completo: datos -> productos/
```

Los bloques A/B/C corren **en paralelo** (con respaldo secuencial automático si el cluster falla) y los modelos mixtos usan `nAGQ = 0`, lo que baja el tiempo de ~110 min a ~30 a 40 min en un equipo de varios núcleos. Se puede ajustar con variables de entorno antes del `source`:

```r
Sys.setenv(REM_PAR = "0") # "1" paralelo (def) | "0" secuencial
Sys.setenv(REM_SENS = "0") # "1" corre la sensibilidad participativa (def) | "0" la omite (más rápido)
Sys.setenv(REM_DEP = "1") # "0" omite dependencia en la descomposición (def) | "1" la incluye
Sys.setenv(REM_FAST = "1") # "0" glmer exacto nAGQ=1 (def, ~30-40 min) | "1" rápido nAGQ=0 (~4 min, ICC algo menor)
```

La corrida **publicable** se hace en modo exacto (por defecto); `REM_FAST="1"` es solo para iterar rápido durante el desarrollo.

Luego, en la terminal:

```bash
quarto render # genera el tablero en docs/
quarto render articulo.qmd # genera el informe técnico en PDF
```

El archivo **FONASA** (`Beneficiarios 2025.csv`) debe estar en la raíz o en `datos/externos/` antes de correr (no tiene descarga automática estable). Todo lo demás (REM y CASEN) se descarga solo.

### El pipeline, paso a paso

| Script | Qué hace |
|---|---|
| `R/00_descarga.R` | Descarga REM del DEIS + base maestra de establecimientos. |
| `R/01_procesamiento.R` | Crosswalks A19b, filtra participación, reconstruye universo establecimiento × mes, formato largo etiquetado. |
| `R/02_datos_comunales.R` | Pobreza comunal CASEN 2024 (auto-descarga). |
| `R/03_fonasa_inscritos.R` | Denominador poblacional FONASA (lectura robusta del archivo local). |
| `R/04_engine.R` | **Motor**: toda la lógica analítica por bloque (KPIs, cobertura, serie, equidad, subsecciones, hurdle mixto, multinivel, espacial, tipologías), con salvaguardas de convergencia. |
| `R/05_indicadores.R` | Indicadores de auditoría social con denominador poblacional. |
| `R/06/07/08_analisis_{A,B,C}.R` | Corren el motor sobre cada bloque, `productos/{A,B,C}/`. |
| `R/09_sintesis.R` | Comparativo A/B/C, tipologías cross-tema, consolidado territorial, indicadores. |
| `R/10_run_all.R` | Orquesta todo lo anterior en orden. |

Scripts exploratorios y versiones anteriores quedan archivados en `R/exploratorio/`.

### Estructura del repositorio

```
├── R/            scripts del pipeline (00 a 10) + exploratorio/
├── datos/        REM crudo (en .gitignore) + externos/ (CASEN, FONASA)
├── crosswalk/    diccionarios curados A19b (prestaciones y columnas)
├── productos/    salidas del análisis (lo único que lee el tablero)
│   ├── A/ B/ C/   una carpeta por bloque temático
│   └── sintesis/  comparativos e indicadores transversales
├── index.qmd     dashboard Quarto (genera docs/)
├── articulo.qmd  informe técnico (genera articulo.pdf)
├── _quarto.yml   configuración del sitio
└── docs/         sitio renderizado (GitHub Pages)
```

---

## Lecciones para quien siga este camino

1. **El subregistro suele estar en lo que no está.** Reconstruir el universo completo (filas ausentes) importa más que limpiar las celdas vacías. No colapses NA a 0.
2. **Entiende el instrumento antes de modelar.** Saber que instancias y participantes son marginales independientes evita afirmar cruces que el dato no soporta.
3. **Un modelo que no converge no es un modelo.** Revisa dispersión, errores estándar y Hessiana; ten lista una alternativa estable (aquí, descomponer el hurdle en barrera + intensidad).
4. **Separa ceros estructurales de subregistro.** No es lo mismo "una urgencia que por diseño no participa" que "un CESFAM que dejó de registrar".
5. **Prueba tus hipótesis y acepta cuando el dato las rechaza** (la dependencia administrativa no explicaba nada: bien saberlo).
6. **Diseña el tablero para quien no es experto.** Doble glosario, tooltips, una sección por lógica propia