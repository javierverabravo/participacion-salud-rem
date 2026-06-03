# =============================================================================
# 04_engine.R  ·  MOTOR de análisis por bloque (funciones reutilizables)
# -----------------------------------------------------------------------------
# Toda la lógica analítica vive aquí UNA sola vez, parametrizada por `blq`
# (A = OIRS, B = participación social, C = satisfacción usuaria). Los runners
# 20/21/22 sólo cargan datos y llaman estas funciones; la síntesis (30) las
# reutiliza. Cada función escribe sus salidas en productos/<blq>/.
#
# El mismo flujo que veníamos usando, ahora aplicado sección por sección:
#   KPIs · cobertura territorial · serie temporal · equidad (sexo/género/
#   migración/pueblos/PRAIS) · subsecciones propias · hurdle mixto ·
#   multinivel 3 niveles · autocorrelación espacial · tipologías k-means.
#
# SALVAGUARDA: los modelos pesados (glmer/lmer/Moran/k-means) van envueltos en
# tryCatch y chequeos de convergencia. Si un bloque es demasiado ralo para un
# modelo, se registra el motivo en productos/<blq>/modelo_estado.csv y el
# pipeline continúa, sin abortar el resto del análisis.
#
# NOTA de diseño: el parámetro se llama `blq` (no `bloque`) a propósito, para no
# colisionar con la columna `bloque` de las tablas dentro de los filtros de
# data.table (evita el bug clásico de auto-comparación columna == columna).
# =============================================================================
suppressPackageStartupMessages({
  library(here)
  library(data.table)
  library(lme4)
})

# ---- utilitarios -----------------------------------------------------------

dir_bloque <- function(blq) {
  d <- here("productos", blq)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  d
}

# Registro de estado de un modelo (convergió / por qué no).
.estado <- function(dirb, modelo, estado, detalle = "") {
  f <- file.path(dirb, "modelo_estado.csv")
  fila <- data.table(modelo = modelo, estado = estado, detalle = detalle,
                     ts = as.character(Sys.time()))
  if (file.exists(f)) fila <- rbind(fread(f, sep = ";"), fila, fill = TRUE)
  fwrite(fila, f, sep = ";", bom = TRUE)
  message(sprintf("  [%s] %s -> %s %s", dirb, modelo, estado,
                  if (nzchar(detalle)) paste0("(", detalle, ")") else ""))
}

# Agrupación de tipo de establecimiento (top 8 + Otro).
tipo_agrupado <- function(est) {
  principales <- c("Posta de Salud Rural (PSR)", "Centro de Salud Familiar (CESFAM)",
    "Centro Comunitario de Salud Familiar (CECOSF)",
    "Servicio de Atención Primaria de Urgencia (SAPU)", "Hospital",
    "Servicio de Urgencia Rural (SUR)", "Centro Comunitario de Salud Mental  (COSAM)",
    "Servicio de Atención Primaria de Urgencia de Alta Resolutividad (SAR)")
  corto <- c("Posta Rural (PSR)", "CESFAM", "CECOSF", "SAPU", "Hospital",
             "SUR", "COSAM", "SAR")
  names(corto) <- principales
  est[, tipo_grp := ifelse(TipoEstablecimientoGlosa %in% principales,
                           corto[TipoEstablecimientoGlosa], "Otro")]
  est[is.na(tipo_grp), tipo_grp := "Otro"]
  # Nivel de atencion (limpio) desde la glosa oficial del DEIS.
  if ("NivelAtencionEstabglosa" %in% names(est)) {
    na_glosa <- est$NivelAtencionEstabglosa
    est[, nivel_atencion := fcase(
      grepl("primar",   na_glosa, ignore.case = TRUE), "Primario (APS)",
      grepl("secundar", na_glosa, ignore.case = TRUE), "Secundario",
      grepl("terciar",  na_glosa, ignore.case = TRUE), "Terciario",
      default = "No aplica / otro")]
  } else est[, nivel_atencion := "No aplica / otro"]
  # Universo participativo: urgencias (SAPU/SUR/SAR) casi no registran
  # participacion por diseno de su funcion -> ceros estructurales, no subregistro.
  est[, participa_estructural := !(tipo_grp %in% c("SAPU", "SUR", "SAR"))]
  est[]
}

