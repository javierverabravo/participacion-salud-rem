# =============================================================================
# 05_modelo_hurdle_mixto.R
# -----------------------------------------------------------------------------
# OBJETIVO
#   Refinar el modelo hurdle del script 04 añadiendo un EFECTO ALEATORIO por
#   establecimiento en ambas partes. Esto:
#     (a) corrige la no-independencia (12 meses del mismo establecimiento), y
#     (b) cuantifica la heterogeneidad ENTRE establecimientos mediante el ICC.
#
#   Recordatorio: el R2 del modelo 04 mostró que región y mes explican solo ~5%
#   del volumen. El efecto aleatorio captura el resto (la "personalidad" de cada
#   establecimiento) y el ICC nos dice exactamente cuánto pesa.
#
# Parte barrera   : regresión logística MIXTA  -> glmer (lme4)
# Parte intensidad: modelo lineal MIXTO         -> lmer  (lme4)
#
# ENTRADA : datos/<AÑO>/participacion_A19b.rds + Serie A (columnas de ID)
# SALIDA  : salidas/ (resúmenes .txt y figura .png)
# =============================================================================

# ---- 0. Paquetes -----------------------------------------------------------
library(here)
library(data.table)
library(ggplot2)
library(lme4)        # glmer, lmer

dir_salidas <- here("salidas")
dir_figuras <- here("salidas", "figuras")
dir.create(dir_figuras, recursive = TRUE, showWarnings = FALSE)

# ---- 1. Reconstruir el panel (igual que en el script 04) -------------------
anio          <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
tema_objetivo <- "Participación social"

part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds"))
setDT(part)

ruta_serieA <- list.files(here("datos", as.character(anio)),
                          pattern = sprintf("SerieA%d\\.csv$", anio),
                          full.names = TRUE, recursive = TRUE)[1]
univ <- fread(ruta_serieA, sep = ";", encoding = "UTF-8",
              select = c("IdEstablecimiento", "Mes", "IdRegion"))
panel <- unique(univ, by = c("IdEstablecimiento", "Mes"))

part_tema <- part[tema == tema_objetivo,
                  .(valor = sum(valor_total, na.rm = TRUE)),
                  by = .(IdEstablecimiento, Mes)]
panel <- merge(panel, part_tema,
               by = c("IdEstablecimiento", "Mes"), all.x = TRUE, sort = FALSE)
panel[is.na(valor), valor := 0L]

panel[, IdRegion          := factor(IdRegion)]
panel[, Mes               := factor(Mes, levels = 1:12)]
panel[, reporta           := as.integer(valor > 0)]
panel[, IdEstablecimiento := factor(IdEstablecimiento)]

# ===========================================================================
# (1) BARRERA MIXTA: logística con intercepto aleatorio por establecimiento
# ===========================================================================
# (1|IdEstablecimiento) = cada establecimiento tiene su propio nivel basal.
# bobyqa = optimizador robusto para ayudar a la convergencia.
message("Ajustando barrera mixta (glmer; puede tardar 1-3 min)...")
m_barrera_mix <- glmer(
  reporta ~ IdRegion + Mes + (1 | IdEstablecimiento),
  family  = binomial,
  data    = panel,
  control = glmerControl(optimizer = "bobyqa",
                         optCtrl = list(maxfun = 2e5))
)
capture.output(summary(m_barrera_mix),
               file = file.path(dir_salidas, "modelo_barrera_mixto_resumen.txt"))

# ICC de la barrera (escala latente): varianza entre establecimientos /
# (varianza entre establecimientos + varianza residual logística = pi^2/3).
var_estab_b <- as.numeric(VarCorr(m_barrera_mix)$IdEstablecimiento)
icc_barrera <- var_estab_b / (var_estab_b + pi^2 / 3)

# ===========================================================================
# (2) INTENSIDAD MIXTA: lineal sobre log(valor), intercepto aleatorio
# ===========================================================================
pos <- panel[valor > 0]
pos[, log_valor := log(valor)]
message("Ajustando intensidad mixta (lmer)...")
m_intens_mix <- lmer(
  log_valor ~ IdRegion + Mes + (1 | IdEstablecimiento),
  data = pos
)
capture.output(summary(m_intens_mix),
               file = file.path(dir_salidas, "modelo_intensidad_mixto_resumen.txt"))

vc <- as.data.frame(VarCorr(m_intens_mix))
var_estab_i <- vc[vc$grp == "IdEstablecimiento", "vcov"]
var_resid_i <- vc[vc$grp == "Residual",          "vcov"]
icc_intens  <- var_estab_i / (var_estab_i + var_resid_i)

# ===========================================================================
# (3) RESULTADOS CLAVE
# ===========================================================================
cat("\n==========================================================\n")
cat("ICC — ¿cuánto de la variación está ENTRE establecimientos?\n")
cat("----------------------------------------------------------\n")
cat(sprintf("ICC barrera   (¿registra o no?): %.1f%%\n", 100 * icc_barrera))
cat(sprintf("ICC intensidad (¿cuánto?)      : %.1f%%\n", 100 * icc_intens))

# Comparar el ajuste de la barrera con y sin efecto aleatorio (AIC).
m_barrera_simple <- glm(reporta ~ IdRegion + Mes, family = binomial, data = panel)
cat(sprintf("\nAIC barrera SIN efecto aleatorio: %.0f\n", AIC(m_barrera_simple)))
cat(sprintf("AIC barrera CON efecto aleatorio: %.0f  (menor = mejor ajuste)\n",
            AIC(m_barrera_mix)))

# Efectos fijos de la barrera mixta como odds ratios (¿sobreviven al RE?).
cat("\nOdds ratios de la barrera mixta (efectos fijos):\n")
or_fix <- exp(fixef(m_barrera_mix))
print(round(or_fix, 3))

# ---- 4. Figura: heterogeneidad entre establecimientos ----------------------
# Interceptos aleatorios de la barrera: cada barra/punto es la "tendencia basal"
# de un establecimiento (en log-odds). Una distribución ancha = mucha
# heterogeneidad no explicada por región/mes.
re_estab <- ranef(m_barrera_mix)$IdEstablecimiento
re_dt <- data.table(efecto = re_estab[[1]])

g <- ggplot(re_dt, aes(x = efecto)) +
  geom_histogram(bins = 50, fill = "#756bb1") +
  geom_vline(xintercept = 0, linetype = "dashed") +
  labs(title = "Heterogeneidad entre establecimientos (parte barrera)",
       subtitle = "Intercepto aleatorio por establecimiento (log-odds de registrar)",
       x = "Desviación del promedio (log-odds)", y = "Nº de establecimientos") +
  theme_minimal()
ggsave(file.path(dir_figuras, "G_heterogeneidad_establecimientos.png"), g,
       width = 9, height = 5, dpi = 120)

cat("\nResúmenes y figura guardados en salidas/.\n")
