# =============================================================================
# 13_regularidad_intensidad.R
# -----------------------------------------------------------------------------
# DOS preguntas que abre el subregistro (53,8%):
#
# (A) REGULARIDAD: de los establecimientos que SÍ registran un tema, ¿cuántos lo
#     hacen todos los meses y cuántos solo a veces? (el subregistro no es solo
#     "nunca registra", sino "no registra de forma constante"). Es un conteo
#     directo de meses con registro por establecimiento; no requiere modelo.
#
# (B) INTENSIDAD ESPACIAL: ¿la INTENSIDAD de la participación (actividades por
#     establecimiento), y en particular la de PARTICIPACIÓN SOCIAL, forma clústeres
#     territoriales? Antes medimos cobertura (presencia); aquí medimos cuánto.
#
# ENTRADA : datos/<AÑO>/participacion_A19b.rds  +  establecimientos_lookup.rds
# SALIDA  : productos/regularidad.csv  ·  productos/moran_intensidad.csv
#           productos/lisa_intensidad.csv
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

recode_tema <- function(x) fcase(
  x == "OIRS / Reclamos y solicitudes", "OIRS / Reclamos",
  x == "Participación social", "Participación social",
  x == "Satisfacción usuaria y humanización", "Satisfacción",
  default = x)

# ===========================================================================
# (A) REGULARIDAD del registro: meses con actividad por establecimiento y tema
# ===========================================================================
reg <- part[!is.na(valor_total) & valor_total > 0,
            .(meses = uniqueN(Mes)), by = .(IdEstablecimiento, tema)]
reg[, categoria := fcase(
  meses <= 3, "Esporádico (1-3 meses)",
  meses <= 9, "Intermitente (4-9 meses)",
  default     = "Constante (10-12 meses)")]
reg[, tema := recode_tema(tema)]
regd <- reg[, .(n_estab = .N), by = .(tema, categoria)]
regd[, pct := round(100 * n_estab / sum(n_estab), 1), by = tema]
setorder(regd, tema, categoria)
fwrite(regd, file.path(dir_prod, "regularidad.csv"), sep = ";", bom = TRUE)

cat("Regularidad del registro (entre los que SÍ registran cada tema):\n")
print(dcast(regd, tema ~ categoria, value.var = "pct"))

# ===========================================================================
# (B) INTENSIDAD por comuna y tema + clústeres espaciales
# ===========================================================================
# Intensidad = actividades del tema / nº de establecimientos del universo comunal.
uni <- est[!is.na(IdComuna), .(n_estab = uniqueN(IdEstablecimiento)), by = IdComuna]
intens <- part[!is.na(valor_total),
               .(act = sum(valor_total)), by = .(IdComuna, tema)]
intens <- merge(intens, uni, by = "IdComuna", all.x = TRUE)
intens[, intensidad := act / n_estab]
intens[, tema := recode_tema(tema)]
intens[, codigo_comuna := sprintf("%05d", IdComuna)]

mapa <- st_as_sf(chilemapas::mapa_comunas)
mapa <- mapa[mapa$codigo_comuna %in% unique(intens$codigo_comuna), ]
nb <- poly2nb(mapa, queen = TRUE)
lw <- nb2listw(nb, style = "W", zero.policy = TRUE)

temas <- c("OIRS / Reclamos", "Participación social", "Satisfacción")
moran_list <- list(); lisa_list <- list()
for (tm in temas) {
  d <- intens[tema == tm]
  v <- d[match(mapa$codigo_comuna, d$codigo_comuna), intensidad]
  v[is.na(v)] <- 0
  v <- log1p(v)                          # domar la cola (intensidad muy asimétrica)

  mi <- moran.test(v, lw, zero.policy = TRUE)
  moran_list[[tm]] <- data.table(
    tema = tm,
    I_Moran = round(mi$estimate[["Moran I statistic"]], 4),
    p_valor = round(mi$p.value, 4),
    significativo = ifelse(mi$p.value < 0.05, "Sí", "No"))

  lm   <- localmoran(v, lw, zero.policy = TRUE)
  z    <- scale(v)[, 1]; lagz <- lag.listw(lw, z, zero.policy = TRUE)
  p    <- lm[, "Pr(z != E(Ii))"]
  cl <- fifelse(p >= 0.05, "No significativo",
        fifelse(z > 0 & lagz > 0, "Alto-Alto (foco)",
        fifelse(z < 0 & lagz < 0, "Bajo-Bajo (vacío)",
        fifelse(z > 0 & lagz < 0, "Alto-Bajo (atípico)", "Bajo-Alto (atípico)"))))
  lisa_list[[tm]] <- data.table(codigo_comuna = mapa$codigo_comuna,
                                tema = tm, intensidad = v, lisa_cluster = cl)
}
moran_int <- rbindlist(moran_list)
lisa_int  <- rbindlist(lisa_list)
fwrite(moran_int, file.path(dir_prod, "moran_intensidad.csv"), sep = ";", bom = TRUE)
fwrite(lisa_int,  file.path(dir_prod, "lisa_intensidad.csv"),  sep = ";", bom = TRUE)

cat("\n¿Clústeres por INTENSIDAD (actividades por establecimiento)?\n")
print(moran_int)
cat("\nFocos Alto-Alto de intensidad por tema:\n")
print(lisa_int[lisa_cluster == "Alto-Alto (foco)", .N, by = tema])
