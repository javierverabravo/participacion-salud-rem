# =============================================================================
# 06_preparar_dashboard.R
# -----------------------------------------------------------------------------
# OBJETIVO
#   Generar todos los INSUMOS PEQUEÑOS que alimentan el dashboard de Quarto.
#   El dashboard NO reprocesa los CSV de 1 GB: solo lee estas tablas resumidas.
#   Por eso este script es el "puente" entre el análisis pesado y la
#   visualización ligera. Sus salidas (carpeta productos/) SÍ se versionan en Git.
#
#   Produce:
#     - productos/kpis_generales.csv      : tarjetas KPI
#     - productos/cobertura_region.csv    : % cobertura por región (mapa/barras)
#     - productos/cobertura_comuna.csv    : % cobertura por comuna (mapa fino)
#     - productos/serie_mensual.csv       : evolución temporal por tema
#     - productos/temas.csv               : resumen por tema
#     - productos/modelo_region.csv       : efectos del modelo por región
#     - productos/modelo_estacionalidad.csv: efecto del mes (barrera)
#     - productos/modelo_icc.csv          : ICC y AIC (hallazgos del modelo)
#
# ENTRADA : datos/<AÑO>/participacion_A19b.rds + Serie A (columnas de ID)
# =============================================================================

# ---- 0. Paquetes y carpetas ------------------------------------------------
library(here)
library(data.table)
library(lme4)

dir_prod <- here("productos")
dir.create(dir_prod, showWarnings = FALSE)

anio          <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
tema_objetivo <- "Participación social"

# ---- 1. Cargar datos --------------------------------------------------------
part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds"))
setDT(part)

ruta_serieA <- list.files(here("datos", as.character(anio)),
                          pattern = sprintf("SerieA%d\\.csv$", anio),
                          full.names = TRUE, recursive = TRUE)[1]
univ_raw <- fread(ruta_serieA, sep = ";", encoding = "UTF-8",
                  select = c("IdEstablecimiento", "Mes", "IdRegion", "IdComuna"))

# Universo de establecimientos (uno por establecimiento, con su región/comuna).
universo <- unique(univ_raw, by = "IdEstablecimiento")
# Universo de establecimiento-mes activos (reportaron algo al REM ese mes).
univ_mes <- unique(univ_raw, by = c("IdEstablecimiento", "Mes"))

estab_participa <- unique(part$IdEstablecimiento)

# ---- 2. KPIs generales ------------------------------------------------------
# Subregistro a nivel establecimiento-mes: de los activos, cuántos NO registran
# ninguna participación ese mes.
part_em <- unique(part[, .(IdEstablecimiento, Mes)])
univ_mes[, registra_part := paste(IdEstablecimiento, Mes) %in%
            paste(part_em$IdEstablecimiento, part_em$Mes)]

kpis <- data.table(
  indicador = c("establecimientos_activos",
                "establecimientos_participan",
                "pct_cobertura",
                "prestaciones_monitoreadas",
                "total_actividades_participacion",
                "pct_subregistro_estab_mes"),
  valor = c(
    nrow(universo),
    length(estab_participa),
    round(100 * length(estab_participa) / nrow(universo), 1),
    uniqueN(part$CodigoPrestacion),
    sum(part$valor_total, na.rm = TRUE),
    round(100 * mean(!univ_mes$registra_part), 1)
  )
)
fwrite(kpis, file.path(dir_prod, "kpis_generales.csv"), sep = ";", bom = TRUE)

# ---- 3. Cobertura territorial (región y comuna) ----------------------------
universo[, participa := IdEstablecimiento %in% estab_participa]

cob_region <- universo[, .(n_total = .N,
                           n_participa = sum(participa),
                           pct = round(100 * mean(participa), 1)),
                       by = IdRegion][order(IdRegion)]
fwrite(cob_region, file.path(dir_prod, "cobertura_region.csv"), sep = ";", bom = TRUE)

cob_comuna <- universo[, .(n_total = .N,
                           n_participa = sum(participa),
                           pct = round(100 * mean(participa), 1)),
                       by = IdComuna][order(IdComuna)]
fwrite(cob_comuna, file.path(dir_prod, "cobertura_comuna.csv"), sep = ";", bom = TRUE)

# ---- 4. Serie temporal mensual por tema ------------------------------------
serie <- part[, .(actividades       = sum(valor_total, na.rm = TRUE),
                  estab_que_reportan = uniqueN(IdEstablecimiento)),
              by = .(Mes, tema)][order(tema, Mes)]
