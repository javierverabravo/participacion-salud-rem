# =============================================================================
# 00_descarga_datos.R
# -----------------------------------------------------------------------------
# OBJETIVO
#   Descargar automáticamente las series REM de un año desde el repositorio
#   oficial del DEIS (MINSAL) y descomprimirlas en la carpeta datos/.
#   Parametrizable por año. Funciona igual en tu PC y en la nube (GitHub
#   Actions), porque usa rutas relativas y no depende de ninguna ruta absoluta.
#
# FUENTE OFICIAL (un ZIP por año, contiene las 5 series A, BS, BM, D, P):
#   https://repositoriodeis.minsal.cl/DatosAbiertos/REM/SERIE_REM_<AÑO>.zip
#
# SALIDA: datos/<AÑO>/SerieA<AÑO>.csv, SerieBS<AÑO>.csv, ... (carpeta ignorada por Git)
# =============================================================================

# ---- 0. Paquetes -----------------------------------------------------------
# Solo 'here' para rutas portables. La descarga y el unzip usan funciones base.
# Si no lo tienes: install.packages("here")
library(here)

# ---- 1. Parámetros ---------------------------------------------------------
# Cambia 'anio' para descargar otro año. En la nube se puede pasar por variable
# de entorno (lo veremos en la Fase 4); por ahora un valor por defecto.
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))

# URL base del repositorio DEIS. El nombre del archivo depende del año.
url_base <- "https://repositoriodeis.minsal.cl/DatosAbiertos/REM"
url_zip  <- sprintf("%s/SERIE_REM_%d.zip", url_base, anio)

# Carpetas de destino (relativas al proyecto).
dir_datos <- here("datos")                 # carpeta general (ignorada por Git)
dir_anio  <- here("datos", as.character(anio))
ruta_zip  <- file.path(dir_datos, sprintf("SERIE_REM_%d.zip", anio))

dir.create(dir_anio, recursive = TRUE, showWarnings = FALSE)

# ---- 2. Descargar el ZIP (si no existe ya) ---------------------------------
# Idempotencia: si el ZIP ya está descargado, no lo bajamos de nuevo.
# Esto evita re-descargar ~1 GB en cada ejecución (importante para la nube).

# Ampliamos el límite de tiempo: un archivo grande puede tardar varios minutos.
options(timeout = max(3600, getOption("timeout")))

if (file.exists(ruta_zip)) {
  message(sprintf("El ZIP del año %d ya existe, se omite la descarga: %s",
                  anio, ruta_zip))
} else {
  message(sprintf("Descargando series REM %d desde:\n  %s", anio, url_zip))
  # mode = "wb" es OBLIGATORIO en Windows para archivos binarios (zip),
  # de lo contrario el archivo se corrompe.
  codigo <- tryCatch(
    download.file(url = url_zip, destfile = ruta_zip, mode = "wb", quiet = FALSE),
    error = function(e) {
      stop(sprintf(
        "No se pudo descargar el archivo del año %d.\n  URL: %s\n  Error: %s\n  Verifica que el año exista en el repositorio del DEIS.",
        anio, url_zip, conditionMessage(e)))
    }
  )
}

# ---- 3. Descomprimir -------------------------------------------------------
# Listamos el contenido del ZIP y lo extraemos en datos/<AÑO>/.
contenido <- unzip(ruta_zip, list = TRUE)
message("\nArchivos dentro del ZIP:")
print(contenido[, c("Name", "Length")])

unzip(ruta_zip, exdir = dir_anio, overwrite = TRUE)

# ---- 4. Verificación -------------------------------------------------------
# Comprobamos que quedaron los CSV esperados y avisamos su tamaño.
csv_extraidos <- list.files(dir_anio, pattern = "\\.csv$", full.names = TRUE,
                            recursive = TRUE)

if (length(csv_extraidos) == 0) {
  stop("La descompresión no dejó ningún CSV. Revisa el contenido del ZIP.")
}

cat("\nDescarga y descompresión OK. CSV disponibles en datos/", anio, ":\n", sep = "")
for (f in csv_extraidos) {
  cat(sprintf("  - %s (%.1f MB)\n", basename(f), file.size(f) / 1e6))
}

# Devolvemos las rutas para que el script maestro las use si hace falta.
invisible(csv_extraidos)
