# =============================================================================
# 09_sintesis.R  ·  SINTESIS — comparacion de los tres bloques (A, B, C)
# -----------------------------------------------------------------------------
# Entregable transversal que resume y compara las tres secciones. Reutiliza los
# productos ya calculados por 20/21/22 (productos/A, /B, /C) y agrega analisis
# que solo tienen sentido cruzando los bloques:
#   - Tabla comparativa A vs B vs C (cobertura, intensidad, subregistro,
#     brechas de genero/migracion, ICC y descomposicion de varianza, pobreza).
#   - Tipologias cross-tema (k-means sobre la composicion A/B/C de cada
#     establecimiento): "participar" significa cosas distintas segun el tipo.
#   - Matriz region x bloque: que bloque domina la actividad de cada region.
#   - INDICADORES DE AUDITORIA SOCIAL (05_indicadores.R): I_fa, T_se, I_dd,
#     I_ci y extras, con denominador FONASA (o poblacion CASEN como proxy).
# Salidas en productos/sintesis/.
# =============================================================================
library(here)
library(data.table)
source(here("R", "04_engine.R"))
source(here("R", "05_indicadores.R"))

anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
dirs <- here("productos", "sintesis"); dir.create(dirs, recursive = TRUE, showWarnings = FALSE)
message("\n==== SINTESIS - comparacion A / B / C ====")

bloques <- c(A = "OIRS / Reclamos y solicitudes",
             B = "Participacion social",
             C = "Satisfaccion usuaria y humanizacion")

# ---- helpers para leer productos ya calculados -----------------------------
leer_val <- function(blq, archivo, ind) {
  f <- here("productos", blq, archivo); if (!file.exists(f)) return(NA_real_)
  dt <- fread(f, sep = ";")
  if (!("indicador" %in% names(dt)) || !(ind %in% dt$indicador)) return(NA_real_)
  as.numeric(dt[indicador == ind, valor][1])
}
# Coincidencia por prefijo, a prueba de tildes ("^Regi" calza con "Region"/"Región").
leer_var <- function(blq, patron) {
  f <- here("productos", blq, "modelo_multinivel_var.csv"); if (!file.exists(f)) return(NA_real_)
  dt <- fread(f, sep = ";"); v <- dt[grepl(patron, nivel), pct_varianza]
  if (length(v) == 0) NA_real_ else as.numeric(v[1])
}

# ---- 1. Tabla comparativa de los tres bloques ------------------------------
comp <- rbindlist(lapply(names(bloques), function(b) data.table(
  bloque = b, tema = bloques[[b]],
  cobertura_pct              = leer_val(b, "kpis.csv", "pct_cobertura"),
  total_eventos              = leer_val(b, "kpis.csv", "total_eventos"),
  intensidad_por_estab       = leer_val(b, "kpis.csv", "intensidad_por_estab"),
  pct_subregistro_estab_mes  = leer_val(b, "kpis.csv", "pct_subregistro_estab_mes"),
  mediana_meses_con_registro = leer_val(b, "kpis.csv", "mediana_meses_con_registro"),
  total_personas             = leer_val(b, "equidad_kpis.csv", "total_personas"),
  pct_mujeres                = leer_val(b, "equidad_kpis.csv", "pct_mujeres"),
  brecha_genero_pp           = leer_val(b, "equidad_kpis.csv", "brecha_genero_pp"),
  pct_migrantes              = leer_val(b, "equidad_kpis.csv", "pct_migrantes"),
  pct_pueblos_originarios    = leer_val(b, "equidad_kpis.csv", "pct_pueblos_originarios"),
  pct_prais                  = leer_val(b, "equidad_kpis.csv", "pct_prais"),
  icc_barrera_pct            = leer_val(b, "modelo_icc.csv", "icc_barrera_pct"),
  var_establecimiento_pct    = leer_var(b, "^Estab"),
  var_comuna_pct             = leer_var(b, "^Comuna"),
  var_region_pct             = leer_var(b, "^Regi"),
  OR_pobreza_x10pp           = leer_val(b, "modelo_determinantes.csv", "OR_pobreza_x10pp"),
  pobreza_p_valor            = leer_val(b, "modelo_determinantes.csv", "p_valor")
)))
fwrite(comp, file.path(dirs, "comparativo_bloques.csv"), sep = ";", bom = TRUE)

