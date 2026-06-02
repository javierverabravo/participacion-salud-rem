# =============================================================================
# 22_analisis_C.R  ·  BLOQUE C — Satisfaccion Usuaria y Humanizacion
#                      (C.1 gestion + C.2 lineas de accion y participantes)
# -----------------------------------------------------------------------------
# Analisis independiente de la seccion C del REM-A19b. Aplica el flujo completo
# del motor 10_engine.R. Salidas en productos/C/.
#
# El bloque combina sus dos subsecciones:
#   C.1 = ACTIVIDADES de gestion de la satisfaccion usuaria y humanizacion
#         (comites de gestion usuaria, medicion SU, acompanamiento espiritual,
#          asistencia religiosa/indigena, Hospital Amigo, TICs)
#   C.2 = SESIONES segun linea de accion (dialogos, diagnostico/planificacion
#          participativa, capacitacion, pueblos originarios, migrantes)
# =============================================================================
library(here)
library(data.table)
source(here("R", "10_engine.R"))

blq  <- "C"
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
dirb <- dir_bloque(blq)
unlink(file.path(dirb, "modelo_estado.csv"))   # reinicia el registro de esta corrida
message("\n==== BLOQUE C - Satisfaccion Usuaria y Humanizacion ====")

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
subsecciones_bloque(largo, part, blq, dirb)

# Modelos (con salvaguardas de convergencia)
modelo_hurdle(panel, blq, dirb)
modelo_multinivel(panel, com, est, part, blq, dirb)
espacial_bloque(blq, dirb)
tipologias_bloque(part, largo, est, blq, dirb)

message("Bloque C listo. Productos en productos/C/")
