# =============================================================================
# 01_crosswalk_participacion.R
# -----------------------------------------------------------------------------
# OBJETIVO
#   Construir el "crosswalk" (tabla puente) que traduce cada CodigoPrestacion
#   de la sección REM-A19b a su descripción y su sección temática.
#   Es la base de todo el análisis: nos dice QUÉ filas del CSV son participación.
#
# CONTEXTO DEL DATO (verificado en el diagnóstico)
#   - El CodigoPrestacion del CSV (8 dígitos) ES el mismo código de 8 dígitos
#     que aparece en la columna A de la hoja "A19b" del diccionario.
#   - La columna B del diccionario tiene la descripción de la prestación.
#   - Filas con "SECCIÓN ..." en la col B marcan a qué subsección pertenece
#     cada código que viene debajo.
#   - Hay un bloque "CÓDIGOS ELIMINADOS" con prestaciones dadas de baja:
#     se excluyen (no tienen descripción válida).
#
# ENTRADA : Diccionarios/DICCIONARIO CODIGOS SA_25_V1.5.xlsm  (hoja "A19b")
# SALIDA  : crosswalk/crosswalk_participacion_A19b.csv
# =============================================================================

# ---- 0. Paquetes -----------------------------------------------------------
# 'here'   : construye rutas relativas a la raíz del proyecto (portable).
# 'readxl' : lee archivos Excel, incluido .xlsm (sin ejecutar sus macros).
# 'data.table' : manipulación rápida de tablas.
# Si no los tienes instalados, corre UNA vez en la consola de R:
#   install.packages(c("here", "readxl", "data.table"))

library(here)
library(readxl)
library(data.table)

# ---- 1. Parámetros ---------------------------------------------------------
# Ruta al diccionario de la Serie A (relativa al proyecto gracias a 'here').
ruta_diccionario <- here("Diccionarios", "DICCIONARIO CODIGOS SA_25_V1.5.xlsm")
hoja             <- "A19b"

# ---- 2. Lectura cruda de la hoja -------------------------------------------
# Leemos SIN nombres de columna (col_names = FALSE) para trabajar por posición:
#   ...1 = columna A (código)   ;   ...2 = columna B (descripción / sección)
# 'col_types = "text"' fuerza todo a texto: así los códigos no se convierten
# a número (perderían ceros a la izquierda y el formato).
crudo <- read_excel(
  path      = ruta_diccionario,
  sheet     = hoja,
  col_names = FALSE,
  col_types = "text"
)
crudo <- as.data.table(crudo)

# Nos quedan solo las dos primeras columnas, que son las que nos interesan.
colA <- crudo[[1]]   # códigos
colB <- crudo[[2]]   # descripciones y encabezados de sección

# ---- 3. Recorrer las filas y armar el crosswalk ----------------------------
# Recorremos fila por fila llevando memoria de:
#   - 'seccion_actual': la última "SECCIÓN ..." vista.
#   - 'en_eliminados' : si entramos al bloque de códigos dados de baja.
# Guardamos una fila por cada código de 8 dígitos con descripción válida.

seccion_actual <- NA_character_
en_eliminados  <- FALSE
filas <- list()   # acumulador

for (i in seq_len(nrow(crudo))) {

  a <- trimws(ifelse(is.na(colA[i]), "", colA[i]))
  b <- trimws(ifelse(is.na(colB[i]), "", colB[i]))

  # Marcadores en la columna A que cambian el "modo" de lectura.
  if (grepl("^C[OÓ]DIGOS ELIMINADOS", a, ignore.case = TRUE)) {
    en_eliminados <- TRUE; next
  }
  if (grepl("^C[OÓ]DIGOS NUEVOS", a, ignore.case = TRUE)) {
    en_eliminados <- FALSE; next
  }

  # Si la col B trae "SECCIÓN ...", actualizamos la sección y seguimos.
  if (grepl("^SECC", b, ignore.case = TRUE)) {
    seccion_actual <- b; next
  }

  # ¿La col A es un código de prestación (exactamente 8 dígitos)?
  es_codigo <- grepl("^[0-9]{8}$", a)

  # Lo guardamos solo si: es código, NO estamos en el bloque eliminado,
  # y tiene una descripción real (distinta de vacío y de "0").
  if (es_codigo && !en_eliminados && !(b %in% c("", "0"))) {
    filas[[length(filas) + 1]] <- data.table(
      codigo      = a,
      descripcion = b,
      seccion     = seccion_actual
    )
  }
}

crosswalk <- rbindlist(filas)

# ---- 4. Deduplicar y clasificar por tema -----------------------------------
# Algunos códigos aparecen repetidos en la hoja; nos quedamos con la 1ª ocurrencia.
crosswalk <- unique(crosswalk, by = "codigo")

# Etiqueta temática legible a partir del texto de la sección.
crosswalk[, tema := fcase(
  grepl("SECCIÓN A",   seccion), "OIRS / Reclamos y solicitudes",
  grepl("SECCIÓN B",   seccion), "Participación social",
  grepl("SECCIÓN C",   seccion), "Satisfacción usuaria y humanización",
  default = "Otra"
)]

# Metadatos: de qué serie y sección REM proviene.
crosswalk[, `:=`(serie = "A", seccion_rem = "A19b")]

# Ordenamos columnas.
setcolorder(crosswalk, c("serie", "seccion_rem", "tema", "seccion",
                         "codigo", "descripcion"))

# ---- 5. Guardar resultado --------------------------------------------------
dir.create(here("crosswalk"), showWarnings = FALSE)
ruta_salida <- here("crosswalk", "crosswalk_participacion_A19b.csv")

fwrite(crosswalk, ruta_salida, sep = ";", bom = TRUE)

# ---- 6. Resumen en consola -------------------------------------------------
cat("Crosswalk A19b creado:\n")
cat("  Códigos activos:", nrow(crosswalk), "\n")
print(crosswalk[, .N, by = tema])
cat("\nGuardado en:", ruta_salida, "\n")
