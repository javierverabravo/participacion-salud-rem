# =============================================================================
# 03_analisis_subregistro.R
# -----------------------------------------------------------------------------
# OBJETIVO (responde a la pregunta de investigación 5, y parte de la 1)
#   Caracterizar el PATRÓN DE PARTICIPACIÓN Y SUBREGISTRO de la sección A19b:
#     (A) Margen extensivo : ¿qué fracción de los establecimientos activos
#                            registra ALGUNA participación? (¿quién queda fuera?)
#     (B) Intermitencia     : para los pares establecimiento-prestación que SÍ
#                            existen, ¿en cuántos meses se registran? (continuidad)
#     (C) Estados del panel : sobre el panel "razonable" (pares observados ×
#                            12 meses), qué % son ausencias, ceros o positivos.
#
# IDEA CENTRAL (hallazgo del paso anterior):
#   El subregistro NO está en los NA dentro de las filas, sino en las FILAS
#   AUSENTES. Aquí lo cuantificamos construyendo explícitamente el panel.
#
# ENTRADA : datos/<AÑO>/participacion_A19b.rds  +  Serie A (solo columnas de ID)
# SALIDA  : salidas/ (tablas .csv y figuras .png) — carpeta ignorada por Git
# =============================================================================

# ---- 0. Paquetes -----------------------------------------------------------
# Nuevo: ggplot2 (gráficos). Si no lo tienes: install.packages("ggplot2")
library(here)
library(data.table)
library(ggplot2)

# Carpetas de salida.
dir_salidas <- here("salidas")
dir_figuras <- here("salidas", "figuras")
dir.create(dir_figuras, recursive = TRUE, showWarnings = FALSE)

# Helper para formatear enteros con separador de miles sin warnings de locale.
fmt <- function(x) formatC(x, format = "d", big.mark = ".")

# ---- 1. Cargar datos -------------------------------------------------------
anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))

part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds"))
setDT(part)

# Universo de establecimientos ACTIVOS en la Serie A (denominador del margen
# extensivo). Leemos solo columnas de ID para que sea rápido y liviano.
ruta_serieA <- list.files(here("datos", as.character(anio)),
                          pattern = sprintf("SerieA%d\\.csv$", anio),
                          full.names = TRUE, recursive = TRUE)[1]

universo <- fread(ruta_serieA, sep = ";", encoding = "UTF-8",
                  select = c("IdEstablecimiento", "IdRegion", "IdComuna"))
universo <- unique(universo, by = "IdEstablecimiento")
n_estab_total <- nrow(universo)

# =============================================================================
# (A) MARGEN EXTENSIVO: ¿quién participa del sistema de participación?
# =============================================================================
estab_participa <- unique(part$IdEstablecimiento)
n_estab_part    <- length(estab_participa)

cat("==========================================================\n")
cat("(A) MARGEN EXTENSIVO\n")
cat("----------------------------------------------------------\n")
cat(sprintf("Establecimientos activos en Serie A : %s\n", fmt(n_estab_total)))
cat(sprintf("Registran ALGUNA participación      : %s (%.1f%%)\n",
            fmt(n_estab_part), 100 * n_estab_part / n_estab_total))
cat(sprintf("NUNCA registran participación       : %s (%.1f%%)\n",
            fmt(n_estab_total - n_estab_part),
            100 * (n_estab_total - n_estab_part) / n_estab_total))

# Cobertura por región: % de establecimientos que participan en cada región.
universo[, participa := IdEstablecimiento %in% estab_participa]
cobertura_region <- universo[, .(
  n_total    = .N,
  n_participa = sum(participa),
  pct        = round(100 * mean(participa), 1)
), by = IdRegion][order(IdRegion)]

cat("\nCobertura por región (% de establecimientos que participan):\n")
print(cobertura_region)
fwrite(cobertura_region, file.path(dir_salidas, "cobertura_region.csv"),
       sep = ";", bom = TRUE)

# Gráfico A: cobertura por región.
g_cob <- ggplot(cobertura_region, aes(x = factor(IdRegion), y = pct)) +
  geom_col(fill = "#2c7fb8") +
  geom_text(aes(label = paste0(pct, "%")), vjust = -0.3, size = 3) +
  labs(title = "Cobertura de participación por región",
       subtitle = "% de establecimientos activos que registran alguna actividad A19b",
       x = "Región (IdRegion)", y = "% establecimientos") +
  theme_minimal()
