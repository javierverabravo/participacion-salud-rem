# =============================================================================
# 08_establecimientos.R
# -----------------------------------------------------------------------------
# OBJETIVO
#   Descargar la BASE MAESTRA DE ESTABLECIMIENTOS del DEIS (datos abiertos) y
#   cruzarla con los establecimientos del REM para incorporar características
#   que el REM no trae: TIPO de establecimiento, DEPENDENCIA administrativa,
#   NIVEL de atención y complejidad, y coordenadas. Estas variables son
#   candidatas a explicar la heterogeneidad "entre establecimientos" del modelo.
#
#   El cruce se hace contra el código nuevo Y el antiguo, porque el REM puede
#   usar cualquiera de los dos.
#
# SALIDA : datos/establecimientos_lookup.rds  (IdEstablecimiento -> atributos)
#          productos/cobertura_tipo.csv, productos/establecimientos_resumen.csv
# =============================================================================

library(here)
library(data.table)

dir_prod <- here("productos")
dir.create(dir_prod, showWarnings = FALSE)
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))

# ---- 1. Descargar la base maestra (si no existe) ---------------------------
# Nota: la URL del DEIS incluye una fecha que cambia cuando actualizan la base.
# Si fallara, busca la versión vigente en datos.gob.cl ("Establecimientos de
# Salud vigentes") y reemplaza esta URL.
url_estab <- paste0("https://datos.gob.cl/dataset/",
  "3bf4cf7c-f638-4735-9a01-f65faae4beca/resource/",
  "2c44d782-3365-44e3-aefb-2c8b8363a1bc/download/establecimientos_20260325.csv")
ruta_estab <- here("datos", "establecimientos_maestra.csv")

options(timeout = max(600, getOption("timeout")))
if (!file.exists(ruta_estab)) {
  message("Descargando base maestra de establecimientos...")
  download.file(url_estab, ruta_estab, mode = "wb")
}

# ---- 2. Leer columnas relevantes -------------------------------------------
# encoding: probamos UTF-8 (el portal lo entrega así); si vieras acentos rotos,
# cambia a "Latin-1".
cols <- c("EstablecimientoCodigo", "EstablecimientoCodigoAntiguo",
          "TipoEstablecimientoGlosa", "DependenciaAdministrativa",
          "NivelAtencionEstabglosa", "NivelComplejidadEstabGlosa",
          "TipoPertenenciaEstabGlosa", "ComunaGlosa", "RegionGlosa",
          "Latitud", "Longitud", "EstadoFuncionamiento")
maestra <- fread(ruta_estab, sep = ";", encoding = "UTF-8",
                 select = cols, colClasses = "character")

# ---- 3. Construir un lookup por código (nuevo Y antiguo) -------------------
# Creamos una fila por cada código posible (nuevo y antiguo), apuntando a los
# mismos atributos, para poder cruzar con cualquiera de los dos.
attrs <- c("TipoEstablecimientoGlosa", "DependenciaAdministrativa",
           "NivelAtencionEstabglosa", "NivelComplejidadEstabGlosa",
           "TipoPertenenciaEstabGlosa", "ComunaGlosa", "RegionGlosa",
           "Latitud", "Longitud", "EstadoFuncionamiento")

l_nuevo <- copy(maestra[EstablecimientoCodigo != ""])
l_nuevo[, cod := EstablecimientoCodigo]
l_ant <- copy(maestra[!is.na(EstablecimientoCodigoAntiguo) &
                        EstablecimientoCodigoAntiguo != ""])
l_ant[, cod := EstablecimientoCodigoAntiguo]

lookup <- rbindlist(list(l_nuevo, l_ant))[, c("cod", attrs), with = FALSE]
lookup <- unique(lookup, by = "cod")

# ---- 4. Cruzar con el universo de establecimientos del REM -----------------
ruta_serieA <- list.files(here("datos", as.character(anio)),
                          pattern = sprintf("SerieA%d\\.csv$", anio),
                          full.names = TRUE, recursive = TRUE)[1]
universo <- unique(fread(ruta_serieA, sep = ";", encoding = "UTF-8",
                         select = "IdEstablecimiento"))
universo[, cod := as.character(IdEstablecimiento)]

est <- merge(universo, lookup, by = "cod", all.x = TRUE, sort = FALSE)

# Tasa de match (cuántos establecimientos del REM encontraron sus atributos).
match_pct <- round(100 * mean(!is.na(est$TipoEstablecimientoGlosa)), 1)
cat(sprintf("Match con la base maestra: %.1f%% (%d de %d establecimientos)\n",
            match_pct, sum(!is.na(est$TipoEstablecimientoGlosa)), nrow(est)))

saveRDS(est, here("datos", "establecimientos_lookup.rds"))

# ---- 5. Distribución de tipos (validación + insumo dashboard) --------------
cat("\nTipos de establecimiento en el REM:\n")
tipos <- est[!is.na(TipoEstablecimientoGlosa),
             .N, by = TipoEstablecimientoGlosa][order(-N)]
print(tipos)
fwrite(tipos, file.path(dir_prod, "establecimientos_resumen.csv"),
       sep = ";", bom = TRUE)

cat("\nDependencia administrativa:\n")
print(est[!is.na(DependenciaAdministrativa),
          .N, by = DependenciaAdministrativa][order(-N)])
