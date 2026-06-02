# =============================================================================
# 03_fonasa_inscritos.R  ·  Denominador poblacional: inscritos validados FONASA
# -----------------------------------------------------------------------------
# La poblacion INSCRITA VALIDADA per capita de FONASA es el denominador natural
# para tasas de auditoria social (reclamos por 1.000 inscritos, densidad
# participativa, etc.). FONASA la publica anualmente por establecimiento de APS
# y comuna en datos abiertos:
#   - https://datosabiertos.fonasa.cl/
#   - https://datos.gob.cl/organization/fondo_nacional_de_salud
#
# Como el portal no expone una URL CSV estable (render JS), este script LEE un
# archivo que descargues UNA vez y dejes en datos/externos/. Detecta el archivo
# automaticamente (nombre con "fonasa"/"inscrit"/"percapita") y las columnas por
# palabra clave. Si no encuentra el archivo, avisa y continua (los indicadores
# per capita quedaran como NA, el resto del pipeline NO se detiene).
#
# Coloca el archivo (CSV o XLSX) en:
#   datos/externos/poblacion_inscrita_fonasa.csv   (o .xlsx)
# Debe tener, al menos, una columna de COMUNA (codigo o nombre) y una de
# POBLACION INSCRITA. Si trae codigo de ESTABLECIMIENTO, tambien se usa.
#
# SALIDA: datos/externos/fonasa_comuna.rds  (IdComuna, inscritos)
#         datos/externos/fonasa_estab.rds   (IdEstablecimiento, inscritos)  [si hay]
# =============================================================================
library(here)
library(data.table)
suppressWarnings(suppressMessages(library(readxl)))

dir_ext <- here("datos", "externos")
cands <- list.files(dir_ext, pattern = "(fonasa|inscrit|percapita|per_capita)",
                    ignore.case = TRUE, full.names = TRUE)
cands <- cands[grepl("\\.(csv|xlsx|xls)$", cands, ignore.case = TRUE)]
cands <- cands[!grepl("\\.rds$", cands, ignore.case = TRUE)]

if (length(cands) == 0) {
  message("[FONASA] No encontre archivo de inscritos en datos/externos/.")
  message("[FONASA] Descarga 'Poblacion inscrita validada per capita' desde ",
          "https://datosabiertos.fonasa.cl/ o datos.gob.cl y dejala como ",
          "datos/externos/poblacion_inscrita_fonasa.csv")
  message("[FONASA] Los indicadores per capita quedaran como NA por ahora.")
} else {
  ruta <- cands[1]
  message("[FONASA] Leyendo: ", basename(ruta))
  if (grepl("\\.csv$", ruta, ignore.case = TRUE)) {
    dt <- tryCatch(fread(ruta, encoding = "UTF-8"), error = function(e) fread(ruta))
  } else {
    dt <- as.data.table(read_excel(ruta, sheet = 1))
  }
  setnames(dt, names(dt), trimws(names(dt)))
  norm <- function(x) tolower(iconv(x, to = "ASCII//TRANSLIT"))
  nm <- norm(names(dt))

  pick <- function(patrones) {
    for (p in patrones) { j <- which(grepl(p, nm)); if (length(j)) return(j[1]) }
    NA_integer_
  }
  j_pob   <- pick(c("inscrit.*valid", "poblacion.*inscrit", "per.?capita", "inscrit", "poblacion"))
  j_comc  <- pick(c("cod.*comuna", "comuna.*cod", "id.?comuna"))
  j_comn  <- pick(c("^comuna$", "nombre.*comuna", "glosa.*comuna", "comuna"))
  j_estc  <- pick(c("cod.*estab", "estab.*cod", "id.?estab", "codigo.*deis", "cod_centro"))

  num <- function(x) suppressWarnings(as.numeric(gsub("[^0-9]", "", as.character(x))))
  if (is.na(j_pob)) stop("[FONASA] No identifique la columna de poblacion inscrita. ",
                         "Renombra esa columna a 'poblacion_inscrita' y reintenta.")
  dt[, .inscritos := num(.SD[[1]]), .SDcols = j_pob]

  # ---- Nivel comuna ----------------------------------------------------------
  comc <- if (!is.na(j_comc)) as.integer(num(dt[[j_comc]])) else NA_integer_
  if (all(is.na(comc)) && !is.na(j_comn)) {
    # sin codigo: intentar mapear por nombre con la base de establecimientos
    est <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)
    mapa <- unique(est[!is.na(ComunaGlosa), .(ComunaGlosa, IdComuna)], by = "ComunaGlosa")
    mapa[, key := norm(ComunaGlosa)]
    dt[, key := norm(get(names(dt)[j_comn]))]
    dt <- merge(dt, mapa[, .(key, IdComuna)], by = "key", all.x = TRUE)
    comc <- dt$IdComuna
  }
  dt[, .IdComuna := comc]
  fonasa_comuna <- dt[!is.na(.IdComuna), .(inscritos = sum(.inscritos, na.rm = TRUE)),
                      by = .(IdComuna = .IdComuna)]
  saveRDS(fonasa_comuna, file.path(dir_ext, "fonasa_comuna.rds"))
  message("[FONASA] Inscritos por comuna: ", nrow(fonasa_comuna),
          " comunas, total ", format(sum(fonasa_comuna$inscritos), big.mark = "."))

  # ---- Nivel establecimiento (si hay codigo) --------------------------------
  if (!is.na(j_estc)) {
    dt[, .IdEstab := as.integer(num(get(names(dt)[j_estc])))]
    fonasa_estab <- dt[!is.na(.IdEstab), .(inscritos = sum(.inscritos, na.rm = TRUE)),
                       by = .(IdEstablecimiento = .IdEstab)]
    saveRDS(fonasa_estab, file.path(dir_ext, "fonasa_estab.rds"))
    message("[FONASA] Inscritos por establecimiento: ", nrow(fonasa_estab), " centros.")
  }
}
