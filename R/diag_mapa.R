# =============================================================================
# diag_mapa.R · Diagnóstico paso a paso del mapa interactivo de Territorio
# -----------------------------------------------------------------------------
# Correr en Positron desde la raíz del proyecto:  source("R/diag_mapa.R")
# Ejecuta el mismo código del chunk del mapa pero anunciando cada paso.
# Si algo falla, el último "PASO" impreso indica exactamente dónde.
# =============================================================================
library(data.table)

paso <- function(x) cat("\nPASO:", x, "\n")

paso("paquetes")
for (p in c("leaflet","sf","chilemapas","htmlwidgets","jsonlite"))
  cat(sprintf("  %-12s %s\n", p, ifelse(requireNamespace(p, quietly = TRUE), "ok", "FALTA")))
suppressPackageStartupMessages({ library(sf); library(leaflet) })

gp <- function(blq, name) {
  f <- file.path("productos", blq, paste0(name, ".csv"))
  if (file.exists(f)) fread(f, sep = ";", encoding = "UTF-8") else NULL
}
gs <- function(name) {
  f <- file.path("productos", "sintesis", paste0(name, ".csv"))
  if (file.exists(f)) fread(f, sep = ";", encoding = "UTF-8") else NULL
}
reg_nom <- data.table(
  IdRegion = c(15,1,2,3,4,5,13,6,7,16,8,9,14,10,11,12),
  region   = c("Arica y Parinacota","Tarapacá","Antofagasta","Atacama",
               "Coquimbo","Valparaíso","Metropolitana","O'Higgins","Maule",
               "Ñuble","Biobío","La Araucanía","Los Ríos","Los Lagos",
               "Aysén","Magallanes"))

paso("leer territorio_comuna")
tc <- gs("territorio_comuna"); stopifnot(!is.null(tc))
tc <- tc[bloque == "A", .(codigo_comuna = sprintf("%05d", IdComuna),
         cobertura, pct_pobreza, poblacion = as.numeric(poblacion),
         servicio_salud, IdRegion)]
str(tc)

paso("merge nombres de región")
tc <- merge(tc, reg_nom, by = "IdRegion", all.x = TRUE)

paso("modelo_comuna")
mc <- gp("A", "modelo_comuna")
if (!is.null(mc)) {
  mc[, codigo_comuna := sprintf("%05d", IdComuna)]
  tc <- merge(tc, mc[, .(codigo_comuna, prob_pct = round(prob_registra * 100, 1))],
              by = "codigo_comuna", all.x = TRUE)
} else tc[, prob_pct := NA_real_]

paso("indicadores auditoria comuna")
ia <- gs("indicadores_auditoria_comuna")
if (!is.null(ia) && "I_fa_reclamos_x1000" %in% names(ia)) {
  ia[, codigo_comuna := sprintf("%05d", IdComuna)]
  tc <- merge(tc, ia[, .(codigo_comuna, I_fa = round(I_fa_reclamos_x1000, 2))],
              by = "codigo_comuna", all.x = TRUE)
} else tc[, I_fa := NA_real_]

paso("lisa")
lc <- gp("A", "lisa_comuna")
if (!is.null(lc)) {
  lc[, codigo_comuna := as.character(codigo_comuna)]
  lc[nchar(codigo_comuna) < 5, codigo_comuna := formatC(codigo_comuna, width = 5, flag = "0")]
  tc <- merge(tc, lc[, .(codigo_comuna, lisa_cluster)], by = "codigo_comuna", all.x = TRUE)
  tc[is.na(lisa_cluster), lisa_cluster := "No significativo"]
} else tc[, lisa_cluster := "No significativo"]

paso("nombres de comuna (codigos_territoriales)")
nom <- unique(as.data.frame(
  chilemapas::codigos_territoriales)[, c("codigo_comuna", "nombre_comuna")])
cat("  filas nombres:", nrow(nom), "\n")

paso("st_as_sf(mapa_comunas)")
mapa <- sf::st_as_sf(chilemapas::mapa_comunas)
cat("  clase:", paste(class(mapa), collapse = "/"), " filas:", nrow(mapa), "\n")

paso("merge shapes + nombres (data.frame, no data.table)")
mapa <- merge(mapa, nom, by = "codigo_comuna", all.x = TRUE)

paso("merge shapes + datos")
mapa <- merge(mapa, as.data.frame(tc), by = "codigo_comuna")
cat("  filas tras merge:", nrow(mapa), "\n")

paso("st_transform 4326")
mapa <- sf::st_transform(mapa, 4326)

paso("etiquetas sprintf")
lab_txt <- sprintf(
  "<b>%s</b> · %s | Cobertura %s%%",
  ifelse(is.na(mapa$nombre_comuna), mapa$codigo_comuna, mapa$nombre_comuna),
  mapa$region, mapa$cobertura)
cat("  etiquetas:", length(lab_txt), "\n")

paso("toJSON")
j <- jsonlite::toJSON(list(a = mapa$cobertura[1], b = mapa$servicio_salud[1]),
                      auto_unbox = TRUE, na = "null")

paso("leaflet basico")
pal <- leaflet::colorNumeric(c("#f7fcf5","#74c476","#005a32"), domain = c(0,100),
                             na.color = "#e8e8e8")
m <- leaflet(mapa) |> addProviderTiles("CartoDB.Positron") |>
  addPolygons(fillColor = ~pal(cobertura), weight = 0.5, color = "white",
              fillOpacity = 0.88, label = lapply(lab_txt, htmltools::HTML))
print("Mapa creado sin errores. Si esto corre completo, el chunk del dashboard debería funcionar.")
m
