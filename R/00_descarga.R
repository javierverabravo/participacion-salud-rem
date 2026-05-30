# =============================================================================
# 00_descarga.R  ·  Descarga de datos desde el DEIS (MINSAL)
# -----------------------------------------------------------------------------
# Descarga, si no existen ya, las dos fuentes oficiales:
#   1. Series REM del año (ZIP que contiene las 5 series CSV + diccionarios).
#   2. Base maestra de establecimientos (tipo, dependencia, nivel, coordenadas).
# Parametrizable por año mediante la variable de entorno REM_ANIO.
# =============================================================================
library(here)
options(timeout = max(3600, getOption("timeout")))
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))

# ---- 1. Series REM ---------------------------------------------------------
dir_anio <- here("datos", as.character(anio))
dir.create(dir_anio, recursive = TRUE, showWarnings = FALSE)
ruta_zip <- here("datos", sprintf("SERIE_REM_%d.zip", anio))

if (!file.exists(ruta_zip)) {
  url_zip <- sprintf(
    "https://repositoriodeis.minsal.cl/DatosAbiertos/REM/SERIE_REM_%d.zip", anio)
  message("Descargando series REM ", anio, "...")
  download.file(url_zip, ruta_zip, mode = "wb")
}
if (length(list.files(dir_anio, pattern = "\\.csv$", recursive = TRUE)) == 0) {
  unzip(ruta_zip, exdir = dir_anio, overwrite = TRUE)
}

# ---- 2. Base maestra de establecimientos -----------------------------------
# Nota: la URL del DEIS incluye una fecha que cambia al actualizar la base.
# Si fallara, busca la versión vigente en datos.gob.cl ("Establecimientos de
# Salud vigentes") y reemplaza esta URL.
ruta_estab <- here("datos", "establecimientos_maestra.csv")
if (!file.exists(ruta_estab)) {
  url_estab <- paste0("https://datos.gob.cl/dataset/",
    "3bf4cf7c-f638-4735-9a01-f65faae4beca/resource/",
    "2c44d782-3365-44e3-aefb-2c8b8363a1bc/download/establecimientos_20260325.csv")
  message("Descargando base maestra de establecimientos...")
  download.file(url_estab, ruta_estab, mode = "wb")
}

message("Descarga lista. Datos en datos/", anio, "/")
