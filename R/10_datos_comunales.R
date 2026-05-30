# =============================================================================
# 10_datos_comunales.R  ·  (INSPECCIÓN) Datos socioeconómicos por comuna
# -----------------------------------------------------------------------------
# Paso previo: descargar la base de pobreza comunal (CASEN, estimación de áreas
# pequeñas) y MOSTRAR su estructura, para escribir el cruce con código de comuna
# sin adivinar nombres de columnas. Una vez vista la estructura, este script se
# completará con la extracción y el join.
# =============================================================================
library(here)
library(readxl)

dir.create(here("datos", "externos"), recursive = TRUE, showWarnings = FALSE)
ruta_pob <- here("datos", "externos", "pobreza_comunal.xlsx")

# Estimación de tasa de pobreza por ingresos por comuna (2020, revisada 2022).
url_pob <- paste0("https://observatorio.ministeriodesarrollosocial.gob.cl/",
  "storage/docs/pobreza-comunal/2020/",
  "Estimaciones_de_Tasa_de_Pobreza_por_Ingresos_por_Comunas_2020_revisada2022_09.xlsx")

options(timeout = max(600, getOption("timeout")))
if (!file.exists(ruta_pob)) {
  message("Descargando pobreza comunal...")
  download.file(url_pob, ruta_pob, mode = "wb")
}

# Mostrar estructura.
cat("Hojas del archivo:\n"); print(excel_sheets(ruta_pob))
cat("\nPrimeras 12 filas de la primera hoja (sin asumir encabezado):\n")
muestra <- read_excel(ruta_pob, sheet = 1, col_names = FALSE, n_max = 12)
print(as.data.frame(muestra))
