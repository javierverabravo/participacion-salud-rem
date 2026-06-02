# =============================================================================
# 11_clusters_covariables.R  ·  ¿Los clústeres son socioeconómicos o composicionales?
# -----------------------------------------------------------------------------
# Hallazgo previo (10): los reclamos (OIRS) y la satisfacción forman clústeres
# territoriales. PREGUNTA: ¿se explican por la POBREZA de la comuna (socioeconómico)
# o por la COMPOSICIÓN de su red de salud (cuántas postas rurales, hospitales,
# CESFAM tiene = institucional/compositional)?
#
# ESTRATEGIA: para cada tema, una regresión de la cobertura comunal sobre
#   pobreza + composición, y luego se mira si AÚN queda autocorrelación espacial
#   en los residuos. Lectura:
#   - Si la pobreza es significativa  -> hay un componente socioeconómico.
#   - Si el Moran de los residuos cae a ~0 -> la composición explica el clúster
#     (es institucional, no territorial-socioeconómico).
#
# NOTA: etnia y migración a nivel COMUNAL no están aún en el proyecto (vendrían
# del CENSO 2017). Este script cubre pobreza + composición; el bloque CENSO queda
# como extensión.
#
# Paquetes: sf, spdep, chilemapas
# SALIDA  : productos/espacial_covariables.csv
# =============================================================================
library(here)
library(data.table)
library(sf)
library(spdep)
library(chilemapas)
dir_prod <- here("productos")

anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)
est  <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)
com  <- readRDS(here("datos", "externos", "comunal.rds")); setDT(com)

# ---- Tipo de establecimiento agrupado --------------------------------------
principales <- c("Posta de Salud Rural (PSR)","Centro de Salud Familiar (CESFAM)",
  "Centro Comunitario de Salud Familiar (CECOSF)",
  "Servicio de Atención Primaria de Urgencia (SAPU)","Hospital",
  "Servicio de Urgencia Rural (SUR)","Centro Comunitario de Salud Mental  (COSAM)",
  "Servicio de Atención Primaria de Urgencia de Alta Resolutividad (SAR)")
corto <- c("Posta Rural (PSR)","CESFAM","CECOSF","SAPU","Hospital","SUR","COSAM","SAR")
names(corto) <- principales
est[, tipo_grp := ifelse(TipoEstablecimientoGlosa %in% principales,
                         corto[TipoEstablecimientoGlosa], "Otro")]
est[is.na(tipo_grp), tipo_grp := "Otro"]

# ---- Cobertura por comuna y tema -------------------------------------------
uni <- est[!is.na(IdComuna), .(n_estab = uniqueN(IdEstablecimiento)), by = IdComuna]
temas_full  <- c("OIRS / Reclamos y solicitudes", "Participación social",
                 "Satisfacción usuaria y humanización")
temas_corto <- c("OIRS / Reclamos", "Participación social", "Satisfacción")
cobs <- vector("list", 3)
for (i in seq_along(temas_full)) {
  num <- part[tema == temas_full[i] & !is.na(valor_total) & valor_total > 0,
              .(n = uniqueN(IdEstablecimiento)), by = IdComuna]
  d <- merge(uni, num, by = "IdComuna", all.x = TRUE); d[is.na(n), n := 0]
  d[, cobertura := 100 * n / n_estab]
  cobs[[i]] <- d[, .(IdComuna, tema = temas_corto[i], cobertura)]
}
cobtema <- rbindlist(cobs)

# ---- Composición de la red por comuna --------------------------------------
comp <- est[!is.na(IdComuna), .(
  n_tot    = .N,
  n_rural  = sum(tipo_grp %in% c("Posta Rural (PSR)", "SUR")),
  n_hosp   = sum(tipo_grp == "Hospital"),
  n_cesfam = sum(tipo_grp == "CESFAM")), by = IdComuna]
comp[, `:=`(pct_rural  = 100 * n_rural  / n_tot,
            pct_hosp   = 100 * n_hosp   / n_tot,
            pct_cesfam = 100 * n_cesfam / n_tot)]

# ---- Conjunto de análisis: comunas con TODO (universo ∩ pobreza ∩ geometría) -
mapa <- st_as_sf(chilemapas::mapa_comunas)
mapa$IdComuna <- as.integer(mapa$codigo_comuna)
base <- merge(comp[, .(IdComuna, pct_rural, pct_hosp, pct_cesfam)],
              com[,  .(IdComuna, pct_pobreza)], by = "IdComuna")
base <- base[complete.cases(base)]
keep <- intersect(base$IdComuna, mapa$IdComuna)
mapa <- mapa[mapa$IdComuna %in% keep, ]
mapa <- mapa[order(mapa$IdComuna), ]
base <- base[match(mapa$IdComuna, IdComuna)]   # mismo orden que la geometría

nb <- poly2nb(mapa, queen = TRUE)
lw <- nb2listw(nb, style = "W", zero.policy = TRUE)

# ---- Regresión + Moran de residuos, tema por tema --------------------------
out <- vector("list", 3)
for (k in seq_along(temas_corto)) {
  tm <- temas_corto[k]
  cv <- cobtema[tema == tm][match(mapa$IdComuna, IdComuna), cobertura]
  cv[is.na(cv)] <- 0
  d  <- copy(base); d[, cobertura := cv]

  fit <- lm(cobertura ~ pct_pobreza + pct_rural + pct_hosp + pct_cesfam, data = d)
  s   <- summary(fit)
  rho <- suppressWarnings(cor(d$cobertura, d$pct_pobreza, method = "spearman"))

  mi_crudo <- moran.test(d$cobertura, lw, zero.policy = TRUE)
  mi_resid <- moran.test(residuals(fit), lw, zero.policy = TRUE)

  out[[k]] <- data.table(
    tema            = tm,
    rho_pobreza     = round(rho, 3),
    beta_pobreza    = round(coef(fit)[["pct_pobreza"]], 3),
    p_pobreza       = round(s$coefficients["pct_pobreza", "Pr(>|t|)"], 4),
    beta_pct_rural  = round(coef(fit)[["pct_rural"]], 3),
    p_pct_rural     = round(s$coefficients["pct_rural", "Pr(>|t|)"], 4),
    R2              = round(s$r.squared, 3),
    moran_crudo     = round(mi_crudo$estimate[["Moran I statistic"]], 3),
    p_moran_crudo   = round(mi_crudo$p.value, 4),
    moran_residual  = round(mi_resid$estimate[["Moran I statistic"]], 3),
    p_moran_resid   = round(mi_resid$p.value, 4))
}
res_dt <- rbindlist(out)
fwrite(res_dt, file.path(dir_prod, "espacial_covariables.csv"), sep = ";", bom = TRUE)

cat("\n¿Pobreza o composición explican los clústeres?\n")
print(res_dt)
cat("\nLectura: p_pobreza < 0,05 => hay componente socioeconómico.\n")
cat("moran_residual ~ 0 (p >= 0,05) => la composición explica el clúster (institucional).\n")
