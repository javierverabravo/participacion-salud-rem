# =============================================================================
# 11_ml.R  .  Machine learning COMPLEMENTARIO (predictivo, no causal)
# -----------------------------------------------------------------------------
# Para cada bloque (A, B, C) entrena un gradient boosting (xgboost) que predice
# si un ESTABLECIMIENTO registra la seccion a partir de sus CARACTERISTICAS
# (tipo, nivel, dependencia, Servicio de Salud, region, pobreza comunal,
# poblacion), SIN usar su identidad. Esto:
#   - mapea importancia NO lineal e interacciones (SHAP nativo de xgboost),
#     triangulando el hallazgo del multinivel desde otro metodo;
#   - produce un SCORE DE RIESGO de subregistro por establecimiento (focalizacion).
# Es un complemento del nucleo inferencial (hurdle/multinivel), no un reemplazo.
# La unidad es el establecimiento (una fila por centro), asi que la validacion
# cruzada es k-fold estandar sin fuga por establecimiento.
# Salidas en productos/ml/. Degrada con elegancia si falta xgboost.
# Compatible con xgboost >= 1.5 y con xgboost >= 3.x (la API cambio: ahora
# best_iteration vive dentro de cv$early_stop, no en la raiz del objeto cv).
# =============================================================================
suppressPackageStartupMessages({ library(here); library(data.table) })
source(here("R", "04_engine.R"))

anio <- as.integer(Sys.getenv("REM_ANIO", unset = "2025"))
dirm <- here("productos", "ml"); dir.create(dirm, recursive = TRUE, showWarnings = FALSE)
message("\n==== MACHINE LEARNING (xgboost + SHAP) ====")

# Helpers compatibles con varias versiones de xgboost ---------------------------
.best_iter <- function(cv) {
  bi <- cv$best_iteration
  if (is.null(bi) && !is.null(cv$early_stop)) bi <- cv$early_stop$best_iteration
  if (is.null(bi)) bi <- nrow(cv$evaluation_log)
  as.integer(bi)
}
.auc_cv <- function(cv, best) {
  ev <- as.data.table(cv$evaluation_log)
  col <- grep("^test.*auc.*mean$", names(ev), value = TRUE, ignore.case = TRUE)[1]
  if (is.na(col)) col <- grep("test.*mean", names(ev), value = TRUE, ignore.case = TRUE)[1]
  if (is.na(col)) return(NA_real_)
  as.numeric(ev[[col]][best])
}