# Factor de tipo con CESFAM como referencia (si está presente).
.factor_tipo <- function(x) {
  f <- factor(x)
  if ("CESFAM" %in% levels(f)) f <- relevel(f, ref = "CESFAM")
  f
}

# ---- 1. Panel establecimiento × mes del bloque -----------------------------
# valor = suma de valor_total (Col01 de cada prestación) del bloque, por
# establecimiento y mes. reporta = 1 si registró algo ese mes.
construir_panel <- function(part, est, universo, blq) {
  panel <- copy(universo)
  pt <- part[bloque == blq, .(valor = sum(valor_total, na.rm = TRUE)),
             by = .(IdEstablecimiento, Mes)]
  panel <- merge(panel, pt, by = c("IdEstablecimiento", "Mes"),
                 all.x = TRUE, sort = FALSE)
  panel[is.na(valor), valor := 0]
  panel <- merge(panel, est[, .(IdEstablecimiento, tipo_grp, nivel_atencion, participa_estructural)],
                 by = "IdEstablecimiento", all.x = TRUE, sort = FALSE)
  panel[is.na(tipo_grp), tipo_grp := "Otro"]
  panel[is.na(nivel_atencion), nivel_atencion := "No aplica / otro"]
  panel[is.na(participa_estructural), participa_estructural := FALSE]
  panel[, reporta := as.integer(valor > 0)]
  panel[]
}

# ---- 2. KPIs del bloque ----------------------------------------------------
kpis_bloque <- function(part, est, panel, largo, blq, dirb) {
  pb <- part[bloque == blq]
  estab_part <- unique(pb$IdEstablecimiento)
  n_estab_total <- est[, uniqueN(IdEstablecimiento)]
  total_personas <- largo[bloque == blq & dimension == "total" &
                          grepl("ambos sexos", etiqueta, ignore.case = TRUE),
                          sum(valor, na.rm = TRUE)]
  reg <- panel[reporta == 1, .N, by = IdEstablecimiento]  # meses con registro
  k <- data.table(
    indicador = c("establecimientos_activos", "establecimientos_participan",
                  "pct_cobertura", "prestaciones_monitoreadas",
                  "total_eventos", "total_personas", "intensidad_por_estab",
                  "pct_subregistro_estab_mes", "mediana_meses_con_registro"),
    valor = c(
      n_estab_total,
      length(estab_part),
      round(100 * length(estab_part) / max(n_estab_total, 1), 1),
      uniqueN(pb$CodigoPrestacion),
      sum(pb$valor_total, na.rm = TRUE),
      total_personas,
      round(sum(pb$valor_total, na.rm = TRUE) / max(length(estab_part), 1), 1),
      round(100 * mean(panel$reporta == 0), 1),
      ifelse(nrow(reg) > 0, as.numeric(median(reg$N)), 0)))
  fwrite(k, file.path(dirb, "kpis.csv"), sep = ";", bom = TRUE)
  k
}

# ---- 3. Cobertura territorial ----------------------------------------------
cobertura_territorial <- function(est, part, blq, dirb) {
  estab_part <- unique(part[bloque == blq]$IdEstablecimiento)
  e <- copy(est)
  e[, participa := IdEstablecimiento %in% estab_part]
  cob <- function(by_col) e[!is.na(get(by_col)),
    .(n_total = .N, n_participa = sum(participa),
      pct = round(100 * mean(participa), 1)), by = by_col]
  fwrite(cob("IdRegion")[order(IdRegion)],
         file.path(dirb, "cobertura_region.csv"), sep = ";", bom = TRUE)
  fwrite(cob("ComunaGlosa")[order(-pct)],
         file.path(dirb, "cobertura_comuna.csv"), sep = ";", bom = TRUE)
  fwrite(cob("tipo_grp")[order(-pct)],
         file.path(dirb, "cobertura_tipo.csv"), sep = ";", bom = TRUE)
  fwrite(cob("DependenciaAdministrativa")[order(-pct)],
         file.path(dirb, "cobertura_dependencia.csv"), sep = ";", bom = TRUE)
  invisible(TRUE)
}