fwrite(serie, file.path(dir_prod, "serie_mensual.csv"), sep = ";", bom = TRUE)

# ---- 5. Resumen por tema ----------------------------------------------------
temas <- part[, .(filas = .N,
                  actividades = sum(valor_total, na.rm = TRUE),
                  prestaciones = uniqueN(CodigoPrestacion),
                  establecimientos = uniqueN(IdEstablecimiento)),
              by = tema][order(-actividades)]
fwrite(temas, file.path(dir_prod, "temas.csv"), sep = ";", bom = TRUE)

# ===========================================================================
# 6. MODELO HURDLE (reproducimos los resultados clave para el dashboard)
# ===========================================================================
# Panel establecimiento × mes para el tema objetivo.
panel <- copy(univ_mes[, .(IdEstablecimiento, Mes, IdRegion)])
part_tema <- part[tema == tema_objetivo,
                  .(valor = sum(valor_total, na.rm = TRUE)),
                  by = .(IdEstablecimiento, Mes)]
panel <- merge(panel, part_tema, by = c("IdEstablecimiento", "Mes"),
               all.x = TRUE, sort = FALSE)
panel[is.na(valor), valor := 0L]
panel[, IdRegion          := factor(IdRegion)]
panel[, Mes               := factor(Mes, levels = 1:12)]
panel[, reporta           := as.integer(valor > 0)]
panel[, IdEstablecimiento := factor(IdEstablecimiento)]

# Modelos simples (rápidos) para los efectos por región y mes.
m_barrera <- glm(reporta ~ IdRegion + Mes, family = binomial, data = panel)
pos <- panel[valor > 0]; pos[, log_valor := log(valor)]
m_intens  <- lm(log_valor ~ IdRegion + Mes, data = pos)

# Efectos por región (OR de la barrera y factor de intensidad), como predicción.
grid <- CJ(IdRegion = factor(levels(panel$IdRegion), levels = levels(panel$IdRegion)),
           Mes      = factor(1:12, levels = 1:12))
grid[, p_reporta  := predict(m_barrera, newdata = grid, type = "response")]
grid[, intensidad := exp(predict(m_intens, newdata = grid))]
modelo_region <- grid[, .(prob_registra = round(mean(p_reporta), 3),
                          intensidad_mediana = round(mean(intensidad), 1)),
                      by = IdRegion][order(-prob_registra)]
fwrite(modelo_region, file.path(dir_prod, "modelo_region.csv"), sep = ";", bom = TRUE)

modelo_mes <- grid[, .(prob_registra = round(mean(p_reporta), 3)), by = Mes][order(Mes)]
fwrite(modelo_mes, file.path(dir_prod, "modelo_estacionalidad.csv"), sep = ";", bom = TRUE)

# Modelos mixtos (más lentos) para el ICC: el hallazgo institucional.
message("Ajustando modelos mixtos para ICC (puede tardar 2-3 min)...")
m_barrera_mix <- glmer(reporta ~ IdRegion + Mes + (1 | IdEstablecimiento),
                       family = binomial, data = panel,
                       control = glmerControl(optimizer = "bobyqa",
                                              optCtrl = list(maxfun = 2e5)))
m_intens_mix  <- lmer(log_valor ~ IdRegion + Mes + (1 | IdEstablecimiento), data = pos)

var_b <- as.numeric(VarCorr(m_barrera_mix)$IdEstablecimiento)
icc_b <- var_b / (var_b + pi^2 / 3)
vc <- as.data.frame(VarCorr(m_intens_mix))
icc_i <- vc[vc$grp == "IdEstablecimiento", "vcov"] /
  (vc[vc$grp == "IdEstablecimiento", "vcov"] + vc[vc$grp == "Residual", "vcov"])

modelo_icc <- data.table(
  indicador = c("icc_barrera_pct", "icc_intensidad_pct",
                "aic_barrera_simple", "aic_barrera_mixto"),
  valor = c(round(100 * icc_b, 1), round(100 * icc_i, 1),
            round(AIC(m_barrera)), round(AIC(m_barrera_mix)))
)
fwrite(modelo_icc, file.path(dir_prod, "modelo_icc.csv"), sep = ";", bom = TRUE)

cat("\nInsumos del dashboard generados en productos/:\n")
print(list.files(dir_prod))
