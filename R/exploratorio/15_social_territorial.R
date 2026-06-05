# =============================================================================
# 15_social_territorial.R  ·  ¿Los TIPOS de participación social cambian por región?
# -----------------------------------------------------------------------------
# Caracteriza la COMPOSICIÓN de la participación social (sus tipologías/instancias)
# en cada región: qué % de la actividad social de la región corresponde a cada
# instancia (COSOC, CDL, cabildos, indígena, jóvenes, TICs, etc.). Revela patrones
# territoriales , p. ej. instancias indígenas concentradas en el sur.
#
# ENTRADA : datos/<AÑO>/participacion_largo.rds
# SALIDA  : productos/social_region_instancia.csv  (IdRegion x instancia, % y total)
# =============================================================================
library(here)
library(data.table)
dir_prod <- here("productos")

anio  <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
largo <- readRDS(here("datos", as.character(anio), "participacion_largo.rds")); setDT(largo)

soc <- largo[seccion_key == "B.1" & dimension == "instancia"]
ri <- soc[!is.na(IdRegion) & !is.na(valor) & valor > 0,
          .(actividades = sum(valor)), by = .(IdRegion, etiqueta)]
# % que representa cada tipología dentro de la actividad social de la región.
ri[, pct_region := round(100 * actividades / sum(actividades), 1), by = IdRegion]
setorder(ri, IdRegion, -actividades)
fwrite(ri, file.path(dir_prod, "social_region_instancia.csv"), sep = ";", bom = TRUE)

cat("Composición de tipologías de participación social por región:\n")
cat("(top tipología de cada región)\n")
print(ri[, .SD[which.max(pct_region)], by = IdRegion][
  , .(IdRegion, etiqueta, pct_region)][order(IdRegion)])
