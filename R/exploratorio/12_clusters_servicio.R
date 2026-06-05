# =============================================================================
# 12_clusters_servicio.R  ·  ¿El residuo espacial es el SERVICIO DE SALUD (la red)?
# -----------------------------------------------------------------------------
# En 11 vimos que, tras controlar por pobreza y composición, AÚN queda
# autocorrelación espacial en reclamos y satisfacción. Hipótesis: ese residuo es
# la gestión de la RED, los ~29 Servicios de Salud, que agrupan establecimientos
# y comunas. Aquí agregamos el Servicio de Salud como factor al modelo comunal y
# vemos si el Moran de los residuos cae a ~0.
#   - Si cae a no significativo -> el "territorio" era en realidad la RED (gestión
#     del servicio): sigue siendo un fenómeno institucional, no geográfico.
#   - Si se mantiene -> hay estructura espacial que ni la red explica.
#
# Paquetes: sf, spdep, chilemapas
# SALIDA  : productos/espacial_servicio.csv
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

# ---- Servicio de Salud por establecimiento (desde la maestra) --------------
maestra <- fread(here("datos", "establecimientos_maestra.csv"), sep = ";",
                 encoding = "UTF-8", colClasses = "character",
                 select = c("EstablecimientoCodigo", "EstablecimientoCodigoAntiguo",
                            "SeremiSaludGlosa_ServicioDeSaludGlosa"))
setnames(maestra, "SeremiSaludGlosa_ServicioDeSaludGlosa", "servicio")
maestra <- maestra[grepl("^Servicio de Salud", servicio)]   # solo red pública
sv <- unique(rbindlist(list(
  maestra[EstablecimientoCodigo != "", .(cod = EstablecimientoCodigo, servicio)],
  maestra[!is.na(EstablecimientoCodigoAntiguo) & EstablecimientoCodigoAntiguo != "",
          .(cod = EstablecimientoCodigoAntiguo, servicio)])), by = "cod")
est[, cod := as.character(IdEstablecimiento)]
est <- merge(est, sv, by = "cod", all.x = TRUE)

# Servicio dominante de cada comuna (el de la mayoría de sus establecimientos).
com_sv <- est[!is.na(servicio), .N, by = .(IdComuna, servicio)][
  order(IdComuna, -N)][, .SD[1], by = IdComuna][, .(IdComuna, servicio)]

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

# ---- Composición + pobreza + servicio (conjunto de análisis) ----------------
comp <- est[!is.na(IdComuna), .(
  n_tot = .N, n_rural = sum(tipo_grp %in% c("Posta Rural (PSR)","SUR")),
  n_hosp = sum(tipo_grp == "Hospital"), n_cesfam = sum(tipo_grp == "CESFAM")),
  by = IdComuna]
comp[, `:=`(pct_rural = 100*n_rural/n_tot, pct_hosp = 100*n_hosp/n_tot,
            pct_cesfam = 100*n_cesfam/n_tot)]

mapa <- st_as_sf(chilemapas::mapa_comunas)
mapa$IdComuna <- as.integer(mapa$codigo_comuna)
base <- Reduce(function(a,b) merge(a,b,by="IdComuna"), list(
  comp[, .(IdComuna, pct_rural, pct_hosp, pct_cesfam)],
  com[,  .(IdComuna, pct_pobreza)], com_sv))
base <- base[complete.cases(base)]
base[, servicio := factor(servicio)]
keep <- intersect(base$IdComuna, mapa$IdComuna)
mapa <- mapa[mapa$IdComuna %in% keep, ]; mapa <- mapa[order(mapa$IdComuna), ]
base <- base[match(mapa$IdComuna, IdComuna)]
nb <- poly2nb(mapa, queen = TRUE); lw <- nb2listw(nb, style = "W", zero.policy = TRUE)

# ---- Por tema: modelo con servicio vs. Moran de residuos -------------------
out <- vector("list", 3)
for (k in seq_along(temas_corto)) {
  tm <- temas_corto[k]
  cv <- cobtema[tema == tm][match(mapa$IdComuna, IdComuna), cobertura]
  cv[is.na(cv)] <- 0
  d <- copy(base); d[, cobertura := cv]
  fit <- lm(cobertura ~ pct_pobreza + pct_rural + pct_hosp + pct_cesfam + servicio,
            data = d)
  mi <- moran.test(residuals(fit), lw, zero.policy = TRUE)
  out[[k]] <- data.table(
    tema = tm, R2 = round(summary(fit)$r.squared, 3),
    moran_residual_con_servicio = round(mi$estimate[["Moran I statistic"]], 3),
    p_moran_residual = round(mi$p.value, 4),
    veredicto = ifelse(mi$p.value >= 0.05,
                       "La red (servicio) explica el clúster",
                       "Queda estructura espacial aún con servicio"))
}
res_dt <- rbindlist(out)
fwrite(res_dt, file.path(dir_prod, "espacial_servicio.csv"), sep = ";", bom = TRUE)

cat("\n¿El Servicio de Salud (la red) explica el residuo espacial?\n")
print(res_dt)
