# =============================================================================
# 08_territorial_cruces.R  ·  Lo territorial cruzado con DOS tipologías
# -----------------------------------------------------------------------------
# PREGUNTA: ¿la composición de cada región explica sus diferencias? Cruzamos cada
# región con:
#   (1) el TIPO de establecimiento (¿qué red tiene cada región?)
#   (2) la TIPOLOGÍA DE REGISTRO  (los perfiles k-means: reclamos vs. participación
#       social vs. satisfacción) → ¿qué "estilo" de participación predomina por región?
#
# Esto permite leer el mapa con cuidado: buena parte de las diferencias regionales
# es composición (más postas rurales, más CESFAM…), no un "efecto región" en sí.
#
# ENTRADA : datos/establecimientos_lookup.rds          (IdRegion, tipo)
#           productos/tipologias_asignacion.csv         (perfil por establecimiento)
#           productos/tipologias_perfil.csv             (etiqueta de cada perfil)
# SALIDA  : productos/region_x_tipo.csv  ·  productos/region_x_perfil.csv
# =============================================================================
library(here)
library(data.table)

dir_prod <- here("productos")

# ---- 1. Cargar datos -------------------------------------------------------
est  <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)
asg  <- fread(here("productos", "tipologias_asignacion.csv"), sep = ";", encoding = "UTF-8")
perf <- fread(here("productos", "tipologias_perfil.csv"),     sep = ";", encoding = "UTF-8")

# ---- 2. Tipo de establecimiento agrupado (idéntico a 02/04/07) -------------
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

# ===========================================================================
# (1) REGIÓN x TIPO de establecimiento  (universo completo)
# ===========================================================================
rt <- est[!is.na(IdRegion),
          .(n_estab = uniqueN(IdEstablecimiento)), by = .(IdRegion, tipo_grp)]
rt[, pct_region := round(100 * n_estab / sum(n_estab), 1), by = IdRegion]
setorder(rt, IdRegion, -n_estab)
fwrite(rt, file.path(dir_prod, "region_x_tipo.csv"), sep = ";", bom = TRUE)
cat("region_x_tipo.csv :", nrow(rt), "filas\n")

# ===========================================================================
# (2) REGIÓN x PERFIL de registro  (solo establecimientos que participan)
# ===========================================================================
# Añadir región y etiqueta del perfil a cada establecimiento clasificado.
asg <- merge(asg, est[, .(IdEstablecimiento, IdRegion)],
             by = "IdEstablecimiento", all.x = TRUE)
asg <- merge(asg, perf[, .(perfil, etiqueta)], by = "perfil", all.x = TRUE)

rp <- asg[!is.na(IdRegion),
          .(n_estab = uniqueN(IdEstablecimiento)), by = .(IdRegion, perfil, etiqueta)]
rp[, pct_region := round(100 * n_estab / sum(n_estab), 1), by = IdRegion]
setorder(rp, IdRegion, perfil)
fwrite(rp, file.path(dir_prod, "region_x_perfil.csv"), sep = ";", bom = TRUE)
cat("region_x_perfil.csv :", nrow(rp), "filas\n")

# ---- 3. Control rápido en consola ------------------------------------------
cat("\nComposición de perfiles (conteo nacional por perfil):\n")
print(rp[, .(n = sum(n_estab)), by = .(perfil, etiqueta)][order(perfil)])