if (!requireNamespace("xgboost", quietly = TRUE)) {
  fwrite(data.table(aviso = "Etapa ML omitida: instala xgboost con install.packages('xgboost')"),
         file.path(dirm, "ml_estado.csv"), sep = ";", bom = TRUE)
  message("  xgboost no instalado; etapa ML omitida (no bloquea el pipeline).")
} else {
  part <- readRDS(here("datos", as.character(anio), "participacion_A19b.rds")); setDT(part)
  est  <- tipo_agrupado(setDT(readRDS(here("datos", "establecimientos_lookup.rds"))))
  com  <- readRDS(here("datos", "externos", "comunal.rds")); setDT(com)
  est  <- merge(est, com[, .(IdComuna, pct_pobreza, poblacion)], by = "IdComuna", all.x = TRUE)

  feats <- c("tipo_grp", "nivel_atencion", "dependencia", "servicio_salud",
             "IdRegion", "pct_pobreza", "poblacion")
  cats  <- c("tipo_grp", "nivel_atencion", "dependencia", "servicio_salud", "IdRegion")

  prep_X <- function(d) {
    falt <- setdiff(feats, names(d))
    if (length(falt))
      stop(sprintf("faltan columnas en establecimientos: %s", paste(falt, collapse = ", ")))
    X <- d[, ..feats]
    for (cc in intersect(cats, names(X))) {
      v <- as.character(X[[cc]]); v[is.na(v) | v == ""] <- "Sin dato"
      X[[cc]] <- as.factor(v)
    }
    for (nc in c("pct_pobreza", "poblacion"))
      if (nc %in% names(X)) X[[nc]][is.na(X[[nc]])] <- stats::median(X[[nc]], na.rm = TRUE)
    stats::model.matrix(~ . - 1, data = X)
  }

  for (blq in c("A", "B", "C")) {
    estab_part <- unique(part[bloque == blq]$IdEstablecimiento)
    d <- copy(est)[!is.na(tipo_grp)]
    d[, participa := as.integer(IdEstablecimiento %in% estab_part)]
    paso <- "(inicio)"
    res <- tryCatch({
      paso <- "prep_X";    mm <- prep_X(d); y <- d$participa
      paso <- "DMatrix";   set.seed(123)
      dtrain <- xgboost::xgb.DMatrix(mm, label = y)
      par <- list(objective = "binary:logistic", eval_metric = "auc",
                  max_depth = 4, eta = 0.08, subsample = 0.8, colsample_bytree = 0.8)
      paso <- "xgb.cv"
      cv <- xgboost::xgb.cv(params = par, data = dtrain, nrounds = 400, nfold = 5,
                            early_stopping_rounds = 25, verbose = 0)
      paso <- "best_iter"; best <- .best_iter(cv)
      paso <- "auc_cv";    auc  <- .auc_cv(cv, best)
      paso <- "xgb.train"
      mdl  <- xgboost::xgb.train(params = par, data = dtrain, nrounds = best, verbose = 0)

      paso <- "importance"
      imp <- xgboost::xgb.importance(model = mdl)
      fwrite(imp, file.path(dirm, sprintf("importancia_%s.csv", blq)), sep = ";", bom = TRUE)

      paso <- "shap"
      sh <- predict(mdl, mm, predcontrib = TRUE)
      if (!is.null(colnames(sh)))
        sh <- sh[, setdiff(colnames(sh), c("BIAS", "(Intercept)")), drop = FALSE]
      feats_sh <- if (!is.null(colnames(sh))) colnames(sh) else paste0("f", seq_len(ncol(sh)))
      shm <- data.table(feature = feats_sh,
                        shap_abs_medio = round(colMeans(abs(sh)), 4))[order(-shap_abs_medio)]
      fwrite(shm, file.path(dirm, sprintf("shap_%s.csv", blq)), sep = ";", bom = TRUE)

      paso <- "riesgo"
      p <- predict(mdl, mm)
      riesgo <- data.table(
        IdEstablecimiento = d$IdEstablecimiento, tipo = d$tipo_grp,
        IdComuna = d$IdComuna, prob_participa = round(p, 3),
        riesgo_subregistro = round(1 - p, 3),
        participa_real = y)[order(-riesgo_subregistro)]
      fwrite(riesgo, file.path(dirm, sprintf("riesgo_%s.csv", blq)), sep = ";", bom = TRUE)

      fwrite(data.table(bloque = blq, auc_cv = round(auc, 3),
                        nrounds = best, n_establecimientos = nrow(d),
                        pct_participa = round(100 * mean(y), 1)),
             file.path(dirm, sprintf("metrica_%s.csv", blq)), sep = ";", bom = TRUE)
      message(sprintf("  [ML %s] AUC validacion cruzada %.3f (n=%d centros)", blq, auc, nrow(d)))
      TRUE
    }, error = function(e) {
      fwrite(data.table(bloque = blq, paso = paso, error = conditionMessage(e)),
             file.path(dirm, sprintf("ml_estado_%s.csv", blq)), sep = ";", bom = TRUE)
      message("  [ML ", blq, "] error en paso ", paso, ": ", conditionMessage(e))
      FALSE })
  }

  mets <- rbindlist(lapply(c("A", "B", "C"), function(b) {
    f <- file.path(dirm, sprintf("metrica_%s.csv", b))
    if (file.exists(f)) fread(f, sep = ";") else NULL
  }), fill = TRUE)
  if (nrow(mets)) fwrite(mets, file.path(dirm, "ml_metricas.csv"), sep = ";", bom = TRUE)
  message("ML listo. Productos en productos/ml/")
}
