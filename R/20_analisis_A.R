# =============================================================================
# 20_analisis_A.R  ·  BLOQUE A — Atención OIRS (Sistema Integral de Atención
#                      a Usuarios): reclamos, consultas, sugerencias, solicitudes
# -----------------------------------------------------------------------------
# Análisis independiente de la sección A del REM-A19b. Aplica el flujo completo
# (KPIs, cobertura territorial, serie temporal, equidad, subsecciones propias,
# hurdle mixto, multinivel, espacial, tipologías) usando el motor 10_engine.R.
# Salidas en productos/A/.
#
# Subsecciones propias de A: motivos de reclamo (familias) y gestión de plazos
# de respuesta (generados, respondidos fuera de plazo, pendientes).
# =============================================================================
library(here)
library(data.table)
source(here("R", "10_engine.R"))

blq  <- "A"
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
dirb <- dir_bloque(blq)
unlink(file.path(dirb, "modelo_estado.csv"))   # reinicia el registro de esta corrida
message("\n==== BLOQUE A - Atencion OIRS ====")

part     <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)
largo    <- readRDS(here("datos", as.character(anio), "participacion_largo.rds")); setDT(largo)
universo <- readRDS(here("datos", as.character(anio), "universo_estab_mes.rds")); setDT(universo)
est      <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)
com      <- readRDS(here("datos", "externos", "comunal.rds")); setDT(com)
if (!all(c("bloque", "seccion_key") %in% names(part)))
  stop("Falta 'bloque'/'seccion_key' en participacion_A19b.rds. ",
       "Corre primero R/01_procesamiento.R (o usa R/99_run_all.R).")
est <- tipo_agrupado(est)

panel <- construir_panel(part, est, universo, blq)

# Descriptivo
kpis_bloque(part, est, panel, largo, blq, dirb)
cobertura_territorial(est, part, blq, dirb)
serie_temporal(part, blq, dirb)
equidad_bloque(largo, blq, dirb)
subsecciones_bloque(largo, 