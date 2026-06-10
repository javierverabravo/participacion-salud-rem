# Runbook vigente

Pasos habituales del proyecto, en orden. Terminal de Positron salvo donde diga
consola de R.

## 1. Re-correr el pipeline (solo si cambiaron datos o scripts de R/)

En la consola de R, desde la raíz:

```r
source("R/10_run_all.R")   # exacto por defecto, ~60 a 70 min con paralelo
```

Flags opcionales antes del source: `REM_FAST="1"` (rápido ~4 min, solo para
iterar; los ICC salen algo menores), `REM_SENS="0"` (omite sensibilidad),
`REM_PAR="0"` (secuencial), `REM_DEP="1"` (incluye dependencia en la
descomposición).

Sanity check tras una corrida exacta: ICC barrera A ~93,9 / B ~65,8 / C ~74,3
en `productos/{A,B,C}/modelo_icc.csv`.

## 2. Renderizar

```powershell
quarto render                  # dashboard -> docs/
quarto render articulo.qmd     # informe tecnico -> articulo.pdf
```

## 3. Publicar

```powershell
git add -A
git commit -m "mensaje"
git push
```

GitHub Pages sirve `docs/` de la rama main (Settings > Pages > main > /docs;
activarlo una sola vez). El sitio queda en
https://arleq89.github.io/participacion-salud-rem/

## 4. Si el mapa de Territorio falla

```r
source("R/diag_mapa.R")   # imprime PASO a PASO; el ultimo paso indica la falla
```
