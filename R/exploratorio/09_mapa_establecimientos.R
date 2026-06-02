# =============================================================================
# 09_mapa_establecimientos.R  ·  Datos para el mapa interactivo de establecimientos
# -----------------------------------------------------------------------------
# OBJETIVO: una tabla en formato LARGO con una fila por establecimiento × tema de
# participación, con sus coordenadas, tipo y nivel de actividad. El formato largo
# permite FILTRAR el mapa por tipo de actividad (OIRS, participación social,
# satisfacción) además de por región y tipo de establecimiento.
#
# "actividades" = suma de la columna TOTAL (Col01) de todas las prestaciones A19b
# de ese establecimiento en ese tema durante el año. Es el VOLUMEN registrado
# (un reclamo, una sesión de consejo, una medición de satisfacción cuentan como
# actividades). Como el volumen de OIRS es mucho mayor, conviene mirarlo por tema.
#
# ENTRADA : datos/establecimientos_lookup.rds        (coords, tipo, región)
#           datos/<AÑO>/participacion_A19b.rds        (actividades por estab. y tema)
# SALIDA  : productos/mapa_establecimientos.csv       (formato largo)
# =============================================================================
library(here)
library(data.table)

anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
est  <- readRDS(here("datos", "establecimientos_lookup.rds")); setDT(est)
part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)

# ---- Tipo de establecimiento agrupado (idéntico al resto del pipeline) ------
principales <- c("Posta de Salud Rural (PSR)","Centro de Salud Familiar (CESFAM)",
  "Centro Comunitario de Salud Familiar (CECOSF)",
  "Servicio de Atención Primaria de Urgencia (SAPU)","Hospital",
  "Servicio de Urgencia Rural (SUR)","Centro Comunitario de Salud Mental  (COSAM)",
  "Servicio de Atención Primaria de Urgencia de Alta Resolutividad (SAR)")
corto <- c("Posta Rural (PSR)","CESFAM","CECOSF","SAPU","Hospital","SUR","COSAM","SAR")
names(corto) <- principales
est[, tipo_grp := ifelse(TipoEstablecimientoGlosa %in% principales,
                         corto[TipoEstablecimientoGlosa], "Otro")]
est[is.na(tipo_grp), tipo_grp := "Otro"]

# ---- Actividad por establecimiento Y TEMA ----------------------------------
recode_tema <- function(x) fcase(
  x == "OIRS / Reclamos y solicitudes", "OIRS / Reclamos",
  x == "Participación social", "Participación social",
  x == "Satisfacción usuaria y humanización", "Satisfacción",
  default = x)
act <- part[!is.na(valor_total) & valor_total > 0,
            .(actividades = sum(valor_total)), by = .(IdEstablecimiento, tema)]
act[, tema_c := recode_tema(tema)]

# ---- Nombres de región (para el desplegable) -------------------------------
reg_nom <- data.table(
  IdRegion = c(15,1,2,3,4,5,13,6,7,16,8,9,14,10,11,12),
  region   = c("Arica y Parinacota","Tarapacá","Antofagasta","Atacama",
               "Coquimbo","Valparaíso","Metropolitana","O'Higgins","Maule",
               "Ñuble","Biobío","La Araucanía","Los Ríos","Los Lagos",
               "Aysén","Magallanes"))

# ---- Unir coordenadas, tipo y región ---------------------------------------
m <- merge(act,
           est[, .(IdEstablecimiento, IdRegion, ComunaGlosa, tipo_grp,
                   Latitud, Longitud)],
           by = "IdEstablecimiento", all.x = TRUE)
m <- merge(m, reg_nom, by = "IdRegion", all.x = TRUE)

# Coordenadas a numérico (vienen como texto; pueden traer coma decimal).
num <- function(x) suppressWarnings(as.numeric(gsub(",", ".", x)))
m[, Latitud := num(Latitud)][, Longitud := num(Longitud)]
m <- m[!is.na(Latitud) & !is.na(Longitud) &
       Latitud > -57 & Latitud < -17 & Longitud > -110 & Longitud < -66]

# Nombre del establecimiento (desde la base maestra, por código nuevo o antiguo).
maestra <- fread(here("datos", "establecimientos_maestra.csv"), sep = ";",
                 encoding = "UTF-8", colClasses = "character",
                 select = c("EstablecimientoCodigo", "EstablecimientoCodigoAntiguo",
                            "EstablecimientoGlosa"))
nom <- unique(rbindlist(list(
  maestra[EstablecimientoCodigo != "",
          .(cod = EstablecimientoCodigo, nombre = EstablecimientoGlosa)],
  maestra[!is.na(EstablecimientoCodigoAntiguo) & EstablecimientoCodigoAntiguo != "",
          .(cod = EstablecimientoCodigoAntiguo, nombre = EstablecimientoGlosa)])),
  by = "cod")
m[, cod := as.character(IdEstablecimiento)]
m <- merge(m, nom, by = "cod", all.x = TRUE)
m[is.na(nombre) | nombre == "", nombre := tipo_grp]   # respaldo si falta el nombre

# Nivel de actividad (para describir el punto en el popup).
m[, activo := fcase(actividades <= 20, "Baja",
                    actividades <= 200, "Media",
                    default = "Alta")]

fwrite(m[, .(IdEstablecimiento, nombre, IdRegion, region, ComunaGlosa, tipo_grp,
             tema = tema_c, Latitud, Longitud, actividades, activo)],
       here("productos", "mapa_establecimientos.csv"), sep = ";", bom = TRUE)

cat("mapa_establecimientos.csv :", nrow(m),
    "filas (establecimiento × tema) con coordenadas válidas\n")
cat("Establecimientos distintos en el mapa:", m[, uniqueN(IdEstablecimiento)], "\n")
