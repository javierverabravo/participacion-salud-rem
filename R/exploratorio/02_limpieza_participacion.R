# =============================================================================
# 02_limpieza_participacion.R
# -----------------------------------------------------------------------------
# OBJETIVO
#   A partir de la Serie A descargada (datos/<AÑO>/Datos/SerieA<AÑO>.csv) y del
#   crosswalk de participación (93 códigos de A19b), construir un DATASET
#   ANALÍTICO ordenado: una fila por establecimiento × mes × prestación de
#   participación, con su descripción, tema y el valor registrado.
#
# DECISIONES DE DISEÑO (ver explicación en el chat):
#   - 'Col01' es el total de cada prestación -> se renombra 'valor_total'.
#   - NO se convierten los NA en ceros: NA ("no reportó / no aplica") es
#     información distinta de 0 ("reportó cero"). Clave para estudiar subregistro.
#   - CodigoPrestacion se lee como TEXTO para calzar con el crosswalk.
#
# ENTRADA : datos/<AÑO>/Datos/SerieA<AÑO>.csv  +  crosswalk/crosswalk_participacion_A19b.csv
# SALIDA  : datos/<AÑO>/participacion_A19b.rds  (dataset analítico, ignorado por Git)
# =============================================================================

# ---- 0. Paquetes -----------------------------------------------------------
library(here)
library(data.table)

# ---- 1. Parámetros y rutas -------------------------------------------------
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))

# Buscamos el CSV de la Serie A de forma robusta (no asumimos la subcarpeta).
ruta_serieA <- list.files(
  here("datos", as.character(anio)),
  pattern = sprintf("SerieA%d\\.csv$", anio),
  full.names = TRUE, recursive = TRUE
)
if (length(ruta_serieA) == 0) {
  stop(sprintf("No encuentro SerieA%d.csv en datos/%d/. ¿Corriste 00_descarga_datos.R?",
               anio, anio))
}
ruta_serieA <- ruta_serieA[1]

ruta_crosswalk <- here("crosswalk", "crosswalk_participacion_A19b.csv")

# ---- 2. Cargar el crosswalk ------------------------------------------------
crosswalk <- fread(ruta_crosswalk, sep = ";", encoding = "UTF-8",
                   colClasses = list(character = "codigo"))
codigos_participacion <- crosswalk$codigo
message(sprintf("Crosswalk cargado: %d códigos de participación.",
                length(codigos_participacion)))

# ---- 3. Leer la Serie A ----------------------------------------------------
# fread es muy rápido y maneja bien archivos grandes.
#   - sep = ";"        : separador del DEIS.
#   - encoding="UTF-8" : codificación REAL de estos archivos (no Latin-1).
#   - colClasses       : forzamos CodigoPrestacion a texto.
# Leemos solo las columnas que necesitamos para ahorrar memoria: los 7
# identificadores + las 50 columnas de valor.
message("Leyendo Serie A (puede tardar; archivo grande)...")
serieA <- fread(
  ruta_serieA,
  sep      = ";",
  encoding = "UTF-8",
  colClasses = list(character = "CodigoPrestacion")
)
message(sprintf("Serie A leída: %s filas, %d columnas.",
                format(nrow(serieA), big.mark = "."), ncol(serieA)))

# ---- 4. Filtrar solo las filas de participación ----------------------------
participacion <- serieA[CodigoPrestacion %chin% codigos_participacion]
message(sprintf("Filas de participación: %s (de %s totales).",
                format(nrow(participacion), big.mark = "."),
                format(nrow(serieA), big.mark = ".")))

# Liberamos memoria de la tabla grande, ya no la necesitamos.
rm(serieA); gc()

# ---- 5. Pegar descripción y tema (join con el crosswalk) -------------------
participacion <- merge(
  participacion,
  crosswalk[, .(codigo, descripcion, tema, seccion)],
  by.x = "CodigoPrestacion", by.y = "codigo",
  all.x = TRUE, sort = FALSE
)

# ---- 6. Valor principal y banderas de subregistro --------------------------
# Col01 = total de la prestación. Lo renombramos para que quede claro.
setnames(participacion, "Col01", "valor_total")

# Banderas que NO destruyen la distinción NA / 0 (clave para pregunta 5):
#   - reporto = TRUE  si valor_total NO es NA (el establecimiento sí registró algo).
#   - es_cero = TRUE  si registró explícitamente 0.
participacion[, reporto := !is.na(valor_total)]
participacion[, es_cero := (!is.na(valor_total) & valor_total == 0)]

# Fecha de referencia (primer día del mes) para análisis temporal.
participacion[, fecha := as.Date(sprintf("%d-%02d-01", Ano, Mes))]

# ---- 7. Ordenar columnas clave al frente -----------------------------------
cols_frente <- c("fecha", "Ano", "Mes", "IdRegion", "IdComuna", "IdServicio",
                 "IdEstablecimiento", "CodigoPrestacion", "tema", "seccion",
                 "descripcion", "valor_total", "reporto", "es_cero")
setcolorder(participacion, intersect(cols_frente, names(participacion)))

# ---- 8. Guardar dataset analítico ------------------------------------------
# .rds conserva tipos de datos y NA tal cual (mejor que CSV para uso interno).
ruta_salida <- here("datos", as.character(anio), "participacion_A19b.rds")
saveRDS(participacion, ruta_salida)

# ---- 9. Resumen diagnóstico ------------------------------------------------
cat("\n=== Dataset analítico de participación creado ===\n")
cat(sprintf("Filas: %s | Establecimientos: %d | Comunas: %d | Meses: %d\n",
            format(nrow(participacion), big.mark = "."),
            uniqueN(participacion$IdEstablecimiento),
            uniqueN(participacion$IdComuna),
            uniqueN(participacion$Mes)))

cat("\nPatrón del valor principal (valor_total):\n")
n  <- nrow(participacion)
na <- participacion[is.na(valor_total), .N]
z  <- participacion[es_cero == TRUE, .N]
p  <- n - na - z
cat(sprintf("  NA (no reportó/no aplica): %5.1f%%\n", 100 * na / n))
cat(sprintf("  Ceros explícitos        : %5.1f%%\n", 100 * z  / n))
cat(sprintf("  Valores > 0             : %5.1f%%\n", 100 * p  / n))

cat("\nFilas por tema:\n")
print(participacion[, .N, by = tema][order(-N)])

cat("\nGuardado en:", ruta_salida, "\n")