ggsave(file.path(dir_figuras, "A_cobertura_region.png"), g_cob,
       width = 9, height = 5, dpi = 120)

# =============================================================================
# (B) INTERMITENCIA TEMPORAL: continuidad del registro
# =============================================================================
# Para cada par (establecimiento, prestación) que aparece al menos una vez,
# contamos en cuántos meses distintos se registró (de 1 a 12).
meses_por_par <- part[, .(meses_registrados = uniqueN(Mes)),
                      by = .(IdEstablecimiento, CodigoPrestacion)]

cat("\n==========================================================\n")
cat("(B) INTERMITENCIA TEMPORAL\n")
cat("----------------------------------------------------------\n")
cat("Distribución de meses registrados por par establecimiento-prestación:\n")
print(meses_por_par[, .(
  pares          = .N,
  media_meses    = round(mean(meses_registrados), 1),
  mediana_meses  = median(meses_registrados),
  pct_un_solo_mes = round(100 * mean(meses_registrados == 1), 1),
  pct_doce_meses  = round(100 * mean(meses_registrados == 12), 1)
)])

# Gráfico B: histograma de meses registrados.
g_int <- ggplot(meses_por_par, aes(x = meses_registrados)) +
  geom_bar(fill = "#de2d26") +
  scale_x_continuous(breaks = 1:12) +
  labs(title = "Intermitencia del registro de participación",
       subtitle = "Nº de meses (de 12) en que cada par establecimiento-prestación aparece",
       x = "Meses registrados en el año", y = "Nº de pares") +
  theme_minimal()
ggsave(file.path(dir_figuras, "B_intermitencia.png"), g_int,
       width = 9, height = 5, dpi = 120)

# =============================================================================
# (C) ESTADOS DEL PANEL: ausencia vs cero vs positivo
# =============================================================================
# Panel "razonable": los pares (estab-prestación) observados al menos una vez,
# expandidos a los 12 meses. Cada celda se clasifica en uno de tres estados.
pares <- unique(part[, .(IdEstablecimiento, CodigoPrestacion)])
# Producto cartesiano: cada par observado × cada uno de los 12 meses.
combos <- CJ(idx = seq_len(nrow(pares)), Mes = 1:12)
panel  <- cbind(pares[combos$idx], Mes = combos$Mes)

# Pegamos el valor observado (si existe la fila).
obs <- part[, .(IdEstablecimiento, CodigoPrestacion, Mes, valor_total)]
panel <- merge(panel, obs,
               by = c("IdEstablecimiento", "CodigoPrestacion", "Mes"),
               all.x = TRUE, sort = FALSE)

panel[, estado := fcase(
  is.na(valor_total),                 "Ausente (sin fila = subregistro probable)",
  valor_total == 0,                   "Cero explícito",
  default =                           "Positivo"
)]

resumen_panel <- panel[, .(n = .N), by = estado][, pct := round(100 * n / sum(n), 1)][]
cat("\n==========================================================\n")
cat("(C) ESTADOS DEL PANEL (pares observados × 12 meses)\n")
cat("----------------------------------------------------------\n")
cat(sprintf("Celdas totales del panel: %s\n", fmt(nrow(panel))))
print(resumen_panel[order(-n)])
fwrite(resumen_panel, file.path(dir_salidas, "estados_panel.csv"),
       sep = ";", bom = TRUE)

# Gráfico C: composición del panel.
g_pan <- ggplot(resumen_panel, aes(x = reorder(estado, -pct), y = pct, fill = estado)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(pct, "%")), vjust = -0.3, size = 3.5) +
  labs(title = "Composición del panel de participación",
       subtitle = "Sobre pares establecimiento-prestación observados, expandidos a 12 meses",
       x = NULL, y = "% de celdas") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 15, hjust = 1))
ggsave(file.path(dir_figuras, "C_estados_panel.png"), g_pan,
       width = 9, height = 5, dpi = 120)

cat("\nFiguras y tablas guardadas en salidas/.\n")