# ---- 4. Serie temporal mensual (por subsección) ----------------------------
serie_temporal <- function(part, blq, dirb) {
  pb <- part[bloque == blq]
  s <- pb[, .(eventos = sum(valor_total, na.rm = TRUE),
              estab_que_reportan = uniqueN(IdEstablecimiento)),
          by = .(Mes, seccion_key)][order(seccion_key, Mes)]
  fwrite(s, file.path(dirb, "serie_mensual.csv"), sep = ";", bom = TRUE)
  invisible(s)
}

# ---- 5. Equidad: sexo / género / migración / pueblos / PRAIS ---------------
equidad_bloque <- function(largo, blq, dirb) {
  lb <- largo[bloque == blq]
  total_personas <- lb[dimension == "total" &
                       grepl("ambos sexos", etiqueta, ignore.case = TRUE),
                       sum(valor, na.rm = TRUE)]
  total_personas <- max(total_personas, 1)

  # Sexo (unificando Masculino->Hombres, Femenina->Mujeres).
  sexo <- lb[dimension == "sexo", .(personas = sum(valor, na.rm = TRUE)), by = etiqueta]
  sexo[etiqueta == "Masculino", etiqueta := "Hombres"]
  sexo[etiqueta == "Femenina",  etiqueta := "Mujeres"]
  sexo <- sexo[etiqueta %in% c("Hombres", "Mujeres"),
               .(personas = sum(personas)), by = etiqueta]
  fwrite(sexo[order(-personas)], file.path(dirb, "equidad_sexo.csv"),
         sep = ";", bom = TRUE)

  # Identidad de género.
  gen <- lb[dimension == "identidad_genero",
            .(personas = sum(valor, na.rm = TRUE)), by = etiqueta][order(-personas)]
  fwrite(gen, file.path(dirb, "equidad_genero.csv"), sep = ";", bom = TRUE)

  # Grupos prioritarios (sólo bloque A: NNA, gestantes).
  grp <- lb[dimension == "grupo_prioritario",
            .(personas = sum(valor, na.rm = TRUE)), by = etiqueta][order(-personas)]
  if (nrow(grp) > 0)
    fwrite(grp, file.path(dirb, "equidad_grupos.csv"), sep = ";", bom = TRUE)

  # KPIs de inclusión.
  g <- function(dim) lb[dimension == dim, sum(valor, na.rm = TRUE)]
  hb <- sexo[etiqueta == "Hombres", sum(personas)]
  mj <- sexo[etiqueta == "Mujeres", sum(personas)]
  base_sexo <- max(hb + mj, 1)
  eq <- data.table(
    indicador = c("total_personas", "pct_hombres", "pct_mujeres", "brecha_genero_pp",
                  "pct_pueblos_originarios", "pct_migrantes", "pct_prais"),
    valor = c(total_personas,
              round(100 * hb / base_sexo, 1),
              round(100 * mj / base_sexo, 1),
              round(100 * (mj - hb) / base_sexo, 1),
              round(100 * g("pueblos_originarios") / total_personas, 1),
              round(100 * g("migrantes") / total_personas, 1),
              round(100 * g("prais") / total_personas, 1)))
  fwrite(eq, file.path(dirb, "equidad_kpis.csv"), sep = ";", bom = TRUE)

  # Equidad por región (migrantes y pueblos originarios).
  po  <- lb[dimension == "pueblos_originarios", .(pueblos_originarios = sum(valor)), by = IdRegion]
  mig <- lb[dimension == "migrantes", .(migrantes = sum(valor)), by = IdRegion]
  per <- lb[dimension == "total" & grepl("ambos sexos", etiqueta, ignore.case = TRUE),
            .(personas = sum(valor)), by = IdRegion]
  eqr <- Reduce(function(a, b) merge(a, b, by = "IdRegion", all = TRUE),
                list(po, mig, per))
  for (j in names(eqr)) set(eqr, which(is.na(eqr[[j]])), j, 0)
  eqr[, pct_pueblos_originarios := round(100 * pueblos_originarios / pmax(personas, 1), 1)]
  eqr[, pct_migrantes := round(100 * migrantes / pmax(personas, 1), 1)]
  fwrite(eqr[order(-pct_migrantes)], file.path(dirb, "equidad_region.csv"),
         sep = ";", bom = TRUE)
  invisible(eq)
}

