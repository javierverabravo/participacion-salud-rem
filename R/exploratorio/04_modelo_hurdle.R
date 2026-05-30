# =============================================================================
# 04_modelo_hurdle.R
# -----------------------------------------------------------------------------
# OBJETIVO (preguntas de investigación 4 y 5)
#   Modelar la participación con un enfoque HURDLE (de barrera), que separa dos
#   decisiones distintas y las explica por REGIÓN y MES:
#     (1) Parte barrera   : ¿registra alguna actividad ese mes?  [el subregistro]
#     (2) Parte intensidad: cuánto registra, DADO que registró    [el volumen]
#
#   IMPORTANTE: ajustamos las dos partes como DOS MODELOS SEPARADOS. Esto no es
#   un atajo: en un modelo hurdle la verosimilitud se factoriza en esas dos
#   partes independientes, así que estimarlas por separado es equivalente y, en
#   este caso, mucho más estable que forzar una Binomial Negativa truncada (los
#   conteos tienen una cola extrema —máx 5.494, mediana 4— que hacía colapsar
#   esa familia). Para la intensidad usamos la escala logarítmica, estándar
#   para datos positivos muy asimétricos.
#
# UNIDAD DE ANÁLISIS : establecimiento × mes.
# DENOMINADOR HONESTO: solo establecimiento-mes en que el establecimiento
#   reportó ALGO al REM (estaba operando). Un 0 = "pudo registrar y no lo hizo".
#
# ENTRADA : datos/<AÑO>/participacion_A19b.rds  +  Serie A (columnas de ID)
# SALIDA  : salidas/ (resúmenes .txt y figuras .png)
# =============================================================================

# ---- 0. Paquetes -----------------------------------------------------------
library(here)
library(data.table)
library(ggplot2)

dir_salidas <- here("salidas")
dir_figuras <- here("salidas", "figuras")
dir.create(dir_figuras, recursive = TRUE, showWarnings = FALSE)

# ---- 1. Parámetros ---------------------------------------------------------
anio          <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
tema_objetivo <- "Participación social"   # <- cámbialo para modelar otro tema

# ---- 2. Cargar datos -------------------------------------------------------
part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds"))
setDT(part)

# Universo de establecimiento-mes ACTIVOS (reportaron algo al REM ese mes).
ruta_serieA <- list.files(here("datos", as.character(anio)),
                          pattern = sprintf("SerieA%d\\.csv$", anio),
                          full.names = TRUE, recursive = TRUE)[1]
univ <- fread(ruta_serieA, sep = ";", encoding = "UTF-8",
              select = c("IdEstablecimiento", "Mes", "IdRegion"))
panel <- unique(univ, by = c("IdEstablecimiento", "Mes"))

# ---- 3. Construir la variable respuesta ------------------------------------
part_tema <- part[tema == tema_objetivo,
                  .(valor = sum(valor_total, na.rm = TRUE)),
                  by = .(IdEstablecimiento, Mes)]
panel <- merge(panel, part_tema,
               by = c("IdEstablecimiento", "Mes"), all.x = TRUE, sort = FALSE)
panel[is.na(valor), valor := 0L]

panel[, IdRegion := factor(IdRegion)]
panel[, Mes      := factor(Mes, levels = 1:12)]
panel[, reporta  := as.integer(valor > 0)]   # 1 si registró, 0 si no

cat(sprintf("Panel: %d establecimiento-mes | %% con participación > 0: %.1f%%\n",
            nrow(panel), 100 * mean(panel$reporta)))

# ===========================================================================
# (1) PARTE BARRERA: regresión logística  ¿registra o no?
# ===========================================================================
# family = binomial -> modela P(reporta = 1). Coeficiente positivo = MÁS
# probabilidad de registrar (ojo: signo opuesto al modelo anterior).
m_barrera <- glm(reporta ~ IdRegion + Mes, family = binomial, data = panel)

capture.output(summary(m_barrera),
               file = file.path(dir_salidas, "modelo_barrera_resumen.txt"))
