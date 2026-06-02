# =============================================================================
# 14_participacion_social.R  ·  Caracterización de la PARTICIPACIÓN SOCIAL
# -----------------------------------------------------------------------------
# La participación social (sección B del REM-A19b) es el núcleo deliberativo que
# la Norma General prioriza: consejos, cabildos, instancias indígenas, etc.
# Esta página la desglosa por TIPOLOGÍA (instancia) y la caracteriza a nivel
# nacional en COBERTURA (cuántos establecimientos la hacen) e INTENSIDAD
# (actividades por establecimiento), más el cruce con inclusión.
#
# OJO: en el REM, las columnas de "instancia" y las de "quién participó" (sexo,
# pueblos originarios, migrantes) son sub-tablas SEPARADAS de la misma sección:
# no se pueden cruzar instancia × demografía. Se reportan por separado.
#
# ENTRADA : datos/<AÑO>/participacion_largo.rds  +  establecimientos_lookup.rds
# SALIDA  : productos/social_kpis.csv · social_instancias.csv · social_equidad.csv
# =============================================================================
library(here)
library(data.table)
dir_prod <- here("productos")

anio  <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
largo <- readRDS(here("datos", as.character(anio), "participacion_largo.rds")); setDT(largo)
est   <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)

n_estab_total <- est[, uniqueN(IdEstablecimiento)]
# Sección B.1 = "actividades según instancias": la tabla canónica de tipologías.
# (No mezclar con B.2, que cuenta SESIONES con otras etiquetas y duplicaría.)
soc <- largo[seccion_key == "B.1"]

# ---- (1) Tipologías: actividad, cobertura e intensidad por instancia --------
inst <- soc[dimension == "instancia",
            .(actividades = sum(valor, na.rm = TRUE),
              n_estab     = uniqueN(IdEstablecimiento[!is.na(valor) & valor > 0])),
            by = etiqueta]
inst[, intensidad := round(actividades / pmax(n_estab, 1), 1)]
inst[, cobertura  := round(100 * n_estab / n_estab_total, 1)]
setorder(inst, -actividades)
fwrite(inst, file.path(dir_prod, "social_instancias.csv"), sep = ";", bom = TRUE)

# ---- (2) KPIs nacionales de participación social ----------------------------
total_act <- inst[, sum(actividades)]
n_estab_s <- soc[dimension == "instancia" & !is.na(valor) & valor > 0,
                 uniqueN(IdEstablecimiento)]
kpis <- data.table(
  indicador = c("establecimientos_social", "cobertura_social_pct",
                "total_actividades_social", "intensidad_social",
                "n_tipologias"),
  valor = c(n_estab_s,
            round(100 * n_estab_s / n_estab_total, 1),
            total_act,
            round(total_act / pmax(n_estab_s, 1), 1),
            inst[actividades > 0, .N]))
fwrite(kpis, file.path(dir_prod, "social_kpis.csv"), sep = ";", bom = TRUE)

# ---- (3) Inclusión dentro de la participación social ------------------------
tot_pers <- soc[dimension == "total" & grepl("Total Ambos", etiqueta),
                sum(valor, na.rm = TRUE)]
g <- function(dim, et = NULL) {
  d <- soc[dimension == dim]
  if (!is.null(et)) d <- d[etiqueta %in% et]
  sum(d$valor, na.rm = TRUE)
}
po <- g("pueblos_originarios"); mig <- g("migrantes")
hb <- g("sexo", "Hombres"); mj <- g("sexo", "Mujeres")
equ <- data.table(
  indicador = c("pct_pueblos_originarios", "pct_migrantes",
                "pct_hombres", "pct_mujeres"),
  valor = round(100 * c(po, mig, hb, mj) / pmax(tot_pers, 1), 1))
fwrite(equ, file.path(dir_prod, "social_equidad.csv"), sep = ";", bom = TRUE)

# ---- Resumen ---------------------------------------------------------------
cat("KPIs participación social:\n"); print(kpis)
cat("\nTipologías (instancias) por actividad / cobertura / intensidad:\n")
print(inst)
cat("\nInclusión dentro de participación social (%):\n"); print(equ)
