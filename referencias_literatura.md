# Revisión de literatura, métodos y precedentes

Insumo para la sección de métodos/discusión del artículo. Cada bloque justifica una
decisión metodológica del proyecto y la ancla en literatura, priorizando estudios
chilenos con datos administrativos.

## 1. Precedente chileno central (mismo ecosistema de datos y método)

- **García-Huidobro D, Barros X, Quiroz A, Barría M, Soto G, Vargas I (2018).** *Modelo
  de atención integral en salud familiar y comunitaria en la atención primaria chilena.*
  Rev Panam Salud Publica 42:e160. https://www.scielosp.org/article/rpsp/2018.v42/e160/
, **Precedente directo.** Estudio multinivel sobre **1.263 establecimientos de APS**
  chilenos, con factores a nivel de **establecimiento, comuna y región** (idéntica
  jerarquía a la nuestra). Hallazgo clave y paralelo al nuestro: mayor implementación en
  **CESFAM, comunas urbanas, con más población inscrita y menor pobreza**, pero **sin
  asociación significativa con el gasto municipal**, coincide con nuestro resultado de
  que la comuna pesa pero la "capacidad" socioeconómica/municipal no es el motor
  (efecto pobreza ortogonal salvo en satisfacción usuaria).

## 2. Participación social en salud en Chile (marco y vacío que llenamos)

- **Análisis del sistema de salud chileno y su estructura en la participación social
  (2022).** Saúde em Debate 46(spe4):94-106.
  https://www.scielosp.org/article/sdeb/2022.v46nspe4/94-106/en/
, La participación en el sistema chileno es predominantemente **consultiva, sin
  deliberación**. Sustenta nuestra tesis normativa: lo que más se registra (reclamo) no
  es el núcleo deliberativo que prioriza la norma.
- **Social participation in Chile's healthcare system: reflective contributions from
  bioethics (2025).** https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11930322/
, Marco normativo-ético de la participación (Ley 20.500) y sus mecanismos.

## 3. Modelos de conteo con exceso de ceros (hurdle), por qué, no Poisson/lineal

- **Mullahy J (1986).** *Specification and testing of some modified count data models.*
  J Econometrics 33(3):341-365., Formulación original del modelo **hurdle** (barrera).
- **Modeling zero-modified count and semicontinuous data in health services research,
  Part 1 (2016).** PubMed 27500945. https://pubmed.ncbi.nlm.nih.gov/27500945/
, Justifica separar "si ocurre" de "cuánto" en **datos de servicios de salud** con
  muchos ceros (utilización, recuentos administrativos), exactamente nuestro caso.
- **Spatiotemporal hurdle models for zero-inflated count data: emergency department
  visits (2014).** PubMed 24682266. https://pubmed.ncbi.nlm.nih.gov/24682266/
, Hurdle aplicado a recuentos de salud con estructura espacio-temporal.
- **Feng CX (2021).** *A comparison of zero-inflated and hurdle models for modeling
  zero-inflated count data.* J Stat Distrib Appl.
  https://link.springer.com/article/10.1186/s40488-021-00121-4
, Diferencia hurdle vs. zero-inflated; respalda elegir hurdle cuando el cero significa
  "no cruzó el umbral" (no registró), no un proceso de inflación separado.

## 4. Modelos multinivel en salud (descomposición de varianza)

- **Snijders TAB, Bosker RJ (2012).** *Multilevel Analysis*, 2.ª ed. Sage.
, Base de la descomposición establecimiento/comuna/región e ICC.
- **Bates D, Mächler M, Bolker B, Walker S (2015).** *Fitting linear mixed-effects models
  using lme4.* J Stat Softw 67(1):1-48., Software de los modelos mixtos (`glmer`/`lmer`).
- **Brooks ME et al. (2017).** *glmmTMB balances speed and flexibility among packages for
  zero-inflated GLMMs.* R Journal 9(2):378-400.
, Paquete que probamos para el hurdle de objeto único (NB truncada); documenta por qué
  optamos por la descomposición en dos partes cuando no converge por la cola extrema.

## 5. Autocorrelación espacial en salud (Chile)

- **Moran PAP (1950).** *Notes on continuous stochastic phenomena.* Biometrika 37:17-23.
- **Anselin L (1995).** *Local indicators of spatial association, LISA.* Geographical
  Analysis 27(2):93-115., Base de I de Moran global y LISA.
- **Autocorrelación espacial de mortalidad por cáncer de mama en la Región Metropolitana,
  Chile (estudio ecológico).** Medwave. https://www.medwave.cl/investigacion/estudios/7766.html
, Precedente chileno de I de Moran a nivel **comunal** para una variable de salud.

## 6. Pobreza comunal por estimación de áreas pequeñas (SAE / CASEN)

- **Rao JNK, Molina I (2015).** *Small Area Estimation*, 2.ª ed. Wiley., Método SAE.
- **Casas-Cordero Valencia C, Encina J, Corral P (2016).** *Poverty mapping for the
  Chilean comunas* (modelo Fay-Herriot). En Pratesi (ed.), Wiley.
  https://onlinelibrary.wiley.com/doi/pdf/10.1002/9781118814963.ch20
