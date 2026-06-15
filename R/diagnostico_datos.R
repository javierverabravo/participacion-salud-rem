# =============================================================================
# diagnostico_datos.R  ·  Caracterizacion empirica del dato (diagnosticar-datos)
# -----------------------------------------------------------------------------
# Describe la estructura del dato preparado ANTES de elegir modelo: exceso de
# ceros, forma de la cola, sobredispersion, faltantes (NA real vs filas ausentes)
# e intermitencia. No elige modelo: deja por escrito por que un Poisson naive no
# sirve y por que corresponde un hurdle con efectos por establecimiento.
#
# Requisito: 01_procesamiento.R ya corrido para el ano (genera los .rds).
# Uso (consola de R):  source("R/diagnostico_datos.R")
# =============================================================================
suppressPackageStartupMessages({ library(here); library(data.table) })
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))

part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)
uni  <- readRDS(here("datos", as.character(anio), "universo_estab_mes.rds")); setDT(uni)
dir_out <- here("productos", "diagnostico"); dir.create(dir_out, recursive = TRUE, showWarnings = FALSE)

resumen <- list()
for (blq in c("A", "B", "C")) {
  # NA real dentro de las filas presentes (no colapsado a 0).
  na_en_filas <- part[bloque == blq, mean(is.na(valor_total))]
  # Panel del bloque sobre el universo (estab x mes activos en Serie A).
  pb  <- part[bloque == blq, .(valor = sum(valor_total, na.rm = TRUE)),
              by = .(IdEstablecimiento, Mes)]
  pan <- merge(uni[, .(IdEstablecimiento, Mes)], pb,
               by = c("IdEstablecimiento", "Mes"), all.x = TRUE)
  pan[is.na(valor), valor := 0]
  pos <- pan[valor > 0, valor]
  reg <- pan[valor > 0, .N, by = IdEstablecimiento]
  resumen[[blq]] <- data.table(
    bloque = blq,
    estab_mes_panel = nrow(pan),
    pct_ceros_panel = round(100 * mean(pan$valor == 0), 1),   # exceso de ceros
    pct_positivos   = round(100 * mean(pan$valor > 0), 1),
    pct_NA_en_filas = round(100 * na_en_filas, 1),            # NA real (NA != 0)
    media_positivos = round(mean(pos), 1),
    var_positivos   = round(var(pos), 1),
    razon_var_media = round(var(pos) / max(mean(pos), 1e-9), 1), # >1 sobredispersion
    mediana_positivos = as.numeric(median(pos)),
    p95_positivos     = as.numeric(quantile(pos, 0.95)),
    max_positivos     = max(pos),
    mediana_meses_con_registro = if (nrow(reg)) as.numeric(median(reg$N)) else 0)
}
res <- rbindlist(resumen)
fwrite(res, file.path(dir_out, "diagnostico_estructura.csv"), sep = ";", bom = TRUE)
print(res)
message("Diagnostico escrito en productos/diagnostico/diagnostico_estructura.csv")
# Lectura: pct_ceros_panel alto + razon_var_media >> 1 + cola larga (max >> mediana)
# => conteos con exceso de ceros y sobredispersion. Un Poisson o un lineal naive
# subestiman el error; corresponde HURDLE (barrera + intensidad) con efecto
# aleatorio por establecimiento. Justifica la eleccion de 04_engine / investigar-metodo.
