# =============================================================================
# 02_datos_comunales.R  ·  Determinantes sociales por comuna (CASEN 2024)
# -----------------------------------------------------------------------------
# Descarga y procesa las ESTIMACIONES DE POBREZA COMUNAL (CASEN 2024, areas
# pequenas SAE) del Observatorio Social (MDSF): pobreza por ingresos y pobreza
# multidimensional. El codigo de comuna coincide con IdComuna del REM, asi que
# sirve de covariable de contexto en el modelo multinivel y de insumo para los
# indicadores de auditoria social.
#
# ACTUALIZACION: antes se usaba CASEN 2020 (revisada 2022); ahora CASEN 2024,
# publicada en enero 2026 (la estimacion comunal mas reciente).
#
# Lector ROBUSTO: detecta automaticamente la columna de codigo de comuna
# (4-5 digitos), la tasa de pobreza (proporcion 0-1) y la poblacion, para no
# depender de la posicion exacta de las columnas si MDSF cambia el formato.
#
# SALIDA: datos/externos/comunal.rds + productos/determinantes_comuna.csv
# =============================================================================
library(here)
library(readxl)
library(data.table)

dir.create(here("datos", "externos"), recursive = TRUE, showWarnings = FALSE)
options(timeout = max(600, getOption("timeout")))
base_url <- paste0("https://observatorio.ministeriodesarrollosocial.gob.cl/",
                   "storage/docs/pobreza-comunal/2024/")
fuentes <- list(
  ingresos = list(url = paste0(base_url, "SAE_ingresos_2024.xlsx"),
                  file = here("datos", "externos", "pobreza_ingresos_2024.xlsx")),
  multi    = list(url = paste0(base_url, "SAE_multidimensional_2024.xlsx"),
                  file = here("datos", "externos", "pobreza_multi_2024.xlsx")))
for (f in fuentes) if (!file.exists(f$file))
  try(download.file(f$url, f$file, mode = "wb"), silent = TRUE)

# ---- Lector robusto de un archivo SAE comunal ------------------------------
leer_sae <- function(ruta) {
  if (!file.exists(ruta)) return(NULL)
  raw <- suppressMessages(as.data.table(read_excel(ruta, sheet = 1, col_names = FALSE)))
  M <- raw[, lapply(.SD, as.character)]
  es_cod <- function(x) !is.na(x) & grepl("^[0-9]{4,5}$", trimws(x))
  conteo <- vapply(M, function(x) sum(es_cod(x)), integer(1))
  col_cod <- which.max(conteo)
  if (max(conteo) < 100) { warning("No se detecto columna de comuna en ", basename(ruta)); return(NULL) }
  fil <- which(es_cod(M[[col_cod]])); dat <- M[fil]
  rate <- function(x) suppressWarnings(as.numeric(gsub(",", ".", trimws(x))))     # proporciones
  popn <- function(x) suppressWarnings(as.numeric(gsub("[^0-9]", "", x)))         # enteros con miles
  cand