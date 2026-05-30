# =============================================================================
# 07_variables_sustantivas.R
# -----------------------------------------------------------------------------
# OBJETIVO
#   Explotar las columnas de desagregación (Col02..Col50) que hasta ahora
#   ignorábamos. Usando el crosswalk de columnas (qué significa cada Col0X en
#   cada sección), pasamos los datos a FORMATO LARGO etiquetado y calculamos
#   las KPIs sustantivas:
#     - Equidad   : participación de pueblos originarios y migrantes por región.
#     - Composición: qué instancias de participación dominan (COSOC, cabildos...).
#     - Género    : registro de personas Trans y No binarie.
#     - Reclamos  : calidad de gestión (respuesta fuera de plazo legal).
#
# ENTRADA : datos/<AÑO>/participacion_A19b.rds + crosswalk/crosswalk_columnas_A19b.csv
# SALIDA  : productos/ (tablas para el dashboard) + datos/<AÑO>/participacion_largo.rds
# =============================================================================

library(here)
library(data.table)

dir_prod <- here("productos")
dir.create(dir_prod, showWarnings = FALSE)
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))

# ---- 1. Cargar datos y crosswalk de columnas -------------------------------
part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds"))
setDT(part)
# Recuperamos Col01 (lo habíamos renombrado a valor_total en el script 02).
part[, Col01 := valor_total]

cw_col <- fread(here("crosswalk", "crosswalk_columnas_A19b.csv"), sep = ";",
                encoding = "UTF-8")

# Clave de sección (A, B.1, B.2, C.1, C.2) a partir del texto largo.
# Tomamos el segundo "token" del texto "SECCIÓN X: ...".
part[, seccion_key := sub("^[^ ]+ ([A-Z](\\.[0-9])?):.*$", "\\1", seccion)]

# ---- 2. Pasar a formato largo ----------------------------------------------
cols_valor <- sprintf("Col%02d", 1:50)
# Forzamos todas las columnas de valor a numérico (algunas venían como lógicas).
part[, (cols_valor) := lapply(.SD, as.numeric), .SDcols = cols_valor]

largo <- melt(
  part,
  id.vars      = c("IdEstablecimiento", "Mes", "IdRegion", "IdComuna",
                   "CodigoPrestacion", "tema", "seccion_key", "descripcion"),
  measure.vars = cols_valor,
  variable.name = "col", value.name = "valor"
)
largo <- largo[!is.na(valor)]                     # las celdas vacías no aportan
largo[, col := as.character(col)]

# Pegamos la etiqueta y la dimensión de cada columna según su sección.
largo <- merge(largo, cw_col, by = c("seccion_key", "col"),
               all.x = TRUE, sort = FALSE)

saveRDS(largo, here("datos", as.character(anio), "participacion_largo.rds"))
cat(sprintf("Tabla larga: %s filas etiquetadas.\n",
            format(nrow(largo), big.mark = ".")))

# ===========================================================================
# (A) EQUIDAD: pueblos originarios y migrantes por región
# ===========================================================================
po_reg  <- largo[dimension == "pueblos_originarios",
                 .(pueblos_originarios = sum(valor)), by = IdRegion]
mig_reg <- largo[dimension == "migrantes",
                 .(migrantes = sum(valor)), by = IdRegion]
per_reg <- largo[etiqueta == "Total Ambos Sexos",
                 .(personas = sum(valor)), by = IdRegion]

equidad <- Reduce(function(a, b) merge(a, b, by = "IdRegion", all = TRUE),
                  list(po_reg, mig_reg, per_reg))
equidad[is.na(equidad)] <- 0
equidad[, pct_pueblos_originarios := round(100 * pueblos_originarios /
                                             pmax(personas, 1), 1)]
equidad[, pct_migrantes := round(100 * migrantes / pmax(personas, 1), 1)]
setorder(equidad, -pct_pueblos_originarios)
fwrite(equidad, file.path(dir_prod, "equidad_region.csv"), sep = ";", bom = TRUE)

# KPIs nacionales de equidad.
equidad_kpis <- data.table(
  indicador = c("total_pueblos_originarios", "total_migrantes",
                "total_personas", "pct_pueblos_originarios", "pct_migrantes"),
  valor = c(
    sum(largo[dimension == "pueblos_originarios", valor]),
    sum(largo[dimension == "migrantes", valor]),
    sum(largo[etiqueta == "Total Ambos Sexos", valor]),
    round(100 * sum(largo[dimension == "pueblos_originarios", valor]) /
            sum(largo[etiqueta == "Total Ambos Sexos", valor]), 1),
    round(100 * sum(largo[dimension == "migrantes", valor]) /
            sum(largo[etiqueta == "Total Ambos Sexos", valor]), 1)
  )
)
fwrite(equidad_kpis, file.path(dir_prod, "equidad_kpis.csv"), sep = ";", bom = TRUE)

# ===========================================================================
# (B) COMPOSICIÓN: instancias de participación (sección B.1)
# ===========================================================================
instancias <- largo[dimension == "instancia" & seccion_key == "B.1",
                    .(actividades = sum(valor)), by = etiqueta][order(-actividades)]
fwrite(instancias, file.path(dir_prod, "instancias.csv"), sep = ";", bom = TRUE)

# ===========================================================================
# (C) IDENTIDAD DE GÉNERO: Trans, No binarie, No revelado (nacional)
# ===========================================================================
genero <- largo[dimension == "identidad_genero",
                .(personas = sum(valor)), by = etiqueta][order(-personas)]
fwrite(genero, file.path(dir_prod, "genero.csv"), sep = ";", bom = TRUE)

# ===========================================================================
# (D) CALIDAD DE GESTIÓN DE RECLAMOS (sección A) por región
# ===========================================================================
gen_reg   <- largo[etiqueta == "Reclamos generados en el mes",
                   .(generados = sum(valor)), by = IdRegion]
fuera_reg <- largo[etiqueta == "Reclamos Respondidos Fuera de Plazos Legales",
                   .(respondidos_fuera = sum(valor)), by = IdRegion]
reclamos <- merge(gen_reg, fuera_reg, by = "IdRegion", all = TRUE)
reclamos[is.na(reclamos)] <- 0
reclamos[, pct_fuera_plazo := round(100 * respondidos_fuera /
                                      pmax(generados, 1), 1)]
setorder(reclamos, -pct_fuera_plazo)
fwrite(reclamos, file.path(dir_prod, "reclamos_region.csv"), sep = ";", bom = TRUE)

# ---- Resumen en consola ----------------------------------------------------
cat("\n=== KPIs sustantivas nacionales ===\n")
print(equidad_kpis)
cat("\nTop instancias de participación:\n"); print(head(instancias, 6))
cat("\nIdentidad de género:\n"); print(genero)
cat("\nReclamos: regiones con mayor % de respuesta fuera de plazo:\n")
print(head(reclamos, 6))
cat("\nTablas guardadas en productos/.\n")
