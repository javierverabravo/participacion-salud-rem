# =============================================================================
# 01_procesamiento.R  ·  Limpieza y construcción de los datasets analíticos
# -----------------------------------------------------------------------------
# A partir de los datos crudos descargados, produce:
#   - crosswalk/crosswalk_participacion_A19b.csv : código -> prestación -> tema
#   - datos/<AÑO>/participacion_A19b.rds          : Serie A filtrada a participación
#   - datos/<AÑO>/participacion_largo.rds         : formato largo etiquetado
#   - datos/establecimientos_lookup.rds           : atributos por establecimiento
#
# Usa el crosswalk de columnas (crosswalk/crosswalk_columnas_A19b.csv), un
# archivo curado a partir del diccionario oficial (estable mientras MINSAL no
# cambie la estructura del formulario A19b).
# =============================================================================
library(here)
library(readxl)
library(data.table)
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))

# ---- 1. Crosswalk de prestaciones (desde el diccionario A19b) ---------------
ruta_dicc <- here("Diccionarios", "DICCIONARIO CODIGOS SA_25_V1.5.xlsm")
crudo <- as.data.table(read_excel(ruta_dicc, sheet = "A19b",
                                  col_names = FALSE, col_types = "text"))
colA <- crudo[[1]]; colB <- crudo[[2]]
seccion <- NA_character_; en_elim <- FALSE; filas <- list()
for (i in seq_len(nrow(crudo))) {
  a <- trimws(ifelse(is.na(colA[i]), "", colA[i]))
  b <- trimws(ifelse(is.na(colB[i]), "", colB[i]))
  if (grepl("^C[OÓ]DIGOS ELIMINADOS", a, ignore.case = TRUE)) { en_elim <- TRUE; next }
  if (grepl("^C[OÓ]DIGOS NUEVOS",    a, ignore.case = TRUE)) { en_elim <- FALSE; next }
  if (grepl("^SECC", b, ignore.case = TRUE)) { seccion <- b; next }
  if (grepl("^[0-9]{8}$", a) && !en_elim && !(b %in% c("", "0")))
    filas[[length(filas) + 1]] <- data.table(codigo = a, descripcion = b, seccion = seccion)
}
crosswalk <- unique(rbindlist(filas), by = "codigo")
crosswalk[, tema := fcase(
  grepl("SECCIÓN A", seccion), "OIRS / Reclamos y solicitudes",
  grepl("SECCIÓN B", seccion), "Participación social",
  grepl("SECCIÓN C", seccion), "Satisfacción usuaria y humanización",
  default = "Otra")]
crosswalk[, `:=`(serie = "A", seccion_rem = "A19b")]
dir.create(here("crosswalk"), showWarnings = FALSE)
fwrite(crosswalk, here("crosswalk", "crosswalk_participacion_A19b.csv"),
       sep = ";", bom = TRUE)
message("Crosswalk de prestaciones: ", nrow(crosswalk), " códigos activos.")

# ---- 2. Leer y filtrar la Serie A a participación --------------------------
ruta_serieA <- list.files(here("datos", as.character(anio)),
                          pattern = sprintf("SerieA%d\\.csv$", anio),
                          full.names = TRUE, recursive = TRUE)[1]
serieA <- fread(ruta_serieA, sep = ";", encoding = "UTF-8",
                colClasses = list(character = "CodigoPrestacion"))
part <- serieA[CodigoPrestacion %chin% crosswalk$codigo]
rm(serieA); gc()
part <- merge(part, crosswalk[, .(codigo, descripcion, tema, seccion)],
              by.x = "CodigoPrestacion", by.y = "codigo", all.x = TRUE, sort = FALSE)
setnames(part, "Col01", "valor_total")
part[, reporto := !is.na(valor_total)]
part[, es_cero := (!is.na(valor_total) & valor_total == 0)]
part[, fecha := as.Date(sprintf("%d-%02d-01", Ano, Mes))]
saveRDS(part, here("datos", as.character(anio), "participacion_A19b.rds"))
message("Participación A19b: ", format(nrow(part), big.mark = "."), " filas.")

# ---- 3. Formato largo etiquetado (desagregaciones Col01..Col50) ------------
cw_col <- fread(here("crosswalk", "crosswalk_columnas_A19b.csv"),
                sep = ";", encoding = "UTF-8")
part[, Col01 := valor_total]
part[, seccion_key := sub("^[^ ]+ ([A-Z](\\.[0-9])?):.*$", "\\1", seccion)]
cols_valor <- sprintf("Col%02d", 1:50)
part[, (cols_valor) := lapply(.SD, as.numeric), .SDcols = cols_valor]
largo <- melt(part,
  id.vars = c("IdEstablecimiento", "Mes", "IdRegion", "IdComuna",
              "CodigoPrestacion", "tema", "seccion_key", "descripcion"),
  measure.vars = cols_valor, variable.name = "col", value.name = "valor")
largo <- largo[!is.na(valor)]
largo[, col := as.character(col)]
largo <- merge(largo, cw_col, by = c("seccion_key", "col"), all.x = TRUE, sort = FALSE)
saveRDS(largo, here("datos", as.character(anio), "participacion_largo.rds"))
message("Tabla larga: ", format(nrow(largo), big.mark = "."), " filas.")

# ---- 4. Cruce con la base maestra de establecimientos ----------------------
attrs <- c("TipoEstablecimientoGlosa", "DependenciaAdministrativa",
           "NivelAtencionEstabglosa", "NivelComplejidadEstabGlosa",
           "TipoPertenenciaEstabGlosa", "ComunaGlosa", "RegionGlosa",
           "Latitud", "Longitud", "EstadoFuncionamiento")
maestra <- fread(here("datos", "establecimientos_maestra.csv"), sep = ";",
                 encoding = "UTF-8",
                 select = c("EstablecimientoCodigo", "EstablecimientoCodigoAntiguo", attrs),
                 colClasses = "character")
l1 <- copy(maestra[EstablecimientoCodigo != ""]);            l1[, cod := EstablecimientoCodigo]
l2 <- copy(maestra[!is.na(EstablecimientoCodigoAntiguo) & EstablecimientoCodigoAntiguo != ""])
l2[, cod := EstablecimientoCodigoAntiguo]
lookup <- unique(rbindlist(list(l1, l2))[, c("cod", attrs), with = FALSE], by = "cod")

universo <- fread(ruta_serieA, sep = ";", encoding = "UTF-8",
                  select = c("IdEstablecimiento", "IdRegion", "IdComuna"))
universo <- unique(universo, by = "IdEstablecimiento")
universo[, cod := as.character(IdEstablecimiento)]
est <- merge(universo, lookup, by = "cod", all.x = TRUE, sort = FALSE)
saveRDS(est, here("datos", "establecimientos_lookup.rds"))
message("Establecimientos cruzados: ",
        round(100 * mean(!is.na(est$TipoEstablecimientoGlosa)), 1), "% match.")
