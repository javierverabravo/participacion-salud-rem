# =============================================================================
# 04_modelo_multinivel.R  ·  Determinantes socioeconómicos (modelo de 3 niveles)
# -----------------------------------------------------------------------------
# PREGUNTA DE FONDO: controlando por el tipo de establecimiento, ¿la participación
# registrada responde a la NECESIDAD (más pobreza -> más participación) o a la
# CAPACIDAD institucional? Y ¿cuánta de la variación vive en cada nivel
# territorial (región / comuna / establecimiento)?
#
# Modelo: barrera (registra o no) con efectos aleatorios anidados
#   (1 | IdRegion / IdComuna / IdEstablecimiento)
# y covariables fijas: tipo de establecimiento, pobreza comunal y mes.
#
# SALIDA: productos/modelo_multinivel_var.csv (descomposición de varianza),
#         productos/modelo_determinantes.csv (efecto de la pobreza),
#         productos/cobertura_vs_pobreza.csv (para el gráfico comunal).
# =============================================================================
library(here)
library(data.table)
library(lme4)
dir_prod <- here("productos")
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
tema_obj <- "Participación social"

part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)
est  <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)
com  <- readRDS(here("datos", "externos", "comunal.rds")); setDT(com)

# Tipo agrupado (igual que en 02).
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

# ---- Panel establecimiento × mes con comuna, región, tipo y pobreza --------
ruta_serieA <- list.files(here("datos", as.character(anio)),
                          pattern = sprintf("SerieA%d\\.csv$", anio),
                          full.names = TRUE, recursive = TRUE)[1]
univ <- fread(ruta_serieA, sep = ";", encoding = "UTF-8",
              select = c("IdEstablecimiento", "Mes", "IdRegion", "IdComuna"))
panel <- unique(univ, by = c("IdEstablecimiento", "Mes"))
pt <- part[tema == tema_obj, .(valor = sum(valor_total, na.rm=TRUE)),
           by = .(IdEstablecimiento, Mes)]
panel <- merge(panel, pt, by = c("IdEstablecimiento","Mes"), all.x=TRUE, sort=FALSE)
panel[is.na(valor), valor := 0L]
panel <- merge(panel, est[, .(IdEstablecimiento, tipo_grp)],
               by = "IdEstablecimiento", all.x=TRUE, sort=FALSE)
panel <- merge(panel, com[, .(IdComuna, pct_pobreza)],
               by = "IdComuna", all.x=TRUE, sort=FALSE)
panel <- panel[!is.na(pct_pobreza)]                # comunas con dato socioeconómico

panel[, `:=`(reporta = as.integer(valor > 0),
             pobreza10 = pct_pobreza / 10,         # efecto por cada +10 puntos
             Mes = factor(Mes, levels = 1:12),
             tipo_grp = relevel(factor(tipo_grp), ref = "CESFAM"),
             IdRegion = factor(IdRegion), IdComuna = factor(IdComuna),
             IdEstablecimiento = factor(IdEstablecimiento))]

# ---- Modelo de 3 niveles ---------------------------------------------------
message("Ajustando modelo multinivel de 3 niveles (puede tardar varios minutos)...")
m <- glmer(reporta ~ tipo_grp + pobreza10 + Mes +
             (1 | IdRegion/IdComuna/IdEstablecimiento),
           family = binomial, data = panel,
           control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 3e5)))

# ---- Descomposición de la varianza por nivel -------------------------------
vc <- as.data.frame(VarCorr(m))
# Identificamos cada nivel por el nombre del grupo (robusto al orden de lme4).
v_est <- sum(vc$vcov[grepl("IdEstablecimiento", vc$grp)])
v_com <- sum(vc$vcov[grepl("IdComuna", vc$grp) & !grepl("IdEstablecimiento", vc$grp)])
v_reg <- sum(vc$vcov[vc$grp == "IdRegion"])
v_res <- pi^2 / 3
tot <- v_est + v_com + v_reg + v_res
var_dt <- data.table(
  nivel = c("Establecimiento", "Comuna", "Región", "Residual (mes a mes)"),
  pct_varianza = round(100 * c(v_est, v_com, v_reg, v_res) / tot, 1))
fwrite(var_dt, file.path(dir_prod, "modelo_multinivel_var.csv"), sep=";", bom=TRUE)

# ---- Efecto de la pobreza (la pregunta de fondo) ---------------------------
co <- summary(m)$coefficients
or_pob <- exp(co["pobreza10", "Estimate"])
ic_low <- exp(co["pobreza10","Estimate"] - 1.96*co["pobreza10","Std. Error"])
ic_up  <- exp(co["pobreza10","Estimate"] + 1.96*co["pobreza10","Std. Error"])
det_dt <- data.table(
  indicador = c("OR_pobreza_x10pp", "IC95_inferior", "IC95_superior", "p_valor"),
  valor = round(c(or_pob, ic_low, ic_up, co["pobreza10","Pr(>|z|)"]), 4))
fwrite(det_dt, file.path(dir_prod, "modelo_determinantes.csv"), sep=";", bom=TRUE)

# ---- Datos comunales para gráfico: cobertura vs pobreza --------------------
estab_part <- unique(part$IdEstablecimiento)
est[, participa := IdEstablecimiento %in% estab_part]
cob_com <- est[, .(cobertura = round(100*mean(participa),1), n = .N), by = IdComuna]
cob_com <- merge(cob_com, com[, .(IdComuna, comuna, pct_pobreza, poblacion)],
                 by = "IdComuna")
fwrite(cob_com, file.path(dir_prod, "cobertura_vs_pobreza.csv"), sep=";", bom=TRUE)

# ---- Resumen ---------------------------------------------------------------
cat("\nDescomposición de la varianza (parte barrera):\n"); print(var_dt)
cat(sprintf("\nEfecto de la pobreza: OR por +10 pp = %.3f (IC95 %.3f–%.3f, p=%.4f)\n",
            or_pob, ic_low, ic_up, co["pobreza10","Pr(>|z|)"]))
cat("OR > 1 => más pobreza se asocia a MÁS registro; OR < 1 => a MENOS.\n")