# ---- 6. Subsecciones propias de cada bloque --------------------------------
# A  -> motivos de reclamo (familias) + gestión de plazos.
# B  -> B.1 instancias  +  B.2 líneas de acción (prestaciones).
# C  -> C.1 líneas de satisfacción  +  C.2 líneas de acción (prestaciones).
familia_reclamo <- function(desc) {
  d <- tolower(desc)
  fcase(
    grepl("^trato", d), "Trato",
    grepl("competencia t|eventos adversos", d), "Competencia/Seguridad",
    grepl("infraestructura|acompañamiento", d), "Infraestructura",
    grepl("tiempo de espera", d), "Tiempos de espera",
    grepl("informaci", d), "Información",
    grepl("procedimientos administrativos", d), "Proc. administrativos",
    grepl("probidad|incumplimiento|garant|vulneraci|violencia|ley", d), "Garantías/Probidad/Derechos",
    grepl("consulta", d), "Consultas",
    grepl("sugerencia", d), "Sugerencias",
    grepl("felicitacion", d), "Felicitaciones",
    grepl("solicitud", d), "Solicitudes",
    default = "Otros")
}

# Cobertura/intensidad por instancia a partir de una tabla larga ya filtrada.
.instancias_intensidad <- function(lg, n_estab_total) {
  inst <- lg[dimension == "instancia",
             .(actividades = sum(valor, na.rm = TRUE),
               n_estab = uniqueN(IdEstablecimiento[!is.na(valor) & valor > 0])),
             by = etiqueta]
  inst[, intensidad := round(actividades / pmax(n_estab, 1), 1)]
  inst[, cobertura := round(100 * n_estab / max(n_estab_total, 1), 1)]
  setorder(inst, -actividades)
  inst
}

subsecciones_bloque <- function(largo, part, blq, dirb) {
  n_estab_total <- uniqueN(part[bloque == blq]$IdEstablecimiento)
  if (blq == "A") {
    pb <- part[bloque == "A"]
    fam <- pb[, .(eventos = sum(valor_total, na.rm = TRUE),
                  n_estab = uniqueN(IdEstablecimiento[valor_total > 0])),
              by = .(familia = familia_reclamo(descripcion))][order(-eventos)]
    fwrite(fam, file.path(dirb, "sub_motivos_reclamo.csv"), sep = ";", bom = TRUE)
    gest <- largo[bloque == "A" & dimension == "reclamo_gestion",
                  .(total = sum(valor, na.rm = TRUE)), by = etiqueta][order(-total)]
    fwrite(gest, file.path(dirb, "sub_gestion_reclamos.csv"), sep = ";", bom = TRUE)

  } else if (blq == "B") {
    inst <- .instancias_intensidad(largo[seccion_key == "B.1"], n_estab_total)
    fwrite(inst, file.path(dirb, "sub_b1_instancias.csv"), sep = ";", bom = TRUE)
    lineas <- part[seccion_key == "B.2",
                   .(sesiones = sum(valor_total, na.rm = TRUE),
                     n_estab = uniqueN(IdEstablecimiento[valor_total > 0])),
                   by = .(linea = descripcion)][order(-sesiones)]
    fwrite(lineas, file.path(dirb, "sub_b2_lineas_accion.csv"), sep = ";", bom = TRUE)

  } else if (blq == "C") {
    lineas_sat <- largo[seccion_key == "C.1" &
                        dimension %in% c("linea_satisfaccion", "instancia"),
                        .(total = sum(valor, na.rm = TRUE)), by = etiqueta][order(-total)]
    fwrite(lineas_sat, file.path(dirb, "sub_c1_lineas_satisfaccion.csv"),
           sep = ";", bom = TRUE)
    lineas <- part[seccion_key == "C.2",
                   .(sesiones = sum(valor_total, na.rm = TRUE),
                     n_estab = uniqueN(IdEstablecimiento[valor_total > 0])),
                   by = .(linea = descripcion)][order(-sesiones)]
    fwrite(lineas, file.path(dirb, "sub_c2_lineas_accion.csv"), sep = ";", bom = TRUE)
  }
  invisible(TRUE)
}

