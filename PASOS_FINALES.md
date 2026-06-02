# Pasos finales para la reunión — orden de ejecución

Hazlos en este orden en tu terminal (Git Bash recomendado; abajo va también la
variante PowerShell). La carpeta del proyecto es la raíz del repo.

## 1. Arreglar el índice de git (está corrupto)

El índice se corrompió (artefacto del disco montado). Esto **no** toca tus commits
ni tus archivos: solo reconstruye el índice desde el último commit.

**Git Bash:**
```bash
cd "/e/PROYECTO PARTICIPACIÓN CIUDADANA EN SALUD"
rm -f .git/index
git reset
git status
```

**PowerShell / CMD:**
```powershell
cd "E:\PROYECTO PARTICIPACIÓN CIUDADANA EN SALUD"
del .git\index
git reset
git status
```

`git status` debe volver a funcionar y mostrar `index.qmd` y `PROYECTO.md`
modificados, y `RESUMEN_EJECUTIVO.md` como nuevo.

## 2. Borrar archivos temporales y obsoletos

Yo no pude borrarlos desde mi entorno (el disco montado lo impide).

**Git Bash:**
```bash
rm -f R/_probe.txt _idx_clean.qmd _testwrite.txt
# (opcional) archivar los productos planos de la versión global anterior:
mkdir -p _archivo_pipeline_global
mv productos/*.csv _archivo_pipeline_global/ 2>/dev/null
[ -d salidas ] && mv salidas _archivo_pipeline_global/
```

**PowerShell:**
```powershell
Remove-Item R\_probe.txt, _idx_clean.qmd, _testwrite.txt -ErrorAction SilentlyContinue
```

(Los `productos/` y `salidas/` están en `.gitignore`, así que no afectan a GitHub;
moverlos es solo orden local.)

## 3. Generar el dashboard nuevo

En la **consola de R** (si aún no corriste el pipeline en esta versión):
```r
source("R/99_run_all.R")   # ~70 min; deja productos/{A,B,C,sintesis}/
```

En la **terminal**:
```bash
quarto render
```
Revisa que `docs/index.html` abra bien: pestañas **Resumen · A · B · C · Síntesis ·
Metodología · Glosario**, cada una con sus KPIs y gráficos. Para el render local
necesitas además los paquetes `ggplot2`, `plotly`, `DT`, `bslib` (instálalos si faltan).

## 4. Subir todo a GitHub

```bash
git add -A
git commit -m "Dashboard por bloques A/B/C/síntesis; resumen ejecutivo; PROYECTO.md completo"
git push
```

GitHub Pages se actualizará solo desde `docs/`. El workflow mensual de Actions ya
quedará apuntando a la estructura correcta.

## Checklist antes de presentar

- [ ] `git status` limpio y `git push` sin errores.
- [ ] Dashboard renderizado abre con las 7 pestañas y sin chunks en rojo.
- [ ] `RESUMEN_EJECUTIVO.md` a mano para mostrar las conclusiones.
- [ ] Sitio en vivo: https://arleq89.github.io/participacion-salud-rem/
