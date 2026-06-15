# =============================================================================
# manifiesto_datos.R  ·  Manifiesto de procedencia de los insumos
# -----------------------------------------------------------------------------
# Recorre los archivos de datos crudos, calcula su tamano y su huella (sha256 si
# esta el paquete digest, si no md5 de base R), registra la fecha de descarga
# (fecha de modificacion del archivo) y escribe un manifiesto reproducible en
# PROCEDENCIA.csv y PROCEDENCIA.md (en la raiz del proyecto, versionados).
#
# Por que: los datos del DEIS son preliminares y cambian en fechas indeterminadas.
# El manifiesto ancla "esta version del dato (esta huella) genero estas cifras".
# Re-ejecutable: corre cuando quieras, idealmente despues de 00_descarga.R.
#
# Uso (consola de R, desde la raiz del proyecto):  source("R/manifiesto_datos.R")
# Para el 2026 preliminar:  Sys.setenv(REM_ANIO = "2026"); source("R/manifiesto_datos.R")
# =============================================================================
library(here)
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))

# ---- Catalogo de insumos esperados (metadatos curados a mano) --------------
# Cada fila es una fuente. Las rutas que no existan se registran como
# "no encontrado" (degrada con elegancia, no aborta).
insumos <- list(
  list(fuente = "REM (zip anual)",
       organizacion = "DEIS, Ministerio de Salud",
       url = sprintf("https://repositoriodeis.minsal.cl/DatosAbiertos/REM/SERIE_REM_%d.zip", anio),
       licencia = "Datos abiertos DEIS (ver LICENSES.md)",
       ruta = here("datos", sprintf("SERIE_REM_%d.zip", anio))),
  list(fuente = "REM Serie A (csv)",
       organizacion = "DEIS, Ministerio de Salud",
       url = "(extraido del zip)",
       licencia = "Datos abiertos DEIS",
       ruta = list.files(here("datos", as.character(anio)),
                         pattern = sprintf("SerieA%d\\.csv$", anio),
                         full.names = TRUE, recursive = TRUE)),
  list(fuente = "Base maestra establecimientos",
       organizacion = "datos.gob.cl (Estado de Chile)",
       url = "https://datos.gob.cl/ (Establecimientos de Salud vigentes)",
       licencia = "Datos abiertos",
       ruta = here("datos", "establecimientos_maestra.csv")),
  list(fuente = "CASEN SAE ingresos",
       organizacion = "Observatorio Social, MDSF",
       url = "https://observatorio.ministeriodesarrollosocial.gob.cl/",
       licencia = "Datos abiertos CASEN",
       ruta = here("datos", "externos", "pobreza_ingresos_2024.xlsx")),
  list(fuente = "CASEN SAE multidimensional",
       organizacion = "Observatorio Social, MDSF",
       url = "https://observatorio.ministeriodesarrollosocial.gob.cl/",
       licencia = "Datos abiertos CASEN",
       ruta = here("datos", "externos", "pobreza_multi_2024.xlsx")),
  list(fuente = "FONASA beneficiarios por comuna",
       organizacion = "FONASA",
       url = "https://datosabiertos.fonasa.cl/dimensiones-beneficiarios/",
       licencia = "Datos abiertos FONASA",
       ruta = c(here("Beneficiarios 2025.csv"),
                here("datos", "externos", "fonasa_comuna.rds")))
)

# ---- Huella: sha256 si hay digest, si no md5 de base R ---------------------
tiene_digest <- requireNamespace("digest", quietly = TRUE)
huella <- function(f) {
  if (tiene_digest) list(algo = "sha256",
                         valor = digest::digest(file = f, algo = "sha256"))
  else list(algo = "md5", valor = unname(tools::md5sum(f)))
}

filas <- list()
for (ins in insumos) {
  rutas <- ins$ruta
  rutas <- rutas[!is.na(rutas) & nzchar(rutas)]
  encontrada <- rutas[file.exists(rutas)][1]
  if (is.na(encontrada)) {
    filas[[length(filas) + 1]] <- data.frame(
      fuente = ins$fuente, organizacion = ins$organizacion, url = ins$url,
      licencia = ins$licencia, archivo = NA, estado = "no encontrado",
      bytes = NA, algo = NA, huella = NA, fecha_descarga = NA,
      stringsAsFactors = FALSE)
    next
  }
  fi <- file.info(encontrada)
  h  <- huella(encontrada)
  filas[[length(filas) + 1]] <- data.frame(
    fuente = ins$fuente, organizacion = ins$organizacion, url = ins$url,
    licencia = ins$licencia, archivo = basename(encontrada), estado = "ok",
    bytes = fi$size, algo = h$algo, huella = h$valor,
    fecha_descarga = format(fi$mtime, "%Y-%m-%d %H:%M"),
    stringsAsFactors = FALSE)
}
man <- do.call(rbind, filas)
man$anio_rem          <- anio
man$fecha_manifiesto  <- format(Sys.time(), "%Y-%m-%d %H:%M")
man$fecha_corte_fuente <- ""   # rellenar a mano: fecha de corte que declara la fuente

# Se escriben en la RAIZ del proyecto (no en datos/, que esta en .gitignore):
# el manifiesto debe versionarse, es el registro de procedencia.
write.csv2(man, here("PROCEDENCIA.csv"),
           row.names = FALSE, fileEncoding = "UTF-8")

# ---- Version humana (PROCEDENCIA.md) ---------------------------------------
fmt_bytes <- function(x) if (is.na(x)) "-" else formatC(x, format = "d", big.mark = ".")
con <- file(here("PROCEDENCIA.md"), open = "w", encoding = "UTF-8")
writeLines(c(
  "# Manifiesto de procedencia de los datos",
  "",
  sprintf("Generado por `R/manifiesto_datos.R` el %s. Ano REM: %d.",
          format(Sys.time(), "%Y-%m-%d %H:%M"), anio),
  sprintf("Tipo de huella: %s.",
          if (tiene_digest) "sha256" else "md5 (instala el paquete digest para sha256)"),
  "",
  "Este manifiesto ancla que version exacta de cada insumo produjo las cifras.",
  "Si el portal actualiza un archivo, su huella cambia y queda registro del cambio.",
  "",
  "| Fuente | Archivo | Estado | Bytes | Huella (abrev.) | Descargado |",
  "|---|---|---|---:|---|---|"), con)
for (i in seq_len(nrow(man))) {
  writeLines(sprintf("| %s | %s | %s | %s | %s | %s |",
    man$fuente[i], ifelse(is.na(man$archivo[i]), "-", man$archivo[i]),
    man$estado[i], fmt_bytes(man$bytes[i]),
    ifelse(is.na(man$huella[i]), "-", substr(man$huella[i], 1, 16)),
    ifelse(is.na(man$fecha_descarga[i]), "-", man$fecha_descarga[i])), con)
}
writeLines(c("",
  "Nota: rellena `fecha_corte_fuente` en PROCEDENCIA.csv con la fecha de corte que",
  "declara cada portal (por ejemplo, FONASA beneficiarios a diciembre 2025). Para",
  "el REM preliminar, ver tambien corte_<ano>.csv del monitoreo 2026.",
  "La huella completa esta en PROCEDENCIA.csv; aqui se muestra abreviada."), con)
close(con)

message("Manifiesto escrito: PROCEDENCIA.csv y PROCEDENCIA.md (",
        sum(man$estado == "ok"), " de ", nrow(man), " insumos encontrados).")
