# =============================================================================
# 99_run_all.R  ·  Script maestro: ejecuta todo el pipeline en orden
# -----------------------------------------------------------------------------
# Corre de principio a fin: descarga -> procesamiento -> KPIs y modelo.
# Pensado para correr igual en tu PC y en la nube (GitHub Actions).
# Uso:  source("R/99_run_all.R")
# =============================================================================
library(here)
message("== 1/3  Descarga ==");        source(here("R", "00_descarga.R"))
message("== 2/3  Procesamiento ==");    source(here("R", "01_procesamiento.R"))
message("== 3/3  KPIs y modelo ==");    source(here("R", "02_dashboard_kpis.R"))
message("\nPipeline completo. Ahora renderiza el dashboard con: quarto render")
