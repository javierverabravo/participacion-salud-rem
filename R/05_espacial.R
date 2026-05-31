# =============================================================================
# 05_espacial.R  ·  Autocorrelación espacial de la participación (Moran / LISA)
# -----------------------------------------------------------------------------
# PREGUNTA 2: ¿la cobertura de participación forma CLUSTERS territoriales, o se
# distribuye al azar en el espacio? Lo medimos a nivel COMUNAL con:
#   - I de Moran global : ¿hay autocorrelación espacial en general?
#   - LISA (Moran local): ¿dónde están los clusters (alto-alto, bajo-bajo)?
#
# Conceptos:
#   - "Vecindad": dos comunas son vecinas si comparten frontera.
#   - I de Moran > 0 y significativo => comunas parecidas tienden a estar juntas
#     (clusters); cercano a 0 => distribución espacial aleatoria.
#
# Paquetes nuevos: spdep, sf, chilemapas  ->  install.packages(c("spdep","sf"))
# SALIDA: productos/moran_global.csv, productos/lisa_comuna.csv
# =============================================================================
library(here)
library(data.table)
library(sf)
library(spdep)
library(chilemapas)
dir_prod <- here("productos")

# ---- 1. Cobertura por comuna + geometría -----------------------------------
cob <- fread(here("productos", "cobertura_vs_pobreza.csv"), sep = ";")
cob[, codigo_comuna := sprintf("%05d", IdComuna)]

mapa <- st_as_sf(chilemapas::mapa_comunas)
mapa <- merge(mapa, cob[, .(codigo_comuna, cobertura)],
              by = "codigo_comuna", all.x = TRUE)
# Nos quedamos solo con comunas que tienen dato (las del REM).
mapa <- mapa[!is.na(mapa$cobertura), ]

# ---- 2. Matriz de vecindad (comunas que comparten frontera) ----------------
# zero.policy = TRUE permite comunas sin vecinos (islas, p. ej. Juan Fernández).
nb <- poly2nb(mapa, queen = TRUE)
lw <- nb2listw(nb, style = "W", zero.policy = TRUE)

# ---- 3. I de Moran global --------------------------------------------------
mi <- moran.test(mapa$cobertura, lw, zero.policy = TRUE, na.action = na.omit)
moran_dt <- data.table(
  indicador = c("I_Moran", "valor_esperado", "p_valor"),
  valor = round(c(mi$estimate[["Moran I statistic"]],
                  mi$estimate[["Expectation"]], mi$p.value), 4))
fwrite(moran_dt, file.path(dir_prod, "moran_global.csv"), sep = ";", bom = TRUE)

# ---- 4. LISA (Moran local): clasificación en clusters ----------------------
lm <- localmoran(mapa$cobertura, lw, zero.policy = TRUE)
z   <- scale(mapa$cobertura)[, 1]          # variable estandarizada
lagz<- lag.listw(lw, z, zero.policy = TRUE) # promedio de los vecinos
p   <- lm[, "Pr(z != E(Ii))"]
cluster <- fifelse(p >= 0.05, "No significativo",
            fifelse(z > 0 & lagz > 0, "Alto-Alto (foco de participación)",
            fifelse(z < 0 & lagz < 0, "Bajo-Bajo (foco de subregistro)",
            fifelse(z > 0 & lagz < 0, "Alto-Bajo (atípico)",
                    "Bajo-Alto (atípico)"))))
lisa <- data.table(
  codigo_comuna = mapa$codigo_comuna,
  cobertura = mapa$cobertura,
  lisa_cluster = cluster)
fwrite(lisa, file.path(dir_prod, "lisa_comuna.csv"), sep = ";", bom = TRUE)

# ---- Resumen ---------------------------------------------------------------
cat("I de Moran global:\n"); print(moran_dt)
cat("\nDistribución de clusters LISA:\n")
print(lisa[, .N, by = lisa_cluster][order(-N)])
