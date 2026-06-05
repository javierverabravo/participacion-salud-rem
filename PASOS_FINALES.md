# Runbook, probar el flujo y publicar

Ejecuta en orden. Terminal de Positron (PowerShell) salvo donde diga consola de R.

## 1. Arreglar el índice de git (está corrupto)

```powershell
Remove-Item .git\index
git reset
git status
```

## 2. Renumerar los scripts a consecutivo (git mv conserva el historial)

El contenido (llamadas `source()`, workflow, docs) ya quedó apuntando a los nombres
nuevos; falta renombrar los archivos. Hazlo en este orden:

```powershell
git mv R/10_engine.R     R/04_engine.R
git mv R/11_indicadores.R R/05_indicadores.R
git mv R/20_analisis_A.R R/06_analisis_A.R
git mv R/21_analisis_B.R R/07_analisis_B.R
git mv R/22_analisis_C.R R/08_analisis_C.R
git mv R/30_sintesis.R   R/09_sintesis.R
git mv R/99_run_all.R    R/10_run_all.R
```

Esquema final: `00`-`03` datos · `04` motor · `05` indicadores · `06/07/08` bloques
A/B/C · `09` síntesis · `10` maestro.

## 3. Limpiar temporales

```powershell
Remove-Item R\_probe.txt, _idx_clean.qmd, _testwrite.txt -ErrorAction SilentlyContinue
```

## 4. Probar el flujo

Humo rápido (que cargue sin error, sin re-correr 70 min) en la **consola de R**:
```r
library(here)
for (f in c("04_engine.R","05_indicadores.R")) source(here("R", f))  # deben cargar sin error
```

Corrida completa (cuando avisemos que el modelo nuevo está listo), en consola de R:
```r
source("R/10_run_all.R")   # ~70 min; regenera productos/{A,B,C,sintesis}/
```

## 5. Renderizar el dashboard

```powershell
quarto render
```
Abre `docs/index.html`: pestañas Resumen · A · B · C · Síntesis · Metodología · Glosario.

## 6. Subir a GitHub

```powershell
git add -A
git commit -m "Renumeración consecutiva de scripts (00-10); refs y docs actualizadas"
git push
```
