# Participación Ciudadana en Salud en Chile: un análisis de los Resúmenes Estadísticos Mensuales (REM 2025)

*Análisis reproducible de las actividades de participación ciudadana registradas por
la red pública de salud chilena, con un dashboard interactivo de actualización
automática.*

📊 **Dashboard en vivo:** https://arleq89.github.io/participacion-salud-rem/
· 👤 **Autor:** Javier — Salud Pública, Chile ([@Arleq89](https://github.com/Arleq89))

---

## Resumen

La participación ciudadana es un componente normativo y un determinante social de la
salud (Ley N.º 20.500, 2011; CSDH, 2008). Sin embargo, se conoce poco sobre **qué
condiciona su registro efectivo** en el sistema público chileno. Usando los
Resúmenes Estadísticos Mensuales (REM) de 2025 del Departamento de Estadísticas e
Información de Salud (DEIS), se analizan 140.507 registros de participación de 2.982
establecimientos. Mediante modelos de barrera (*hurdle*) con efectos aleatorios,
modelos multinivel de tres niveles, autocorrelación espacial y agrupamiento, se
encuentra que la participación registrada **se explica principalmente por el
establecimiento (≈49 % de la varianza) y la comuna (≈18 %), y casi nada por la
región (≈1 %)**; que el **tipo de establecimiento** es el predictor dominante; y que
la **pobreza comunal no la predice** de forma significativa. La participación no
forma clústeres espaciales (I de Moran no significativo). Se concluye que el
fenómeno es **institucional**, no territorial ni socioeconómico, lo que reorienta
las estrategias para reducir el subregistro.

**Palabras clave:** participación en salud · atención primaria · datos de conteo ·
modelos multinivel · autocorrelación espacial · Chile.

---

## 1. Introducción

La participación social en salud —entendida como la incidencia de las personas y
comunidades en la gestión sanitaria— es a la vez un **derecho** consagrado en la
normativa chilena (Ley N.º 20.500 sobre Asociaciones y Participación Ciudadana en la
Gestión Pública, 2011) y un **determinante social de la salud** reconocido
internacionalmente (Comisión sobre Determinantes Sociales de la Salud, CSDH/OMS,
2008; Marmot, 2005). El Modelo de Atención Integral de Salud Familiar y Comunitaria
sitúa a la participación como uno de sus pilares.

Operativamente, esa participación se registra en los **REM**, el sistema oficial de
estadísticas de producción del DEIS-MINSAL. La sección **REM-A19b** consolida tres
familias de actividades: la atención de Oficinas de Información, Reclamos y
Sugerencias (OIRS), las instancias de participación social (consejos, cabildos,
diálogos) y la gestión de la satisfacción usuaria.

Pese a su relevancia, el **subregistro** y la **heterogeneidad** entre
establecimientos rara vez se analizan con métodos formales en Chile. Este trabajo
aborda seis preguntas: (1) quién participa y en qué; (2) si existen patrones
espaciales; (3) cómo evoluciona en el tiempo; (4) qué factores explican las
diferencias; (5) qué revela el patrón de subregistro; y (6) qué perfiles latentes
subyacen a la participación.

---

## 2. Datos y materiales

| Fuente | Contenido | Uso |
|---|---|---|
| **REM 2025 (DEIS-MINSAL)** | Producción mensual por establecimiento y prestación | Variable de participación (sección A19b) |
| **Base maestra de establecimientos (DEIS / datos.gob.cl)** | Tipo, dependencia, nivel, coordenadas | Características del establecimiento |
| **Pobreza comunal CASEN-SAE (Observatorio Social, MDSF)** | Tasa de pobreza por ingresos | Covariable de contexto comunal |

La unidad de registro del REM es *establecimiento × mes × prestación*; las columnas
`Col01–Col50` codifican desagregaciones (sexo, identidad de género, pueblos
originarios, migrantes, instancias). La participación se identifica mediante un
*crosswalk* construido desde el diccionario oficial (93 códigos activos en A19b). La
estimación de pobreza comunal se basa en metodología de **áreas pequeñas**
(Fay & Herriot, 1979; Rao & Molina, 2015), que combina la encuesta CASEN con
registros administrativos para producir cifras a nivel de comuna.

---

## 3. Métodos

Cada método se eligió según la **naturaleza del dato** (conteos, datos de panel,
datos jerárquicos, datos espaciales), no por convención. A continuación, para cada
uno: la pregunta que responde, la formulación y una explicación para audiencia no
técnica.

### 3.1 Modelo de barrera (*hurdle*) para datos de conteo

**Pregunta:** ¿qué explica que un establecimiento *registre o no* participación, y
*cuánta* registra?

Los conteos de participación tienen exceso de ceros y fuerte asimetría, lo que
invalida la regresión lineal ordinaria (Cameron & Trivedi, 2013). El modelo de
barrera (Mullahy, 1986; Zeileis, Kleiber & Jackman, 2008) separa el proceso en dos:

$$
P(Y_{it}=0)=1-\pi_{it}, \qquad
P(Y_{it}=y)=\pi_{it}\,\frac{f(y;\mu_{it},\theta)}{1-f(0;\mu_{it},\theta)},\; y>0
$$

donde $\pi_{it}$ (parte **barrera**) es la probabilidad de registrar, modelada con
regresión logística, y $f(\cdot)$ es una distribución de conteo truncada en cero
(Binomial Negativa) para la parte de **intensidad**. La Binomial Negativa admite
sobredispersión mediante su varianza $\mathrm{Var}(Y)=\mu+\mu^{2}/\theta$ (Hilbe,
2011), a diferencia de Poisson, que impone $\mathrm{Var}(Y)=\mu$.

> **En palabras simples:** primero el modelo se pregunta *"¿hubo participación,
> sí o no?"* (como lanzar una moneda cuyas probabilidades dependen de la región, el
> tipo de establecimiento y el mes); y solo si la respuesta es sí, se pregunta
> *"¿cuánta?"*. Separar ambas preguntas evita que el enorme número de ceros
> distorsione la medición de la intensidad.

*Implementación:* `glmmTMB` (Brooks et al., 2017).

### 3.2 Modelo multinivel de tres niveles

**Pregunta:** ¿dónde "vive" la variación —en el establecimiento, la comuna o la
región— y la pobreza comunal, la modifica?

Los establecimientos están **anidados** en comunas, y estas en regiones; ignorar esa
jerarquía subestima los errores (Snijders & Bosker, 2012; Gelman & Hill, 2007). Para
la parte barrera (binaria) se ajusta una regresión logística con interceptos
aleatorios anidados:

$$
\mathrm{logit}(\pi_{ijk}) = \beta_0 + \mathbf{x}_{ijk}\boldsymbol{\beta}
+ u_k + v_{jk} + w_{ijk}
$$

con $u_k\sim N(0,\sigma^2_{\text{región}})$, $v_{jk}\sim N(0,\sigma^2_{\text{comuna}})$ y
$w_{ijk}\sim N(0,\sigma^2_{\text{estab}})$. La proporción de varianza atribuible a
cada nivel —el **coeficiente de correlación intraclase (ICC)**— se obtiene en la
escala latente añadiendo la varianza residual logística $\pi^2/3$ (Goldstein et al.,
2002; Merlo et al., 2006):

$$
\text{ICC}_{\text{nivel}}=\frac{\sigma^2_{\text{nivel}}}
{\sigma^2_{\text{región}}+\sigma^2_{\text{comuna}}+\sigma^2_{\text{estab}}+\pi^2/3}
$$

> **En palabras simples:** imagina que la variación total en participación es una
> torta. El ICC indica qué tajada de esa torta corresponde a diferencias *entre
> establecimientos*, cuál a diferencias *entre comunas* y cuál *entre regiones*. Si
> la tajada de la región es minúscula, el "dónde" geográfico importa poco.

*Implementación:* `lme4` (`glmer`).

### 3.3 Autocorrelación espacial: I de Moran y LISA

**Pregunta:** ¿las comunas vecinas se parecen entre sí (clústeres) o la
participación se distribuye al azar en el espacio?

El **I de Moran** (Moran, 1950) mide la autocorrelación espacial global:

$$
I=\frac{n}{W}\cdot
\frac{\sum_i\sum_j w_{ij}(x_i-\bar{x})(x_j-\bar{x})}{\sum_i (x_i-\bar{x})^2}
$$

donde $w_{ij}$ es 1 si las comunas $i$ y $j$ comparten frontera (0 en caso
contrario) y $W=\sum_{i,j}w_{ij}$. Valores de $I$ positivos y significativos indican
clústeres; valores cercanos al esperado $E[I]=-1/(n-1)$ indican aleatoriedad
espacial. Los **LISA** (Anselin, 1995) descomponen ese índice global en una
contribución local por comuna, identificando focos *alto-alto* o *bajo-bajo*.

> **En palabras simples:** es la pregunta de "¿Dios los cría y ellos se juntan?"
> aplicada al mapa. Si las comunas que participan mucho tienden a estar pegadas unas
> a otras, hay clústeres; si están repartidas sin patrón, la geografía no manda.

*Implementación:* `spdep` (Bivand & Wong, 2018), geometrías de `chilemapas`.

### 3.4 Agrupamiento por *k*-means (tipologías)

**Pregunta:** ¿existen "estilos" o perfiles de participación no etiquetados en los
datos?

Se agrupan los establecimientos según la **composición** de su actividad entre los
tres temas. *k*-means (MacQueen, 1967; Hartigan & Wong, 1979) busca los $k$ centros
$\mu_k$ que minimizan la dispersión interna:

$$
\arg\min_{C}\sum_{k=1}^{K}\sum_{x_i\in C_k}\lVert x_i-\mu_k\rVert^{2}
$$

> **En palabras simples:** es como ordenar una canasta de frutas mezcladas en cuatro
> montones, de modo que cada montón sea lo más parecido posible por dentro y lo más
> distinto posible de los demás. Aquí los "montones" son perfiles de participación.

*Implementación:* `stats::kmeans` (R Core Team, 2025).

---

## 4. Resultados principales

- **Cobertura.** El 63 % de los establecimientos registra alguna participación; el
  37 % nunca lo hace. El subregistro a nivel establecimiento-mes alcanza el 54 %.
- **Tipo de establecimiento.** Hospitales y CESFAM participan casi universalmente
  (~100 %); servicios de urgencia (SAPU 13 %, SUR 2 %) y postas rurales (60 %), mucho
  menos: una brecha **estructural** ligada al modelo de atención.
- **Determinantes (multinivel).** Varianza: establecimiento ≈ 49 %, comuna ≈ 18 %,
  región ≈ 1 %. La **pobreza comunal no es significativa** (OR por +10 puntos ≈ 0,81;
  p > 0,05): el efecto comuna existe pero es independiente de la pobreza.
- **Espacial.** I de Moran ≈ 0,03 (no significativo): sin clústeres territoriales.
- **Tipologías.** Cuatro perfiles, desde CESFAM urbanos centrados en reclamos hasta
  postas rurales centradas en participación social comunitaria.

---

## 5. Discusión

Los cuatro métodos convergen en una misma conclusión: **la participación ciudadana
registrada es un fenómeno institucional, no territorial ni socioeconómico.** Que la
región explique ~1 % de la varianza y que la pobreza no sea significativa contradice
la intuición de que "las comunas más pobres participan menos". El efecto comuna
(~18 %), ortogonal a la pobreza, sugiere que lo decisivo es la **gestión municipal**
(voluntad, capacidad administrativa, cultura participativa) más que la riqueza del
territorio. La heterogeneidad dominante a nivel de establecimiento, junto con el
fuerte efecto del tipo, implica que las políticas para reducir el subregistro deben
focalizarse en **establecimientos y tipos concretos**, no en regiones tratadas como
un todo. Finalmente, las tipologías muestran que "participar" no es homogéneo:
significa gestión de reclamos en el centro urbano y participación comunitaria en la
posta rural.

---

## 6. Limitaciones

- Se mide el **registro** de participación, no la participación real: un cero puede
  ser ausencia de actividad **o** subregistro administrativo.
- Diseño **observacional**: las asociaciones no implican causalidad.
- Cubre **un año (2025)**; la pobreza comunal usa la estimación CASEN 2020 (revisada
  2022), la más reciente a nivel comunal.
- No se midió directamente la **capacidad municipal** (presupuesto); el ingreso
  municipal (SINIM) queda como extensión futura para distinguir "capacidad" de
  "gestión", y para explicar el efecto comuna observado.

---

## 7. Reproducibilidad

Requiere R (≥ 4.5) y Quarto.

```r
install.packages(c("here","readxl","data.table","lme4","glmmTMB",
                   "ggplot2","plotly","DT","sf","spdep","chilemapas"))
source("R/99_run_all.R")   # descarga, procesa y analiza todo
```

Luego, en la terminal: `quarto render` (genera el dashboard en `docs/`).

```
R/
  00_descarga.R          Descarga REM + base de establecimientos
  01_procesamiento.R     Crosswalks, limpieza, tabla larga, cruce
  02_datos_comunales.R   Pobreza comunal (CASEN)
  03_dashboard_kpis.R    KPIs + modelo base
  04_modelo_multinivel.R Determinantes socioeconómicos (3 niveles)
  05_espacial.R          Autocorrelación espacial (Moran / LISA)
  06_tipologias.R        Perfiles de participación (k-means)
  99_run_all.R           Script maestro
crosswalk/  Diccionarios de códigos · productos/  Tablas para el dashboard
index.qmd   Dashboard (Quarto) · docs/  Sitio publicado · datos/  (ignorada por Git)
```

---

## 8. Conclusión

Con datos administrativos abiertos y métodos adecuados a su naturaleza, este trabajo
muestra que la participación ciudadana en salud en Chile se gobierna desde la
institución —el establecimiento y su gestión local— y no desde la geografía ni la
condición socioeconómica del territorio. Es un insumo para repensar dónde y cómo
fortalecer la participación, y un ejemplo de análisis reproducible y publicado de
forma automatizada sobre fuentes oficiales.

---

## Referencias

- Anselin, L. (1995). Local Indicators of Spatial Association—LISA. *Geographical Analysis*, 27(2), 93–115.
- Bivand, R. S., & Wong, D. W. S. (2018). Comparing implementations of global and local indicators of spatial association. *TEST*, 27(3), 716–748.
- Brooks, M. E., Kristensen, K., van Benthem, K. J., et al. (2017). glmmTMB balances speed and flexibility among packages for zero-inflated generalized linear mixed models. *The R Journal*, 9(2), 378–400.
- Cameron, A. C., & Trivedi, P. K. (2013). *Regression Analysis of Count Data* (2.ª ed.). Cambridge University Press.
- Comisión sobre Determinantes Sociales de la Salud (CSDH/OMS). (2008). *Subsanar las desigualdades en una generación*. Organización Mundial de la Salud.
- Fay, R. E., & Herriot, R. A. (1979). Estimates of income for small places: An application of James-Stein procedures to census data. *JASA*, 74(366), 269–277.
- Gelman, A., & Hill, J. (2007). *Data Analysis Using Regression and Multilevel/Hierarchical Models*. Cambridge University Press.
- Goldstein, H., Browne, W., & Rasbash, J. (2002). Partitioning variation in multilevel models. *Understanding Statistics*, 1(4), 223–231.
- Hartigan, J. A., & Wong, M. A. (1979). Algorithm AS 136: A K-means clustering algorithm. *Journal of the Royal Statistical Society C*, 28(1), 100–108.
- Hilbe, J. M. (2011). *Negative Binomial Regression* (2.ª ed.). Cambridge University Press.
- Ley N.º 20.500. (2011). *Sobre Asociaciones y Participación Ciudadana en la Gestión Pública*. Chile.
- MacQueen, J. (1967). Some methods for classification and analysis of multivariate observations. *Proc. 5th Berkeley Symposium on Mathematical Statistics and Probability*, 1, 281–297.
- Marmot, M. (2005). Social determinants of health inequalities. *The Lancet*, 365(9464), 1099–1104.
- Merlo, J., Chaix, B., Ohlsson, H., et al. (2006). A brief conceptual tutorial of multilevel analysis in social epidemiology. *Journal of Epidemiology & Community Health*, 60(4), 290–297.
- Moran, P. A. P. (1950). Notes on continuous stochastic phenomena. *Biometrika*, 37(1/2), 17–23.
- Mullahy, J. (1986). Specification and testing of some modified count data models. *Journal of Econometrics*, 33(3), 341–365.
- Rao, J. N. K., & Molina, I. (2015). *Small Area Estimation* (2.ª ed.). Wiley.
- R Core Team. (2025). *R: A Language and Environment for Statistical Computing*. R Foundation for Statistical Computing.
- Snijders, T. A. B., & Bosker, R. J. (2012). *Multilevel Analysis* (2.ª ed.). Sage.
- Zeileis, A., Kleiber, C., & Jackman, S. (2008). Regression models for count data in R. *Journal of Statistical Software*, 27(8), 1–25.

*Datos oficiales del Departamento de Estadísticas e Información de Salud (DEIS),
Ministerio de Salud de Chile. Documento técnico que acompaña al repositorio; no
constituye una publicación revisada por pares.*
