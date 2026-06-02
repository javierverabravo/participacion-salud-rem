# =============================================================================
# 11_indicadores.R  ·  Indicadores de AUDITORIA SOCIAL (cruzan los 3 bloques)
# -----------------------------------------------------------------------------
# Construye indicadores operativos que combinan el REM-A19b con un denominador
# poblacional. Se calculan a nivel NACIONAL, por REGION y por COMUNA, y
# alimentan la planilla de sintesis unificada.
#
# DENOMINADOR (con fallback automatico):
#   1. FONASA inscritos validados  (datos/externos/fonasa_comuna.rds)  <- preferido
#   2. Poblacion comunal CASEN 2024 (datos/externos/comunal.rds$poblacion) <- proxy
#   En cuanto exista el archivo FONASA, este toma precedencia. La columna
#   `denominador` en cada salida deja explicito cual se uso.
#
# Indicadores (definiciones operativas):
#   I_fa  Indice de Friccion Administrativa : reclamos OIRS por 1.000 (inscritos/hab).
#   T_se  Tasa de Severidad de Espera       : % de reclamos por tiempos de espera
#                                              sobre el total de reclamos.
#   I_dd  Indice de Densidad Democratica    : participantes en instancias (bloque
#                                              B) por cada 100 (inscritos/hab).
#   I_ci  Indice de Cohesion Intercultural  : actividades interculturales
#                                              (instancias indigenas + asistencia
#                                              espiritual indigena + actividades
#                                              con pueblos originarios) x 1.000.
#   Extra: tasa de respuesta fuera de plazo, razon felicitaciones/reclamos,
#          participacion social per capita, inclusion migrante y de pueblos
#          originarios per capita.
# =============================================================================
suppressPackageStartupMessages({ library(here); library(data.table) })

indicadores_auditoria_social <- function(part, largo, anio, dirs) {
  setDT(part); setDT(largo)

  # ---- denominador con fallback ---------------------------------------------
  fcom <- here("datos", "externos", "fonasa_comuna.rds")
  fon <- NULL; denom_fuente <- "ninguno"
  if (file.exists(fcom)) {
    fon <- readRDS(fcom); setDT(fon); denom_fuente <- "FONASA inscritos validados"
  } else {
    fcas <- here("datos", "externos", "comunal.rds")
    if (file.exists(fcas)) {
      cc <- readRDS(fcas); setDT(cc)
      if ("poblacion" %in% names(cc) && sum(!is.na(cc$poblacion)) > 0) {
        fon <- cc[!is.na(poblacion) & poblacion > 0, .(IdComuna, inscritos = poblacion)]
        denom_fuente <- "Poblacion comunal CASEN 2024 (proxy; reemplazar por FONASA)"
      }
    }
  }

  A <- part[bloque == "A"]
  no_reclamo <- "consulta|sugerenci|felicitaci|solicitud"   # interacciones que NO son reclamo

  # ---- numeradores por comuna (con su region) -------------------------------
  pc <- function(dt, cond, nombre, col = "valor_total") {
    z <- dt[cond, .(v = sum(get(col), na.rm = TRUE)), by = .(IdComuna, IdRegion)]
    setnames(z, "v", nombre); z
  }
  reclamos <- pc(A, !grepl(no_reclamo, A$descripcion, ignore.case = TRUE), "reclamos")
  esp      <- pc(A,  grepl("tiempo de espera", A$descripcion, ignore.case = TRUE), "reclamos_espera")
  feli     <- pc(A,  grepl("felicitaci", A$descripcion, ignore.case = TRUE), "felicitaciones")
  ic_pres  <- pc(part, grepl("pueblos originarios", part$descripcion, ignore.case = TRUE), "ic_pres")

  gl <- function(cond, nombre) {
    z <- largo[cond, .(v = sum(valor, na.rm = TRUE)), by = .(IdComuna, IdRegion)]
    setnames(z, "v", nombre); z
  }
  generados <- gl(largo$bloque == "A" & largo$etiqueta == "Reclamos generados en el mes", "generados")
  fuera     <- gl(largo$bloque == "A" & largo$etiqueta == "Reclamos Respondidos Fuera de Plazos Legales", "fuera_plazo")
  partB     <- gl(largo$bloque == "B" & largo$dimension == "total" &
                  grepl("ambos sexos", largo$etiqueta, ignore.case = TRUE), "participantes_B")
  eveB      <- pc(part, part$bloque == "B", "eventos_B")
  puebl     <- gl(largo$dimension == "pueblos_originarios", "pueblos_part")
  migr      <- gl(largo$dimension == "migrantes", "migrantes_part")
  ic_inst   <- gl((largo$seccion_key == "B.1" & largo$dimension == "instancia" &
                   grepl("ind.gena", largo$etiqueta, ignore.case = TRUE)) |
                  (largo$seccion_key == "C.1" &
                   grepl("ind.gena", largo$etiqueta, ignore.case = TRUE)), "ic_inst")

  tablas <- list(reclamos, esp, feli, generados, fuera, partB, eveB, puebl, migr, ic_inst, ic_pres)
  N <- Reduce(function(a, b) merge(a, b, by = c("IdComuna", "IdRegion"), all = TRUE), tablas)
  for (j in setdiff(names(N), c("IdComuna", "IdRegion")))
    set(N, which(is.na(N[[j]])), j, 0)
  N[, intercultural := ic_inst + ic_pres]
  if (!is.null(fon)) N <- merge(N, fon, by = "IdComuna", all.x = TRUE) else N[, inscritos := NA_real_]

  # ---- calculo de indicadores a partir de numeradores agregados -------------
  den <- function(x) fifelse(is.na(x) | x <= 0, NA_real_, as.numeric(x))
  cols_num <- c("reclamos", "reclamos_espera", "felicitaciones", "generados", "fuera_plazo",
                "participantes_B", "eventos_B", "pueblos_part", "migrantes_part",
                "intercultural", "inscritos")
  calc <- function(g) {
    g[, `:=`(
      I_fa_reclamos_x1000     = round(1000 * reclamos / den(inscritos), 2),
      T_se_pct                = round(100 * reclamos_espera / pmax(reclamos, 1), 1),
      I_dd_partic_x100        = round(100 * participantes_B / den(inscritos), 2),
      I_ci_intercult_x1000    = round(1000 * intercultural / den(inscritos), 3),
      tasa_fuera_plazo_pct    = round(100 * fuera_plazo / pmax(generados, 1), 1),
      razon_felicit_reclamos  = round(felicitaciones / pmax(reclamos, 1), 2),
      participacion_B_x1000   = round(1000 * eventos_B / den(inscritos), 2),
      migrantes_part_x1000    = round(1000 * migrantes_part / den(inscritos), 2),
      pueblos_part_x1000      = round(1000 * pueblos_part / den(inscritos), 2))]
    g[, denominador := denom_fuente]
    g[]
  }

  nac <- calc(N[, c(.(nivel = "Nacional"), lapply(.SD, sum, na.rm = TRUE)), .SDcols = cols_num])
  reg <- calc(N[, lapply(.SD, sum, na.rm = TRUE), by = IdRegion, .SDcols = cols_num][order(IdRegion)])
  com <- calc(copy(N))[order(-I_fa_reclamos_x1000)]

  fwrite(nac, file.path(dirs, "indicadores_auditoria_nacional.csv