# ---- 7. Hurdle mixto: barrera (glmer) + intensidad (lmer) -------------------
modelo_hurdle <- function(panel, blq, dirb) {
  d <- copy(panel)[!is.na(tipo_grp)]
  if (d[, sum(reporta)] < 30 || d[reporta == 1, uniqueN(IdEstablecimiento)] < 20) {
    .estado(dirb, "hurdle", "omitido", "muy pocos positivos para estimar")
    return(invisible(FALSE))
  }
  d[, `:=`(IdRegion = factor(IdRegion), Mes = factor(Mes, levels = 1:12),
           tipo_grp = .factor_tipo(tipo_grp),
           IdEstablecimiento = factor(IdEstablecimiento))]

  m_b <- tryCatch(
    glmer(reporta ~ IdRegion + tipo_grp + Mes + (1 | IdEstablecimiento),
          family = binomial, data = d,
          control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))),
    error = function(e) { .estado(dirb, "hurdle_barrera", "error", conditionMessage(e)); NULL })

  pos <- d[valor > 0]; pos[, log_valor := log(valor)]
  m_i <- tryCatch(
    lmer(log_valor ~ IdRegion + tipo_grp + Mes + (1 | IdEstablecimiento), data = pos),
    error = function(e) { .estado(dirb, "hurdle_intensidad", "error", conditionMessage(e)); NULL })

  if (is.null(m_b)) return(invisible(FALSE))
  vb <- as.numeric(VarCorr(m_b)$IdEstablecimiento); icc_b <- vb / (vb + pi^2 / 3)
  icc_i <- NA_real_
  if (!is.null(m_i)) {
    vci <- as.data.frame(VarCorr(m_i))
    icc_i <- vci[vci$grp == "IdEstablecimiento", "vcov"] /
      (vci[vci$grp == "IdEstablecimiento", "vcov"] + vci[vci$grp == "Residual", "vcov"])
  }
  fwrite(data.table(indicador = c("icc_barrera_pct", "icc_intensidad_pct"),
                    valor = round(100 * c(icc_b, icc_i), 1)),
         file.path(dirb, "modelo_icc.csv"), sep = ";", bom = TRUE)
  d[, p := predict(m_b, newdata = d, re.form = NA, type = "response")]
  fwrite(d[, .(prob_registra = round(mean(p), 3)), by = IdRegion][order(-prob_registra)],
         file.path(dirb, "modelo_region.csv"), sep = ";", bom = TRUE)
  fwrite(d[, .(prob_registra = round(mean(p), 3)), by = tipo_grp][order(-prob_registra)],
         file.path(dirb, "modelo_tipo.csv"), sep = ";", bom = TRUE)
  if ("nivel_atencion" %in% names(d))
    fwrite(d[, .(prob_registra = round(mean(p), 3)), by = nivel_atencion][order(-prob_registra)],
           file.path(dirb, "modelo_nivel.csv"), sep = ";", bom = TRUE)
  mmes <- d[, .(prob_registra = round(mean(p), 3)), by = Mes]
  mmes[, Mes := as.integer(as.character(Mes))]
  fwrite(mmes[order(Mes)], file.path(dirb, "modelo_estacionalidad.csv"), sep = ";", bom = TRUE)
  .estado(dirb, "hurdle", "ok",
          sprintf("ICC barrera %.1f%% / intensidad %.1f%%", 100 * icc_b, 100 * icc_i))
  invisible(TRUE)
}

