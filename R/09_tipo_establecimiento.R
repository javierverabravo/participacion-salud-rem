# =============================================================================
# 09_tipo_establecimiento.R
# -----------------------------------------------------------------------------
# OBJETIVO
#   Incorporar el TIPO de establecimiento (de la base maestra) a dos cosas:
#     (1) Descriptivo para el dashboard: cobertura de participación por tipo y
#         por dependencia administrativa.
#     (2) El MODELO: re-ajustar la barrera incluyendo el tipo como variable
#         explicativa, para ver CUÁNTO del 84% de variación "entre
#         establecimientos" se explica simplemente por el tipo de establecimiento.
#         Si el ICC baja, el tipo era parte de la "caja negra" institucional.
#
# ENTRADA : participacion_A19b.rds + establecimientos_lookup.rds + Serie A (IDs)
# SALIDA  : productos/cobertura_tipo.csv, cobertura_dependencia.csv,
#           modelo_tipo.csv, modelo_icc_tipo.csv
# =============================================================================

library(here)
library(data.table)
library(lme4)

dir_prod <- here("productos")
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
tema_objetivo <- "Participación social"

part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)
est  <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)

# ---- 1. Agrupar el tipo: top 8 + "Otro" ------------------------------------
# Hay 30 tipos, muchos con 1-2 casos. Para modelar y graficar, dejamos los
# principales y agrupamos el resto.
principales <- c(
  "Posta de Salud Rural (PSR)", "Centro de Salud Familiar (CESFAM)",
  "Centro Comunitario de Salud Familiar (CECOSF)",
  "Servicio de Atención Primaria de Urgencia (SAPU)", "Hospital",
  "Servicio de Urgencia Rural (SUR)",
  "Centro Comunitario de Salud Mental  (COSAM)",
  "Servicio de Atención Primaria de Urgencia de Alta Resolutividad (SAR)")
# Etiquetas cortas para graficar.
corto <- c("Posta Rural (PSR)", "CESFAM", "CECOSF", "SAPU", "Hospital",
           "SUR", "COSAM", "SAR")
names(corto) <- principales

est[, tipo_grp := ifelse(TipoEstablecimientoGlosa %in% principales,
                         corto[TipoEstablecimientoGlosa], "Otro")]
est[is.na(tipo_grp), tipo_grp := "Otro"]

# ---- 2. Cobertura por tipo y por dependencia -------------------------------
estab_participa <- unique(part$IdEstablecimiento)
est[, participa := IdEstablecimiento %in% estab_participa]

cob_tipo <- est[, .(n_total = .N,
                    n_participa = sum(participa),
                    pct = round(100 * mean(participa), 1)),
                by = tipo_grp][order(-pct)]
fwrite(cob_tipo, file.path(dir_prod, "cobertura_tipo.csv"), sep = ";", bom = TRUE)

cob_dep <- est[!is.na(DependenciaAdministrativa),
               .(n_total = .N, n_participa = sum(participa),
                 pct = round(100 * mean(participa), 1)),
               by = DependenciaAdministrativa][order(-pct)]
fwrite(cob_dep, file.path(dir_prod, "cobertura_dependencia.csv"), sep = ";", bom = TRUE)

cat("Cobertura por tipo de establecimiento:\n"); print(cob_tipo)
cat("\nCobertura por dependencia:\n"); print(cob_dep)

# ---- 3. Panel establecimiento × mes con el tipo ----------------------------
ruta_serieA <- list.files(here("datos", as.character(anio)),
                          pattern = sprintf("SerieA%d\\.csv$", anio),
                          full.names = TRUE, recursive = TRUE)[1]
univ <- fread(ruta_serieA, sep = ";", encoding = "UTF-8",
              select = c("IdEstablecimiento", "Mes"))
panel <- unique(univ, by = c("IdEstablecimiento", "Mes"))

part_tema <- part[tema == tema_objetivo,
                  .(valor = sum(valor_total, na.rm = TRUE)),
                  by = .(IdEstablecimiento, Mes)]
panel <- merge(panel, part_tema, by = c("IdEstablecimiento", "Mes"),
               all.x = TRUE, sort = FALSE)
panel[is.na(valor), valor := 0L]
panel <- merge(panel, est[, .(IdEstablecimiento, tipo_grp)],
               by = "IdEstablecimiento", all.x = TRUE, sort = FALSE)

panel[, reporta := as.integer(valor > 0)]
panel[, Mes := factor(Mes, levels = 1:12)]
# Ponemos CESFAM como categoría de referencia (la más "estándar" de APS).
panel[, tipo_grp := relevel(factor(tipo_grp), ref = "CESFAM")]
panel[, IdEstablecimiento := factor(IdEstablecimiento)]

# ---- 4. Modelo barrera CON tipo de establecimiento -------------------------
message("Ajustando barrera con tipo de establecimiento (2-3 min)...")
m_tipo <- glmer(reporta ~ tipo_grp + Mes + (1 | IdEstablecimiento),
                family = binomial, data = panel,
                control = glmerControl(optimizer = "bobyqa",
                                       optCtrl = list(maxfun = 2e5)))

# ICC después de incluir el tipo (comparar con el 84% del modelo sin tipo).
var_estab <- as.numeric(VarCorr(m_tipo)$IdEstablecimiento)
icc_tipo  <- var_estab / (var_estab + pi^2 / 3)

# Odds ratios del tipo (vs CESFAM): ¿qué tipos registran más o menos?
or_tipo <- exp(fixef(m_tipo))
or_tipo <- or_tipo[grep("tipo_grp", names(or_tipo))]
modelo_tipo <- data.table(
  tipo = sub("tipo_grp", "", names(or_tipo)),
  odds_ratio = round(as.numeric(or_tipo), 3))
setorder(modelo_tipo, -odds_ratio)
fwrite(modelo_tipo, file.path(dir_prod, "modelo_tipo.csv"), sep = ";", bom = TRUE)

icc_dt <- data.table(
  indicador = c("icc_sin_tipo", "icc_con_tipo"),
  valor = c(84.4, round(100 * icc_tipo, 1)))
fwrite(icc_dt, file.path(dir_prod, "modelo_icc_tipo.csv"), sep = ";", bom = TRUE)

cat(sprintf("\nICC sin tipo: 84.4%%  ->  ICC con tipo: %.1f%%\n", 100 * icc_tipo))
cat("\nOdds ratios por tipo (referencia = CESFAM):\n")
print(modelo_tipo)
cat("\nListo. Tablas en productos/.\n")
