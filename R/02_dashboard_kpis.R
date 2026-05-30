# =============================================================================
# 02_dashboard_kpis.R  ·  Insumos del dashboard (un solo modelo, el mejor)
# -----------------------------------------------------------------------------
# Calcula TODAS las tablas pequeñas que lee el dashboard (carpeta productos/):
# KPIs, cobertura (región/comuna/tipo/dependencia), serie temporal, equidad,
# instancias, género, reclamos, y los resultados de UN único modelo hurdle
# mixto (barrera + intensidad) que incluye región, tipo y mes a la vez.
# =============================================================================
library(here)
library(data.table)
library(lme4)
dir_prod <- here("productos"); dir.create(dir_prod, showWarnings = FALSE)
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
tema_obj <- "Participación social"

part  <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)
largo <- readRDS(here("datos", as.character(anio), "participacion_largo.rds")); setDT(largo)
est   <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)

# Agrupación de tipo (top 8 + Otro).
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
estab_part <- unique(part$IdEstablecimiento)
est[, participa := IdEstablecimiento %in% estab_part]

# ---- KPIs generales --------------------------------------------------------
ruta_serieA <- list.files(here("datos", as.character(anio)),
                          pattern = sprintf("SerieA%d\\.csv$", anio),
                          full.names = TRUE, recursive = TRUE)[1]
univ_raw <- fread(ruta_serieA, sep = ";", encoding = "UTF-8",
                  select = c("IdEstablecimiento", "Mes", "IdRegion"))
univ_mes <- unique(univ_raw, by = c("IdEstablecimiento", "Mes"))
part_em <- unique(part[, .(IdEstablecimiento, Mes)])
univ_mes[, reg_part := paste(IdEstablecimiento, Mes) %in%
            paste(part_em$IdEstablecimiento, part_em$Mes)]
fwrite(data.table(indicador = c("establecimientos_activos","establecimientos_participan",
  "pct_cobertura","prestaciones_monitoreadas","total_actividades_participacion",
  "pct_subregistro_estab_mes"),
  valor = c(nrow(est), length(estab_part), round(100*mean(est$participa),1),
    uniqueN(part$CodigoPrestacion), sum(part$valor_total, na.rm=TRUE),
    round(100*mean(!univ_mes$reg_part),1))),
  file.path(dir_prod, "kpis_generales.csv"), sep = ";", bom = TRUE)

# ---- Cobertura región / comuna / tipo / dependencia ------------------------
fwrite(est[, .(n_total=.N, n_participa=sum(participa), pct=round(100*mean(participa),1)),
           by=IdRegion][order(IdRegion)],
       file.path(dir_prod,"cobertura_region.csv"), sep=";", bom=TRUE)
fwrite(est[, .(n_total=.N, n_participa=sum(participa), pct=round(100*mean(participa),1)),
           by=ComunaGlosa][order(-pct)],
       file.path(dir_prod,"cobertura_comuna.csv"), sep=";", bom=TRUE)
fwrite(est[, .(n_total=.N, n_participa=sum(participa), pct=round(100*mean(participa),1)),
           by=tipo_grp][order(-pct)],
       file.path(dir_prod,"cobertura_tipo.csv"), sep=";", bom=TRUE)
fwrite(est[!is.na(DependenciaAdministrativa),
           .(n_total=.N, n_participa=sum(participa), pct=round(100*mean(participa),1)),
           by=DependenciaAdministrativa][order(-pct)],
       file.path(dir_prod,"cobertura_dependencia.csv"), sep=";", bom=TRUE)

# ---- Serie temporal y temas ------------------------------------------------
fwrite(part[, .(actividades=sum(valor_total,na.rm=TRUE),
                estab_que_reportan=uniqueN(IdEstablecimiento)),
            by=.(Mes,tema)][order(tema,Mes)],
       file.path(dir_prod,"serie_mensual.csv"), sep=";", bom=TRUE)
fwrite(part[, .(filas=.N, actividades=sum(valor_total,na.rm=TRUE),
                prestaciones=uniqueN(CodigoPrestacion),
                establecimientos=uniqueN(IdEstablecimiento)),
            by=tema][order(-actividades)],
       file.path(dir_prod,"temas.csv"), sep=";", bom=TRUE)

# ---- Equidad, instancias, género, reclamos (desde tabla larga) -------------
po  <- largo[dimension=="pueblos_originarios", .(pueblos_originarios=sum(valor)), by=IdRegion]
mig <- largo[dimension=="migrantes", .(migrantes=sum(valor)), by=IdRegion]
per <- largo[etiqueta=="Total Ambos Sexos", .(personas=sum(valor)), by=IdRegion]
eq <- Reduce(function(a,b) merge(a,b,by="IdRegion",all=TRUE), list(po,mig,per))
eq[is.na(eq)] <- 0
eq[, pct_pueblos_originarios := round(100*pueblos_originarios/pmax(personas,1),1)]
eq[, pct_migrantes := round(100*migrantes/pmax(personas,1),1)]
fwrite(eq[order(-pct_pueblos_originarios)], file.path(dir_prod,"equidad_region.csv"),
       sep=";", bom=TRUE)
