# =============================================================================
# 07_tipo_actividad.R  ·  ¿QUÉ tipo de actividad ocurre en QUÉ tipo de establecimiento?
# -----------------------------------------------------------------------------
# PREGUNTA: la participación no es homogénea. Este script cruza el TIPO de
# establecimiento (Hospital, CESFAM, Posta rural, SAPU…) con el TIPO de
# actividad de participación, en dos niveles de detalle:
#   (1) por TEMA      : OIRS/Reclamos · Participación social · Satisfacción usuaria
#   (2) por INSTANCIA : el detalle dentro de "Participación social"
#                       (COSOC, Consejo de Desarrollo Local, Cabildos, etc.)
#
# Esto permite leer el dato en diálogo con la NORMA: la Norma General de
# Participación Ciudadana en la Gestión Pública de Salud define mecanismos
# formales (CPP, COSOC, consejos de desarrollo, consejos consultivos, CIRA…);
# aquí vemos cuáles se registran efectivamente y en qué dispositivos de la red.
#
# ENTRADA : datos/<AÑO>/participacion_A19b.rds  +  datos/establecimientos_lookup.rds
# SALIDA  : productos/tipo_x_tema.csv  ·  productos/tipo_x_instancia.csv
# =============================================================================
library(here)
library(data.table)

dir_prod <- here("productos")
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))

# ---- 1. Cargar datos -------------------------------------------------------
part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)
est  <- readRDS(here("datos", "establecimientos_lookup.rds"));               setDT(est)

# ---- 2. Tipo de establecimiento agrupado (idéntico a 02 y 04) --------------
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

# Universo de establecimientos por tipo (denominador para los %).
n_tipo <- est[, .(n_total = uniqueN(IdEstablecimiento)), by = tipo_grp]

# Unir el tipo a cada registro de participación.
part <- merge(part, est[, .(IdEstablecimiento, tipo_grp)],
              by = "IdEstablecimiento", all.x = TRUE)
part[is.na(tipo_grp), tipo_grp := "Otro"]

# ===========================================================================
# (1) CRUCE  tipo_grp  x  tema
# ===========================================================================
# actividades        : suma de actividades registradas (volumen)
# n_estab_participa  : establecimientos del tipo que registran ese tema (>0)
# pct_estab          : % del tipo que registra el tema (cobertura del tema)
tt <- part[!is.na(valor_total) & valor_total > 0,
           .(actividades = sum(valor_total),
             n_estab_participa = uniqueN(IdEstablecimiento)),
           by = .(tipo_grp, tema)]
tt <- merge(tt, n_tipo, by = "tipo_grp", all.x = TRUE)
tt[, pct_estab := round(100 * n_estab_participa / n_total, 1)]

# Cuota del volumen de cada tipo que va a cada tema (composición interna, %).
tt[, pct_volumen_tipo := round(100 * actividades / sum(actividades), 1), by = tipo_grp]

setorder(tt, -actividades)
fwrite(tt, file.path(dir_prod, "tipo_x_tema.csv"), sep = ";", bom = TRUE)
cat("tipo_x_tema.csv :", nrow(tt), "filas (tipo x tema)\n")

# ===========================================================================
# (2) CRUCE  tipo_grp  x  INSTANCIA  (detalle de Participación social)
# ===========================================================================
# La 'instancia' está en la descripción del código (COSOC, CDL, Cabildos…).
soc <- part[tema == "Participación social" & !is.na(valor_total) & valor_total > 0,
            .(actividades = sum(valor_total),
              n_estab = uniqueN(IdEstablecimiento)),
            by = .(tipo_grp, instancia = descripcion)]
setorder(soc, -actividades)
fwrite(soc, file.path(dir_prod, "tipo_x_instancia.csv"), sep = ";", bom = TRUE)
cat("tipo_x_instancia.csv :", nrow(soc), "filas (tipo x instancia social)\n")

# ---- 3. Resumen en consola (control rápido) --------------------------------
cat("\nTop tipo x tema por volumen:\n")
print(head(tt[, .(tipo_grp, tema, actividades, pct_estab, pct_volumen_tipo)], 12))
