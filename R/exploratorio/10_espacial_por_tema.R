# =============================================================================
# 10_espacial_por_tema.R  ·  ¿Hay clústeres territoriales POR TIPO DE ACTIVIDAD?
# -----------------------------------------------------------------------------
# El análisis espacial general (05) midió la participación GLOBAL y dio no
# significativo (sin clústeres). Pero cada tema puede comportarse distinto: la
# participación social podría concentrarse en el sur y los reclamos en el centro.
# Aquí calculamos el I de Moran y los LISA POR SEPARADO para cada tema, sobre la
# COBERTURA COMUNAL de ese tema (% de establecimientos de la comuna que lo registra).
#
# Interpretación: I de Moran > 0 y p < 0,05 => sí hay clústeres territoriales para
# ese tipo de actividad; p >= 0,05 => se distribuye en el espacio sin patrón.
#
# Paquetes: sf, spdep, chilemapas  ->  install.packages(c("sf","spdep","chilemapas"))
# SALIDA  : productos/moran_por_tema.csv  ·  productos/lisa_por_tema.csv
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

# ---- 1. Cobertura por comuna y tema ----------------------------------------
# Denominador: establecimientos activos de la comuna (los del universo REM).
uni <- est[!is.na(IdComuna), .(n_estab = uniqueN(IdEstablecimiento)), by = IdComuna]

temas_full  <- c("OIRS / Reclamos y solicitudes", "Participación social",
                 "Satisfacción usuaria y humanización")
temas_corto <- c("OIRS / Reclamos", "Participación social", "Satisfacción")

cobs <- vector("list", length(temas_full))
for (i in seq_along(temas_full)) {
  num <- part[tema == temas_full[i] & !is.na(valor_total) & valor_total > 0,
              .(n = uniqueN(IdEstablecimiento)), by = IdComuna]
  d <- merge(uni, num, by = "IdComuna", all.x = TRUE)
  d[is.na(n), n := 0]
  d[, cobertura := 100 * n / n_estab]   # 0 = comuna activa pero sin ese tema
  cobs[[i]] <- d[, .(IdComuna, tema = temas_corto[i], cobertura)]
}
cobtema <- rbindlist(cobs)
cobtema[, codigo_comuna := sprintf("%05d", IdComuna)]

# ---- 2. Geometría y vecindad (una sola vez) --------------------------------
mapa <- st_as_sf(chilemapas::mapa_comunas)
mapa <- mapa[mapa$codigo_comuna %in% unique(cobtema$codigo_comuna), ]
nb <- poly2nb(mapa, queen = TRUE)
lw <- nb2listw(nb, style = "W", zero.policy = TRUE)

# ---- 3. Moran global + LISA, tema por tema ---------------------------------
moran_list <- list(); lisa_list <- list()
for (tm in temas_corto) {
  d <- cobtema[tema == tm]
  v <- d[match(mapa$codigo_comuna, d$codigo_comuna), cobertura]
  v[is.na(v)] <- 0

  mi <- moran.test(v, lw, zero.policy = TRUE)
  moran_list[[tm]] <- data.table(
    tema = tm,
    I_Moran        = round(mi$estimate[["Moran I statistic"]], 4),
    valor_esperado = round(mi$estimate[["Expectation"]], 4),
    p_valor        = round(mi$p.value, 4),
    significativo  = ifelse(mi$p.value < 0.05, "Sí", "No"))

  lm   <- localmoran(v, lw, zero.policy = TRUE)
  z    <- scale(v)[, 1]
  lagz <- lag.listw(lw, z, zero.policy = TRUE)
  p    <- lm[, "Pr(z != E(Ii))"]
  cluster <- fifelse(p >= 0.05, "No significativo",
              fifelse(z > 0 & lagz > 0, "Alto-Alto (foco)",
              fifelse(z < 0 & lagz < 0, "Bajo-Bajo (vacío)",
              fifelse(z > 0 & lagz < 0, "Alto-Bajo (atípico)",
                      "Bajo-Alto (atípico)"))))
  lisa_list[[tm]] <- data.table(codigo_comuna = mapa$codigo_comuna,
                                tema = tm, cobertura = v, lisa_cluster = cluster)
}
moran_tema <- rbindlist(moran_list)
lisa_tema  <- rbindlist(lisa_list)
fwrite(moran_tema, file.path(dir_prod, "moran_por_tema.csv"), sep = ";", bom = TRUE)
fwrite(lisa_tema,  file.path(dir_prod, "lisa_por_tema.csv"),  sep = ";", bom = TRUE)

# ---- Resumen en consola (la respuesta a la pregunta) -----------------------
cat("\n¿Hay clústeres territoriales por tipo de actividad?\n")
print(moran_tema)
cat("\nFocos LISA por tema (Alto-Alto = concentración significativa):\n")
print(lisa_tema[lisa_cluster != "No significativo", .N, by = .(tema, lisa_cluster)][order(tema, -N)])
