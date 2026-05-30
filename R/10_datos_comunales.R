# =============================================================================
# 10_datos_comunales.R  ·  Datos socioeconómicos por comuna
# -----------------------------------------------------------------------------
# Descarga y procesa la base de POBREZA COMUNAL (CASEN, estimación de áreas
# pequeñas SAE) y construye una tabla comunal con: código de comuna, población
# y tasa de pobreza por ingresos. El código de comuna coincide con el IdComuna
# del REM, así que servirá de covariable de contexto en el modelo multinivel.
#
# SALIDA: datos/externos/comunal.rds + productos/determinantes_comuna.csv
# =============================================================================
library(here)
library(readxl)
library(data.table)

dir.create(here("datos", "externos"), recursive = TRUE, showWarnings = FALSE)
ruta_pob <- here("datos", "externos", "pobreza_comunal.xlsx")
url_pob <- paste0("https://observatorio.ministeriodesarrollosocial.gob.cl/",
  "storage/docs/pobreza-comunal/2020/",
  "Estimaciones_de_Tasa_de_Pobreza_por_Ingresos_por_Comunas_2020_revisada2022_09.xlsx")
options(timeout = max(600, getOption("timeout")))
if (!file.exists(ruta_pob)) download.file(url_pob, ruta_pob, mode = "wb")

# ---- 1. Extraer (encabezado en fila 3 -> saltamos 3 filas) -----------------
crudo <- read_excel(ruta_pob, sheet = 1, skip = 3, col_names = FALSE)
setDT(crudo)
# Asignamos nombres por posición (según la estructura inspeccionada).
setnames(crudo, 1:6, c("cod", "region_txt", "comuna", "poblacion",
                       "n_pobreza", "pct_pobreza"))
comunal <- crudo[!is.na(cod), .(
  IdComuna   = as.integer(cod),
  comuna     = comuna,
  poblacion  = as.numeric(poblacion),
  pct_pobreza = round(100 * as.numeric(pct_pobreza), 1))]
comunal <- comunal[!is.na(IdComuna)]

saveRDS(comunal, here("datos", "externos", "comunal.rds"))
fwrite(comunal, here("productos", "determinantes_comuna.csv"), sep = ";", bom = TRUE)

# ---- 2. Validación ---------------------------------------------------------
cat(sprintf("Comunas con datos de pobreza: %d\n", nrow(comunal)))
cat("Resumen de la tasa de pobreza (%):\n"); print(summary(comunal$pct_pobreza))

# Match con las comunas del REM.
est <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)
com_rem <- unique(est$IdComuna)
cat(sprintf("\nComunas del REM que cruzan con pobreza: %d de %d (%.1f%%)\n",
            sum(com_rem %in% comunal$IdComuna), length(com_rem),
            100 * mean(com_rem %in% comunal$IdComuna)))
cat("\nComunas más pobres:\n"); print(head(comunal[order(-pct_pobreza)], 6))
cat("\nComunas menos pobres:\n"); print(head(comunal[order(pct_pobreza)], 6))