# ---- 2. Tipologias cross-tema (composicion A/B/C por establecimiento) ------
part  <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)
largo <- readRDS(here("datos", as.character(anio), "participacion_largo.rds")); setDT(largo)
est   <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)

cmp <- part[, .(v = sum(valor_total, na.rm = TRUE)), by = .(IdEstablecimiento, bloque)]
cmp <- dcast(cmp, IdEstablecimiento ~ bloque, value.var = "v", fill = 0)
for (b in c("A", "B", "C")) if (!b %in% names(cmp)) cmp[, (b) := 0]
cmp[, total := A + B + C]
cmp <- cmp[total > 0]
cmp[, `:=`(sh_A = A / total, sh_B = B / total, sh_C = C / total)]

Z <- scale(cmp[, .(sh_A, sh_B, sh_C)]); Z[is.nan(Z)] <- 0
set.seed(123)
km <- kmeans(Z, centers = 4, nstart = 25)
cmp[, perfil := km$cluster]
perfil <- cmp[, .(n_establecimientos = .N,
                  pct_A = round(100 * mean(sh_A), 1),
                  pct_B = round(100 * mean(sh_B), 1),
                  pct_C = round(100 * mean(sh_C), 1)), by = perfil][order(perfil)]
perfil[, etiqueta := fcase(
  pct_A >= pmax(pct_B, pct_C), "Centrado en OIRS / reclamos",
  pct_B >= pmax(pct_A, pct_C), "Fuerte en participacion social",
  pct_C >= pmax(pct_A, pct_B), "Orientado a satisfaccion usuaria",
  default = "Mixto")]
fwrite(perfil, file.path(dirs, "tipologias_perfil.csv"), sep = ";", bom = TRUE)

asign <- merge(cmp[, .(IdEstablecimiento, perfil)],
               est[, .(IdEstablecimiento, TipoEstablecimientoGlosa, IdRegion)],
               by = "IdEstablecimiento", all.x = TRUE)
fwrite(asign, file.path(dirs, "tipologias_asignacion.csv"), sep = ";", bom = TRUE)

# ---- 3. Matriz region x bloque (composicion de la actividad por region) ----
rb <- part[, .(eventos = sum(valor_total, na.rm = TRUE)), by = .(IdRegion, bloque)]
rb[, pct_region := round(100 * eventos / sum(eventos), 1), by = IdRegion]
rb <- dcast(rb, IdRegion ~ bloque, value.var = "pct_region", fill = 0)
fwrite(rb[order(IdRegion)], file.path(dirs, "region_x_bloque.csv"), sep = ";", bom = TRUE)

# ---- 3b. Consolidado TERRITORIAL por bloque (insumo de la pagina Territorio) -
# Region x bloque con cobertura + % pueblos originarios + % migrantes, leyendo
# los productos por bloque (cobertura_region.csv y equidad_region.csv).
ter <- rbindlist(lapply(c("A", "B", "C"), function(b) {
  fc <- here("productos", b, "cobertura_region.csv")
  fe <- here("productos", b, "equidad_region.csv")
  if (!file.exists(fc)) return(NULL)
  cc <- fread(fc, sep = ";")[, .(IdRegion, cobertura_pct = pct, n_estab = n_total)]
  if (file.exists(fe)) {
    ee <- fread(fe, sep = ";")[, .(IdRegion, pct_pueblos_originarios, pct_migrantes)]
    cc <- merge(cc, ee, by = "IdRegion", all.x = TRUE)
  }
  cc[, bloque := b]; cc
}), fill = TRUE)
if (nrow(ter))
  fwrite(ter[order(bloque, IdRegion)], file.path(dirs, "territorio_region.csv"),
         sep = ";", bom = TRUE)

# ---- 4. Indicadores de auditoria social (con denominador FONASA/CASEN) -----
indicadores_auditoria_social(part, largo, anio, dirs)

# ---- Resumen ---------------------------------------------------------------
cat("\nComparativo de bloques:\n"); print(comp[, .(bloque, cobertura_pct, total_eventos,
  pct_subregistro_estab_mes, brecha_genero_pp, pct_migrantes, icc_barrera_pct)])
cat("\nTipologias cross-tema (k-means k=4):\n"); print(perfil)
message("\nSintesis lista. Productos en productos/sintesis/")
