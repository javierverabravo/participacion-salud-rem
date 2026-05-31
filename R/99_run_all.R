# =============================================================================
# 99_run_all.R  ·  Script maestro: ejecuta todo el pipeline en orden
# -----------------------------------------------------------------------------
# Datos (00-02) y análisis (03-06). Corre igual en tu PC y en la nube.
# Uso:  source("R/99_run_all.R")
# =============================================================================
library(here)
message("== 1/7  Descarga REM + establecimientos ==");  source(here("R","00_descarga.R"))
message("== 2/7  Procesamiento ==");                    source(here("R","01_procesamiento.R"))
message("== 3/7  Datos comunales (pobreza) ==");         source(here("R","02_datos_comunales.R"))
message("== 4/7  KPIs y modelo base ==");                source(here("R","03_dashboard_kpis.R"))
message("== 5/7  Modelo multinivel (determinantes) =="); source(here("R","04_modelo_multinivel.R"))
message("== 6/7  Autocorrelación espacial ==");          source(here("R","05_espacial.R"))
message("== 7/7  Tipologías ==");                        source(here("R","06_tipologias.R"))
message("\nPipeline completo. Renderiza el dashboard con: quarto render")
