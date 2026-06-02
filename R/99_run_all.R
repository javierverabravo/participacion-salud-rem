# =============================================================================
# 99_run_all.R  ·  Script maestro: ejecuta TODO el pipeline por bloque en orden
# -----------------------------------------------------------------------------
# Datos (00-03) -> motor (10-11) -> analisis por bloque (20/21/22) -> sintesis (30).
# Idempotente y parametrizable por ano con la variable de entorno REM_ANIO.
#
# Uso (consola de R):  source("R/99_run_all.R")
# Para otro ano:       Sys.setenv(REM_ANIO = "2026"); source("R/99_run_all.R")
# =============================================================================
library(here)
t0 <- Sys.time()

message("== 1/9  Descarga REM + establecimientos ==")
source(here("R", "00_descarga.R"))
message("== 2/9  Procesamiento + crosswalk A19b (bloques A/B/C) ==")
source(here("R", "01_procesamiento.R"))
message("== 3/9  Determinantes comunales (CASEN 2024) ==")
source(here("R", "02_datos_comunales.R"))
message("== 4/9  Denominador FONASA (inscritos validados) ==")
source(here("R", "03_fonasa_inscritos.R"))
message("== 5/9  Motor de analisis (funciones) ==")
source(here("R", "10_engine.R"))
message("== 6/9  Bloque A - Atencion OIRS ==")
source(here("R", "20_analisis_A.R"))
message("== 7/9  Bloque B - Participacion social ==")
source(here("R", "21_analisis_B.R"))
message("== 8/9  Bloque C - Satisfaccion usuaria y humanizacion ==")
source(here("R", "22_analisis_C.R"))
message("== 9/9  Sintesis A/B/C + indicadores de auditoria social ==")
source(here("R", "30_sintesis.R"))

message(sprintf("\nPipeline completo en %.1f min. Productos en productos/{A,B,C,sintesis}/.",
                as.numeric(difftime(Sys.time(), t0, units = "mins"))))
message("Revisa productos/<bloque>/modelo_estado.csv para ver que modelos convergieron.")
message("Luego, en la terminal:  quarto render")
