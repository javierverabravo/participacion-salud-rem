# =============================================================================
# 03_fonasa_inscritos.R  ·  Denominador poblacional: beneficiarios FONASA
# -----------------------------------------------------------------------------
# La poblacion FONASA (beneficiarios) por comuna es el denominador natural para
# las tasas de auditoria social (reclamos por 1.000, densidad participativa...).
# FONASA publica los beneficiarios en datos abiertos, pero el portal no expone
# una URL CSV estable (render JS), asi que este archivo se DESCARGA A MANO y se
# deja en el proyecto. El script lo detecta solo.
#
# COLOCA el archivo (CSV o XLSX) en la raiz del proyecto o en datos/externos/.
# Sirve cualquiera cuyo nombre contenga "fonasa", "beneficiario" o "inscrit".
# Formato esperado (flexible): una fila por desagregacion, con al menos una
# columna de COMUNA (nombre o codigo) y una de conteo (BENEFICIARIOS / inscritos).
# Ejemplo validado: "Beneficiarios 2025.csv" (comuna x sexo x edad x tramo).
#
# Si no encuentra el archivo, avisa y continua: los indicadores per capita
# quedan en NA y 05_indicadores cae al proxy de poblacion CASEN. El resto del
# pipeline NO se detiene.
#
# SALIDA: datos/externos/fonasa_comuna.rds  (IdComuna, inscritos)
# =============================================================================
library(here)
library(data.table)
suppressWarnings(suppressMessages(library(readxl)))

norm    <- function(x) tolower(trimws(iconv(x, to = "ASCII//TRANSLIT")))
dir_ext <- here("datos", "externos")
dir.create(dir_ext, showWarnings = FALSE, recursive = TRUE)

buscar <- function(dir) {
  if (!dir.exists(dir)) return(character(0))
  f <- list.files(dir, pattern = "(fonasa|beneficiario|inscrit|percapita|per_capita)",
                  ignore.case = TRUE, full.names = TRUE)
  f[grepl("\\.(csv|xlsx|xls)$", f, ignore.case = TRUE)]
}
cands <- unique(c(buscar(dir_ext), buscar(here())))

if (length(cands) == 0) {
  message("[FONASA] No encontre archivo de beneficiarios/inscritos.")
  message("[FONASA] Deja el CSV (p.ej. 'Beneficiarios 2025.csv') en la raiz del ",
          "proyecto o en datos/externos/. Los indicadores per capita quedaran en NA.")
} else {
  ruta <- cands[1]
  message("[FONASA] Leyendo: ", basename(ruta))
  dt <- if (grepl("\\.csv$", ruta, ignore.case = TRUE))
          tryCatch(fread(ruta, encoding = "UTF-8"), error = function(e) fread(ruta))
        else as.data.table(read_excel(ruta, sheet = 1))
  setnames(dt, names(dt), trimws(names(dt)))
  nm <- norm(names(dt))
  pick <- function(patrones) {
    for (p in patrones) { j <- which(grepl(p, nm)); if (length(j)) return(j[1]) }
    NA_integer_
  }
  j_pob  <- pick(c("beneficiario", "inscrit.*valid", "poblacion.*inscrit", "inscrit",
                   "per.?capita", "poblacion"))
  j_comc <- pick(c("cod.*comuna", "comuna.*cod", "id.?comuna"))
  j_comn <- pick(c("^comuna$", "nombre.*comuna", "glosa.*comuna", "comuna"))
  if (is.na(j_pob))
    stop("[FONASA] No identifique la columna de beneficiarios/poblacion. ",
         "Renombra esa columna a 'beneficiarios' y reintenta.")
  col_pob  <- names(dt)[j_pob]
  col_comn <- if (!is.na(j_comn)) names(dt)[j_comn] else NA_character_
  num <- function(x) suppressWarnings(as.numeric(gsub("[^0-9.-]", "", as.character(x))))
  dt[, .inscritos := num(get(col_pob))]

  if (!is.na(j_comc)) {
    dt[, .IdComuna := as.integer(num(get(names(dt)[j_comc])))]
  } else if (!is.na(col_comn)) {
    # Sin codigo de comuna: mapear por NOMBRE contra la base de establecimientos.
    est  <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)
    mapa <- unique(est[!is.na(ComunaGlosa) & ComunaGlosa != "", .(ComunaGlosa, IdComuna)],
                   by = "ComunaGlosa")
    mapa[, key := norm(ComunaGlosa)]
    dt[, key := norm(get(col_comn))]
    dt <- merge(dt, mapa[, .(key, IdComuna)], by = "key", all.x = TRUE)
    dt[, .IdComuna := IdComuna]
    nmatch <- dt[, uniqueN(key[!is.na(.IdComuna)])]; ntot <- dt[, uniqueN(key)]
    message(sprintf("[FONASA] Comunas mapeadas por nombre: %d de %d (%.0f%%).",
                    nmatch, ntot, 100 * nmatch / ntot))
    sin <- unique(dt[is.na(.IdComuna), get(col_comn)])
    if (length(sin)) message("[FONASA] Sin match (revisar): ",
                             paste(head(sin, 12), collapse = ", "))
  } else stop("[FONASA] No identifique columna de comuna en el archivo.")

  fonasa_comuna <- dt[!is.na(.IdComuna) & !is.na(.inscritos),
                      .(inscritos = sum(.inscritos, na.rm = TRUE)),
                      by = .(IdComuna = .IdComuna)]
  saveRDS(fonasa_comuna, file.path(dir_ext, "fonasa_comuna.rds"))
  message("[FONASA] Inscritos por comuna: ", nrow(fonasa_comuna), " comunas, total ",
          format(sum(fonasa_comuna$inscritos), big.mark = "."), " beneficiarios.")
}
