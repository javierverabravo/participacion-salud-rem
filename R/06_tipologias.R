# =============================================================================
# 06_tipologias.R  ·  Tipologías (perfiles) de participación  [pregunta 6]
# -----------------------------------------------------------------------------
# ¿Existen "estilos" de participación entre establecimientos? Agrupamos los
# establecimientos según la COMPOSICIÓN de su actividad entre los tres temas
# (OIRS/reclamos, participación social, satisfacción) usando k-means. El
# resultado son perfiles latentes —no etiquetados en los datos— que describen
# distintas formas de relacionarse con la comunidad.
#
# SALIDA: productos/tipologias_perfil.csv (descripción de cada perfil)
#         productos/tipologias_asignacion.csv (establecimiento -> perfil)
# =============================================================================
library(here)
library(data.table)
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))

part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)
est  <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)

# ---- 1. Composición de actividad por establecimiento -----------------------
# Total por establecimiento y tema, luego share (proporción) de cada tema.
comp <- part[, .(v = sum(valor_total, na.rm = TRUE)), by = .(IdEstablecimiento, tema)]
comp <- dcast(comp, IdEstablecimiento ~ tema, value.var = "v", fill = 0)
setnames(comp, c("OIRS / Reclamos y solicitudes", "Participación social",
                 "Satisfacción usuaria y humanización"),
         c("oirs", "social", "satisf"), skip_absent = TRUE)
comp[, total := oirs + social + satisf]
comp <- comp[total > 0]                       # solo los que participan
comp[, `:=`(sh_oirs = oirs/total, sh_social = social/total, sh_satisf = satisf/total)]

# ---- 2. k-means sobre las proporciones -------------------------------------
set.seed(123)
X <- scale(comp[, .(sh_oirs, sh_social, sh_satisf)])
km <- kmeans(X, centers = 4, nstart = 25)
comp[, perfil := km$cluster]

# ---- 3. Describir cada perfil ----------------------------------------------
perfil <- comp[, .(
  n_establecimientos = .N,
  pct_oirs   = round(100*mean(sh_oirs), 1),
  pct_social = round(100*mean(sh_social), 1),
  pct_satisf = round(100*mean(sh_satisf), 1)
), by = perfil][order(perfil)]

# Etiqueta automática según el tema dominante de cada perfil.
perfil[, etiqueta := fcase(
  pct_oirs   >= pmax(pct_social, pct_satisf), "Centrado en reclamos (OIRS)",
  pct_social >= pmax(pct_oirs, pct_satisf),   "Fuerte en participación social",
  pct_satisf >= pmax(pct_oirs, pct_social),   "Orientado a satisfacción usuaria",
  default = "Mixto")]
fwrite(perfil, file.path(dir_prod <- here("productos"), "tipologias_perfil.csv"),
       sep = ";", bom = TRUE)

# Asignación establecimiento -> perfil (con tipo y región para describir).
asign <- merge(comp[, .(IdEstablecimiento, perfil)],
               est[, .(IdEstablecimiento, TipoEstablecimientoGlosa)],
               by = "IdEstablecimiento", all.x = TRUE)
fwrite(asign, file.path(dir_prod, "tipologias_asignacion.csv"), sep = ";", bom = TRUE)

# ---- Resumen ---------------------------------------------------------------
cat("Perfiles de participación (k-means, k=4):\n")
print(perfil)
cat("\nTipo de establecimiento más común en cada perfil:\n")
print(asign[, .N, by = .(perfil, TipoEstablecimientoGlosa)][
  order(perfil, -N)][, .SD[1], by = perfil])
