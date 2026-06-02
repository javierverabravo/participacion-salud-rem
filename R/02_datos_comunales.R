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
  cand <- setdiff(seq_along(M), col_cod)
  med_rate <- vapply(cand, function(j) median(rate(dat[[j]]), na.rm = TRUE), numeric(1))
  med_pop  <- vapply(cand, function(j) median(popn(dat[[j]]), na.rm = TRUE), numeric(1))
  col_rate <- cand[which(med_rate > 0 & med_rate < 1)][1]            # tasa como proporcion
  if (is.na(col_rate)) col_rate <- cand[which(med_rate >= 1 & med_rate < 80)][1] # o ya en %
  col_pop  <- cand[which(med_pop > 500)][1]
  es_txt   <- vapply(cand, function(j) mean(is.na(rate(dat[[j]])) & nzchar(dat[[j]])) > 0.7, logical(1))
  col_name <- cand[which(es_txt)][1]
  factor_rate <- if (!is.na(col_rate) && median(rate(dat[[col_rate]]), na.rm = TRUE) < 1) 100 else 1
  out <- data.table(
    IdComuna = as.integer(dat[[col_cod]]),
    comuna   = if (!is.na(col_name)) dat[[col_name]] else NA_character_,
    poblacion = if (!is.na(col_pop)) popn(dat[[col_pop]]) else NA_real_,
    tasa = if (!is.na(col_rate)) round(factor_rate * rate(dat[[col_rate]]), 1) else NA_real_)
  message("  ", basename(ruta), ": ", nrow(out), " comunas | col_cod=", col_cod,
          " col_tasa=", col_rate, " col_pob=", col_pop)
  out[!is.na(IdComuna)]
}

ing <- leer_sae(fuentes$ingresos$file)
mul <- leer_sae(fuentes$multi$file)
if (is.null(ing)) stop("No se pudo leer la pobreza por ingresos CASEN 2024. ",
                       "Descarga manual: ", fuentes$ingresos$url)

comunal <- ing[, .(IdComuna, comuna, poblacion, pct_pobreza = tasa)]
if (!is.null(mul))
  comunal <- merge(comunal, mul[, .(IdComuna, pct_pobreza_multi = tasa)],
                   by = "IdComuna", all.x = TRUE)

saveRDS(comunal, here("datos", "externos", "comunal.rds"))
fwrite(comunal, here("productos", "determinantes_comuna.csv"), sep = ";", bom = TRUE)

# ---- Validacion ------------------------------------------------------------
cat(sprintf("Comunas con pobreza CASEN 2024: %d\n", nrow(comunal)))
cat("Resumen tasa de pobreza por ingresos (%):\n"); print(summary(comunal$pct_pobreza))
est <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)
com_rem <- unique(est$IdComuna)
cat(sprintf("\nComunas del REM que cruzan con pobreza: %d de %d (%.1f%%)\n",
            sum(com_rem %in% comunal$IdComuna), length(com_rem),
            100 * mean(com_rem %in% comunal$IdComuna)))
cat("\nComunas mas pobres (ingresos):\n"); print(head(comunal[order(-pct_pobreza)], 6))