tot_per <- sum(largo[etiqueta=="Total Ambos Sexos", valor])
fwrite(data.table(indicador=c("total_pueblos_originarios","total_migrantes",
  "total_personas","pct_pueblos_originarios","pct_migrantes"),
  valor=c(sum(largo[dimension=="pueblos_originarios",valor]),
    sum(largo[dimension=="migrantes",valor]), tot_per,
    round(100*sum(largo[dimension=="pueblos_originarios",valor])/tot_per,1),
    round(100*sum(largo[dimension=="migrantes",valor])/tot_per,1))),
  file.path(dir_prod,"equidad_kpis.csv"), sep=";", bom=TRUE)
fwrite(largo[dimension=="instancia" & seccion_key=="B.1",
             .(actividades=sum(valor)), by=etiqueta][order(-actividades)],
       file.path(dir_prod,"instancias.csv"), sep=";", bom=TRUE)
fwrite(largo[dimension=="identidad_genero", .(personas=sum(valor)),
             by=etiqueta][order(-personas)],
       file.path(dir_prod,"genero.csv"), sep=";", bom=TRUE)
gen_r <- largo[etiqueta=="Reclamos generados en el mes", .(generados=sum(valor)), by=IdRegion]
fue_r <- largo[etiqueta=="Reclamos Respondidos Fuera de Plazos Legales",
               .(respondidos_fuera=sum(valor)), by=IdRegion]
rec <- merge(gen_r, fue_r, by="IdRegion", all=TRUE); rec[is.na(rec)] <- 0
rec[, pct_fuera_plazo := round(100*respondidos_fuera/pmax(generados,1),1)]
fwrite(rec[order(-pct_fuera_plazo)], file.path(dir_prod,"reclamos_region.csv"),
       sep=";", bom=TRUE)

# ===========================================================================
# MODELO ÚNICO (el mejor): hurdle mixto con región + tipo + mes
# ===========================================================================
panel <- unique(univ_raw, by=c("IdEstablecimiento","Mes"))
pt <- part[tema==tema_obj, .(valor=sum(valor_total,na.rm=TRUE)),
           by=.(IdEstablecimiento,Mes)]
panel <- merge(panel, pt, by=c("IdEstablecimiento","Mes"), all.x=TRUE, sort=FALSE)
panel[is.na(valor), valor := 0L]
panel <- merge(panel, est[, .(IdEstablecimiento, tipo_grp)],
               by="IdEstablecimiento", all.x=TRUE, sort=FALSE)
panel[, `:=`(reporta = as.integer(valor>0),
             IdRegion = factor(IdRegion), Mes = factor(Mes, levels=1:12),
             tipo_grp = relevel(factor(tipo_grp), ref="CESFAM"),
             IdEstablecimiento = factor(IdEstablecimiento))]

message("Ajustando modelo barrera (glmer)...")
m_b <- glmer(reporta ~ IdRegion + tipo_grp + Mes + (1|IdEstablecimiento),
             family=binomial, data=panel,
             control=glmerControl(optimizer="bobyqa", optCtrl=list(maxfun=2e5)))
message("Ajustando modelo intensidad (lmer)...")
pos <- panel[valor>0]; pos[, log_valor := log(valor)]
m_i <- lmer(log_valor ~ IdRegion + tipo_grp + Mes + (1|IdEstablecimiento), data=pos)

# ICC de ambas partes.
vb  <- as.numeric(VarCorr(m_b)$IdEstablecimiento); icc_b <- vb/(vb+pi^2/3)
vci <- as.data.frame(VarCorr(m_i))
icc_i <- vci[vci$grp=="IdEstablecimiento","vcov"] /
  (vci[vci$grp=="IdEstablecimiento","vcov"] + vci[vci$grp=="Residual","vcov"])
fwrite(data.table(indicador=c("icc_barrera_pct","icc_intensidad_pct"),
  valor=c(round(100*icc_b,1), round(100*icc_i,1))),
  file.path(dir_prod,"modelo_icc.csv"), sep=";", bom=TRUE)

# Predicción del modelo (efectos fijos) promediada por región, tipo y mes.
panel[, p := predict(m_b, newdata=panel, re.form=NA, type="response")]
fwrite(panel[, .(prob_registra=round(mean(p),3)), by=IdRegion][order(-prob_registra)],
       file.path(dir_prod,"modelo_region.csv"), sep=";", bom=TRUE)
fwrite(panel[, .(prob_registra=round(mean(p),3)), by=tipo_grp][order(-prob_registra)],
       file.path(dir_prod,"modelo_tipo.csv"), sep=";", bom=TRUE)
mmes <- panel[, .(prob_registra=round(mean(p),3)), by=Mes]
mmes[, Mes := as.integer(as.character(Mes))]
fwrite(mmes[order(Mes)], file.path(dir_prod,"modelo_estacionalidad.csv"), sep=";", bom=TRUE)

message("Insumos del dashboard generados en productos/.")
cat(sprintf("ICC barrera %.1f%% | ICC intensidad %.1f%%\n", 100*icc_b, 100*icc_i))