, Sustenta el uso de la **pobreza comunal CASEN-SAE** como covariable.
- **Ministerio de Desarrollo Social y Familia. Documento metodológico SAE, estimaciones
  de pobreza comunal.** Observatorio Social.
  https://observatorio.ministeriodesarrollosocial.gob.cl/pobreza-comunal
, Fuente oficial de la covariable (CASEN 2024 en nuestro pipeline).

## 7. Calidad y subregistro de registros administrativos en salud (Chile)

- **Calidad de datos y sistemas de información en salud pública, Nota técnica.** CNEP.
  https://cnep.cl/wp-content/uploads/2023/10/Calidad-datos-publicos-v-2.pdf
, Encuadra el problema de completitud/subregistro en datos públicos chilenos.
- **Manual Series REM (DEIS-MINSAL).** Define la estructura del REM y, para participación
  social, indica que la sección "no presenta regla de consistencia", base de nuestro
  argumento de subregistro habilitado por diseño.

## 8. ICC en modelos logísticos (escala latente) y MOR

- **Goldstein H, Browne W, Rasbash J (2002).** *Partitioning variation in multilevel models.*
  Understanding Statistics 1(4):223-231. Define el VPC y los métodos de partición de varianza,
  base del ICC en la escala latente (varianza de nivel 1 fijada en pi^2/3).
- **Merlo J, Chaix B, Ohlsson H, et al. (2006).** *A brief conceptual tutorial of multilevel
  analysis in social epidemiology: using measures of clustering in multilevel logistic
  regression to investigate contextual phenomena.* J Epidemiol Community Health 60(4):290-297.
  Justifica el ICC en logística y propone el **median odds ratio (MOR)** como complemento en
  escala de OR (recomendado para blindar la interpretación).
- **Browne WJ, Subramanian SV, Jones K, Goldstein H (2005).** *Variance partitioning in
  multilevel logistic models that exhibit overdispersion.* J R Stat Soc A 168(3):599-613.
- **Austin PC, Merlo J (2017).** *Intermediate and advanced topics in multilevel logistic
  regression analysis.* Stat Med 36(20):3257-3277. Tutorial de referencia.

## 9. Aproximación de verosimilitud: Laplace, no PQL/nAGQ=0

- **Breslow NE, Clayton DG (1993).** *Approximate inference in generalized linear mixed models.*
  JASA 88(421):9-25. Introduce la PQL y advierte su sesgo.
- **Rodríguez G, Goldman N (1995).** *An assessment of estimation procedures for multilevel
  models with binary responses.* J R Stat Soc A 158(1):73-89. Muestra por simulación el sesgo
  a la baja de las componentes de varianza con respuesta binaria, justo lo que observamos con
  nAGQ=0 (ICC subestimado); sustenta usar Laplace en las cifras publicadas.
- **Bolker BM, et al. (2009).** *Generalized linear mixed models: a practical guide for ecology
  and evolution.* Trends Ecol Evol 24(3):127-135. Recomienda Laplace o cuadratura sobre PQL y
  verificar convergencia.
- **Nakagawa S, Schielzeth H (2013).** *A general and simple method for obtaining R^2 from GLMMs.*
  Methods Ecol Evol 4(2):133-142. Marco para la varianza explicada en modelos mixtos.

## 10. Comparar modelos logísticos anidados: el reescalamiento (caveat del PCV)

- **Mood C (2010).** *Logistic regression: why we cannot do what we think we can do, and what
  we can do about it.* Eur Sociol Rev 26(1):67-82. Las varianzas/coeficientes logísticos no son
  directamente comparables entre modelos por el reescalamiento de la escala latente.
- **Karlson KB, Holm A, Breen R (2012).** *Comparing regression coefficients between same-sample
  nested models using logit and probit.* Sociol Methodol 42(1):286-313. Método KHB que separa
  reescalamiento de explicación genuina (mejora opcional para la descomposición secuencial).

## 11. Datos composicionales y k-means (caveat de tipologías)

- **Aitchison J (1986).** *The Statistical Analysis of Compositional Data.* Chapman and Hall.
  Las proporciones viven en el símplex; el agrupamiento euclidiano es una aproximación, lo
  riguroso usa transformaciones de razón logarítmica (clr/ilr). Las tipologías se reportan como
  exploratorias.
- **Hartigan JA, Wong MA (1979).** *Algorithm AS 136: a k-means clustering algorithm.*
  J R Stat Soc C 28(1):100-108.

## 12. Machine learning interpretable (complemento predictivo)

- **Chen T, Guestrin C (2016).** *XGBoost: a scalable tree boosting system.* Proc. 22nd ACM
  SIGKDD, 785-794. Gradient boosting de árboles; modelo predictivo del módulo de ML.
- **Lundberg SM, Lee SI (2017).** *A unified approach to interpreting model predictions.*
  NeurIPS 30, 4765-4774. Valores SHAP (Shapley) para importancia interpretable; base de la
  lectura de variables del modelo. Se usa como complemento, no como reemplazo del inferencial.

> Ver **FUNDAMENTACION_ESTADISTICA.md** para la auditoría completa concepto por concepto
> (definición, justificación, supuestos, límites y veredicto de cada método), con la lista de
> referencias verificada en junio de 2026.

---

*Nota: las citas con URL provienen de la búsqueda de jun 2026; verificar paginación/autoría
exacta de las que se incluyan en el artículo final contra la fuente.*