# ---- 8. Multinivel 3 niveles (región/comuna/establecimiento) + pobreza -----
modelo_multinivel <- function(panel, com, est, part, blq, dirb) {
  d <- merge(panel, com[, .(IdComuna, pct_pobreza)], by = "IdComuna",
             all.x = TRUE, sort = FALSE)
  d <- d[!is.na(pct_pobreza) & !is.na(tipo_grp)]
  if (d[, sum(reporta)] < 30) {
    .estado(dirb, "multinivel", "omitido", "muy pocos positivos")
    return(invisible(FALSE))
  }
  d[, `:=`(pobreza10 = pct_pobreza / 10, Mes = factor(Mes, levels = 1:12),
           tipo_grp = .factor_tipo(tipo_grp),
           IdRegion = factor(IdRegion), IdComuna = factor(IdComuna),
           IdEstablecimiento = factor(IdEstablecimiento))]

  m <- tryCatch(
    glmer(reporta ~ tipo_grp + pobreza10 + Mes +
            (1 | IdRegion / IdComuna / IdEstablecimiento),
          family = binomial, data = d,
          control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 3e5))),
    error = function(e) { .estado(dirb, "multinivel", "error", conditionMessage(e)); NULL })
  if (is.null(m)) return(invisible(FALSE))

  vc <- as.data.frame(VarCorr(m))
  v_est <- sum(vc$vcov[grepl("IdEstablecimiento", vc$grp)])
  v_com <- sum(vc$vcov[grepl("IdComuna", vc$grp) & !grepl("IdEstablecimiento", vc$grp)])
  v_reg <- sum(vc$vcov[vc$grp == "IdRegion"])
  v_res <- pi^2 / 3
  tot <- v_est + v_com + v_reg + v_res
  fwrite(data.table(nivel = c("Establecimiento", "Comuna", "Región", "Residual (mes a mes)"),
                    pct_varianza = round(100 * c(v_est, v_com, v_reg, v_res) / tot, 1)),
         file.path(dirb, "modelo_multinivel_var.csv"), sep = ";", bom = TRUE)

  co <- summary(m)$coefficients
  if ("pobreza10" %in% rownames(co)) {
    or <- exp(co["pobreza10", "Estimate"])
    lo <- exp(co["pobreza10", "Estimate"] - 1.96 * co["pobreza10", "Std. Error"])
    hi <- exp(co["pobreza10", "Estimate"] + 1.96 * co["pobreza10", "Std. Error"])
    fwrite(data.table(indicador = c("OR_pobreza_x10pp", "IC95_inferior",
                                    "IC95_superior", "p_valor"),
                      valor = round(c(or, lo, hi, co["pobreza10", "Pr(>|z|)"]), 4)),
           file.path(dirb, "modelo_determinantes.csv"), sep = ";", bom = TRUE)
  }

  # --- Sensibilidad: universo participativo (excluye urgencias estructurales) ---
  # Responde "¿cambia la pobreza/territorio al quitar los ceros estructurales?".
  d2 <- droplevels(d[participa_estructural == TRUE])
  if (nrow(d2) > 0 && sum(d2$reporta) >= 30) {
    m2 <- tryCatch(
      glmer(reporta ~ tipo_grp + pobreza10 + Mes +
              (1 | IdRegion / IdComuna / IdEstablecimiento),
            family = binomial, data = d2,
            control = glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 3e5))),
      error = function(e) { .estado(dirb, "multinivel_part", "error", conditionMessage(e)); NULL })
    if (!is.null(m2)) {
      vc2 <- as.data.frame(VarCorr(m2))
      ve2 <- sum(vc2$vcov[grepl("IdEstablecimiento", vc2$grp)])
      vco2 <- sum(vc2$vcov[grepl("IdComuna", vc2$grp) & !grepl("IdEstablecimiento", vc2$grp)])
      vr2 <- sum(vc2$vcov[vc2$grp == "IdRegion"]); vres2 <- pi^2 / 3
      tot2 <- ve2 + vco2 + vr2 + vres2
      fwrite(data.table(nivel = c("Establecimiento", "Comuna", "Región", "Residual (mes a mes)"),
                        pct_varianza = round(100 * c(ve2, vco2, vr2, vres2) / tot2, 1)),
             file.path(dirb, "modelo_multinivel_var_part.csv"), sep = ";", bom = TRUE)
      co2 <- summary(m2)$coefficients
      if ("pobreza10" %in% rownames(co2)) {
        or2 <- exp(co2["pobreza10", "Estimate"])
        lo2 <- exp(co2["pobreza10", "Estimate"] - 1.96 * co2["pobreza10", "Std. Error"])
        hi2 <- exp(co2["pobreza10", "Estimate"] + 1.96 * co2["pobreza10", "Std. Error"])
        fwrite(data.table(indicador = c("OR_pobreza_x10pp", "IC95_inferior",
                                        "IC95_superior", "p_valor"),
                          valor = round(c(or2, lo2, hi2, co2["pobreza10", "Pr(>|z|)"]), 4)),
               file.path(dirb, "modelo_determinantes_part.csv"), sep = ";", bom = TRUE)
      }
      .estado(dirb, "multinivel_part", "ok",
              sprintf("universo participativo (n=%d estab): var estab %.1f%% comuna %.1f%%",
                      d2[, uniqueN(IdEstablecimiento)], 100 * ve2 / tot2, 100 * vco2 / tot2))
    }
  }

  # Cobertura comunal vs pobreza (insumo del mapa y del espacial).
  estab_part <- unique(part[bloque == blq]$IdEstablecimiento)
  e <- copy(est); e[, participa := IdEstablecimiento %in% estab_part]
  cob_com <- e[, .(cobertura = round(100 * mean(participa), 1), n = .N), by = IdComuna]
  cob_com <- merge(cob_com, com[, .(IdComuna, comuna, pct_pobreza, poblacion)],
                   by = "IdComuna")
  fwrite(cob_com, file.path(dirb, "cobertura_vs_pobreza.csv"), sep = ";", bom = TRUE)
  .estado(dirb, "multinivel", "ok",
          sprintf("var estab %.1f%% comuna %.1f%% region %.1f%%",
                  100 * v_est / tot, 100 * v_com / tot, 100 * v_reg / tot))
  invisible(TRUE)
}