cat("\n--- (1) PARTE BARRERA (logística): odds ratios ---\n")
or_barrera <- exp(cbind(OR = coef(m_barrera), confint.default(m_barrera)))
print(round(or_barrera, 3))

# ===========================================================================
# (2) PARTE INTENSIDAD: modelo lineal sobre log(valor), solo en positivos
# ===========================================================================
pos <- panel[valor > 0]
pos[, log_valor := log(valor)]
m_intens <- lm(log_valor ~ IdRegion + Mes, data = pos)

capture.output(summary(m_intens),
               file = file.path(dir_salidas, "modelo_intensidad_resumen.txt"))
cat("\n--- (2) PARTE INTENSIDAD (log-lineal): efectos multiplicativos ---\n")
# exp(coef) = factor multiplicativo sobre la mediana del conteo.
ef_intens <- exp(cbind(Factor = coef(m_intens), confint(m_intens)))
print(round(ef_intens, 3))

# ===========================================================================
# (3) PREDICCIONES INTERPRETABLES (región × mes)
# ===========================================================================
grid <- CJ(IdRegion = factor(levels(panel$IdRegion), levels = levels(panel$IdRegion)),
           Mes      = factor(1:12, levels = 1:12))

grid[, p_reporta  := predict(m_barrera, newdata = grid, type = "response")]
# Intensidad esperada en escala original (mediana ≈ exp de la media en log).
grid[, intensidad := exp(predict(m_intens, newdata = grid))]

# (3a) Barrera por región (promedio anual).
prob_region <- grid[, .(p_reporta = mean(p_reporta)), by = IdRegion][order(-p_reporta)]
cat("\nProbabilidad de registrar participación social por región:\n")
print(prob_region)

g1 <- ggplot(prob_region, aes(x = reorder(IdRegion, p_reporta), y = p_reporta)) +
  geom_col(fill = "#238b45") + coord_flip() +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Parte BARRERA: probabilidad de registrar participación social",
       subtitle = "Regresión logística, por región (promedio anual)",
       x = "Región", y = "P(registra > 0)") +
  theme_minimal()
ggsave(file.path(dir_figuras, "D_hurdle_prob_region.png"), g1,
       width = 8, height = 6, dpi = 120)

# (3b) Intensidad por región (mediana esperada de actividades cuando registra).
int_region <- grid[, .(intensidad = mean(intensidad)), by = IdRegion][order(-intensidad)]
cat("\nIntensidad esperada (mediana de actividades cuando registra) por región:\n")
print(int_region)

g3 <- ggplot(int_region, aes(x = reorder(IdRegion, intensidad), y = intensidad)) +
  geom_col(fill = "#d95f0e") + coord_flip() +
  labs(title = "Parte INTENSIDAD: actividades registradas cuando sí participa",
       subtitle = "Modelo log-lineal, mediana esperada por región",
       x = "Región", y = "Actividades (mediana esperada)") +
  theme_minimal()
ggsave(file.path(dir_figuras, "F_hurdle_intensidad_region.png"), g3,
       width = 8, height = 6, dpi = 120)

# (3c) Estacionalidad de la barrera (probabilidad de registrar por mes).
prob_mes <- grid[, .(p_reporta = mean(p_reporta)), by = Mes][order(Mes)]
g2 <- ggplot(prob_mes, aes(x = as.integer(as.character(Mes)), y = p_reporta)) +
  geom_line(color = "#2c7fb8", linewidth = 1) +
  geom_point(color = "#2c7fb8", size = 2) +
  scale_x_continuous(breaks = 1:12) +
  scale_y_continuous(labels = scales::percent) +
  labs(title = "Estacionalidad del registro de participación social",
       subtitle = "Probabilidad de registrar, por mes (promedio sobre regiones)",
       x = "Mes", y = "P(registra > 0)") +
  theme_minimal()
ggsave(file.path(dir_figuras, "E_hurdle_estacionalidad.png"), g2,
       width = 9, height = 5, dpi = 120)

cat("\nFiguras y resúmenes guardados en salidas/.\n")
cat("Diagnóstico rápido del modelo de intensidad (R2 ajustado):",
    round(summary(m_intens)$adj.r.squared, 3), "\n")
