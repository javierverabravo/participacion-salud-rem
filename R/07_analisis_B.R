# =============================================================================
# 07_analisis_B.R  ·  BLOQUE B — Actividades de Participacion Social
#                      (B.1 instancias + B.2 lineas de accion y participantes)
# -----------------------------------------------------------------------------
# Analisis independiente de la seccion B del REM-A19b (el nucleo deliberativo:
# consejos, cabildos, dialogos, presupuestos participativos, etc.). Aplica el
# flujo completo del motor 04_engine.R. Salidas en productos/B/.
#
# El bloque combina sus dos subsecciones, que miden cosas distintas:
#   B.1 = ACTIVIDADES segun instancia (COSOC, CDL, cabildos, indigena, jovenes)
#   B.2 = SESIONES segun linea de accion (cuentas publicas, presupuestos
#         participativos, dialogos, pueblos originarios, migrantes)
# Se modela el evento "registra participacion social" (B.1+B.2) y se reportan
# las dos subsecciones por separado en subsecciones_bloque().
# =============================================================================
library(here)
library(data.table)
source(here("R", "04_engine.R"))

blq  <- "B"
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
dirb <- dir_bloque(blq)
unlink(file.path(dirb, "modelo_estado.csv"))   # reinicia el registro de esta corrida
message("\n==== BLOQUE B - Participacion Social ====")

part     <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)
largo    <- readRDS(here("datos", as.character(anio), "participacion_largo.rds")); setDT(largo)
universo <- readRDS(here("datos", as.character(anio), "universo_estab_mes.rds")); setDT(universo)
est      <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)
com      <- readRDS(here("datos", "externos", "comunal.rds")); setDT(com)
if (!all(c("bloque", "seccion_key") %in% names(part)))
  stop("Falta 'bloque'/'seccion_key' en participacion_A19b.rds. ",
       "Corre primero R/01_procesamiento.R (o usa R/10_run_all.R).")
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

message("Bloque B listo. Productos en productos/B/")