# ---- 9. Autocorrelación espacial: I de Moran + LISA ------------------------
espacial_bloque <- function(blq, dirb) {
  pkgs <- c("sf", "spdep", "chilemapas")
  if (!all(vapply(pkgs, requireNamespace, logical(1), quietly = TRUE))) {
    .estado(dirb, "espacial", "omitido", "faltan paquetes sf/spdep/chilemapas")
    return(invisible(FALSE))
  }
  f_cob <- file.path(dirb, "cobertura_vs_pobreza.csv")
  if (!file.exists(f_cob)) {
    .estado(dirb, "espacial", "omitido", "falta cobertura_vs_pobreza.csv")
    return(invisible(FALSE))
  }
  suppressPackageStartupMessages({ library(sf); library(spdep) })
  cob <- fread(f_cob, sep = ";"); cob[, codigo_comuna := sprintf("%05d", IdComuna)]
  mapa <- sf::st_as_sf(chilemapas::mapa_comunas)
  mapa <- merge(mapa, cob[, .(codigo_comuna, cobertura)], by = "codigo_comuna", all.x = TRUE)
  mapa <- mapa[!is.na(mapa$cobertura), ]
  if (nrow(mapa) < 10) {
    .estado(dirb, "espacial", "omitido", "muy pocas comunas con dato")
    return(invisible(FALSE))
  }
  res <- tryCatch({
    nb <- spdep::poly2nb(mapa, queen = TRUE)
    lw <- spdep::nb2listw(nb, style = "W", zero.policy = TRUE)
    mi <- spdep::moran.test(mapa$cobertura, lw, zero.policy = TRUE, na.action = na.omit)
    fwrite(data.table(indicador = c("I_Moran", "valor_esperado", "p_valor"),
      valor = round(c(mi$estimate[["Moran I statistic"]],
                      mi$estimate[["Expectation"]], mi$p.value), 4)),
      file.path(dirb, "moran_global.csv"), sep = ";", bom = TRUE)
    lm <- spdep::localmoran(mapa$cobertura, lw, zero.policy = TRUE)
    z <- scale(mapa$cobertura)[, 1]; lagz <- spdep::lag.listw(lw, z, zero.policy = TRUE)
    p <- lm[, "Pr(z != E(Ii))"]
    cl <- fifelse(p >= 0.05, "No significativo",
          fifelse(z > 0 & lagz > 0, "Alto-Alto (foco de participación)",
          fifelse(z < 0 & lagz < 0, "Bajo-Bajo (foco de subregistro)",
          fifelse(z > 0 & lagz < 0, "Alto-Bajo (atípico)", "Bajo-Alto (atípico)"))))
    fwrite(data.table(codigo_comuna = mapa$codigo_comuna, cobertura = mapa$cobertura,
                      lisa_cluster = cl), file.path(dirb, "lisa_comuna.csv"),
           sep = ";", bom = TRUE)
    .estado(dirb, "espacial", "ok",
            sprintf("I=%.3f p=%.3f", mi$estimate[["Moran I statistic"]], mi$p.value))
    TRUE
  }, error = function(e) { .estado(dirb, "espacial", "error", conditionMessage(e)); FALSE })
  invisible(res)
}

