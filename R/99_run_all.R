# =============================================================================
# 99_run_all.R  ·  Script maestro: ejecuta todo el pipeline en orden
# -----------------------------------------------------------------------------
# Corre de principio a fin: descarga -> procesamiento -> KPIs y modelo.
# Pensado para correr igual en tu PC y en la nube (GitHub Actions).
# Uso:  source("R/99_run_all.R")
# =============================================================================
library(here)
message("== 1/7  Descarga ==");                  source(here("R","00_descarga.R"))
message("== 2/7  Procesamiento ==");              source(here("R","01_procesamiento.R"))
message("== 3/7  KPIs y modelo base ==");         source(here("R","02_dashboard_kpis.R"))
message("== 4/7  Datos comunales ==");            source(here("R","10_datos_comunales.R"))
message("== 5/7  Modelo multinivel ==");          source(here("R","11_modelo_multinivel.R"))
message("== 6/7  Autocorrelación espacial ==");   source(here("R","12_espacial.R"))
message("== 7/7  Tipologías ==");                 source(here("R","13_tipologias.R"))
message("\nPipeline completo. Ahora renderiza el dashboard con: quarto render")