# ---- 10. Tipologías k-means (composición interna del bloque) ---------------
# Agrupa establecimientos por la COMPOSICIÓN de su actividad dentro del bloque:
#   A -> familias de reclamo · B -> instancias (B.1) · C -> líneas (C.1).
tipologias_bloque <- function(part, largo, est, blq, dirb, k = 4) {
  comp <- NULL
  if (blq == "A") {
    pb <- part[bloque == "A" & valor_total > 0]
    comp <- pb[, .(v = sum(valor_total, na.rm = TRUE)),
               by = .(IdEstablecimiento, cat = familia_reclamo(descripcion))]
  } else if (blq == "B") {
    lg <- largo[seccion_key == "B.1" & dimension == "instancia" & valor > 0]
    comp <- lg[, .(v = sum(valor, na.rm = TRUE)), by = .(IdEstablecimiento, cat = etiqueta)]
  } else if (blq == "C") {
    lg <- largo[seccion_key == "C.1" &
                dimension %in% c("linea_satisfaccion", "instancia") & valor > 0]
    comp <- lg[, .(v = sum(valor, na.rm = TRUE)), by = .(IdEstablecimiento, cat = etiqueta)]
  }
  if (is.null(comp) || comp[, uniqueN(IdEstablecimiento)] < (k * 5) ||
      comp[, uniqueN(cat)] < 2) {
    .estado(dirb, "tipologias", "omitido", "datos insuficientes para k-means")
    return(invisible(FALSE))
  }
  w <- dcast(comp, IdEstablecimiento ~ cat, value.var = "v", fill = 0)
  cats <- setdiff(names(w), "IdEstablecimiento")
  M <- as.matrix(w[, ..cats]); M <- M / pmax(rowSums(M), 1)   # shares por establecimiento
  S <- as.data.table(M); S[, IdEstablecimiento := w$IdEstablecimiento]
  res <- tryCatch({
    Z <- scale(M); Z[is.nan(Z)] <- 0
    set.seed(123)
    km <- kmeans(Z, centers = k, nstart = 25)
    S[, perfil := km$cluster]
    perfil <- S[, c(list(n_establecimientos = .N),
                    lapply(.SD, function(x) round(100 * mean(x), 1))),
                by = perfil, .SDcols = cats][order(perfil)]
    fwrite(perfil, file.path(dirb, "tipologias_perfil.csv"), sep = ";", bom = TRUE)
    asign <- merge(S[, .(IdEstablecimiento, perfil)],
                   est[, .(IdEstablecimiento, TipoEstablecimientoGlosa, IdRegion)],
                   by = "IdEstablecimiento", all.x = TRUE)
    fwrite(asign, file.path(dirb, "tipologias_asignacion.csv"), sep = ";", bom = TRUE)
    .estado(dirb, "tipologias", "ok", sprintf("k=%d sobre %d establecimientos", k, nrow(w)))
    TRUE
  }, error = function(e) { .estado(dirb, "tipologias", "error", conditionMessage(e)); FALSE })
  invisible(res)
}
