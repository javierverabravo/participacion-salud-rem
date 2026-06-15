# Licencias del proyecto

Este proyecto tiene varias capas y cada una se licencia por separado. Asi otra
persona sabe exactamente que puede reutilizar y bajo que condiciones.

## 1. Codigo (licencia MIT)

Todo el codigo del proyecto (scripts de `R/`, configuracion de Quarto,
`custom.scss`, codigo del dashboard `index.qmd` y del informe `articulo.qmd`)
se publica bajo la **Licencia MIT**. El texto completo esta en el archivo
`LICENSE`. En resumen: cualquiera puede usar, copiar, modificar y redistribuir
el codigo, incluso con fines comerciales, siempre que conserve el aviso de
copyright y la nota de licencia.

## 2. Productos derivados, textos y figuras (CC BY 4.0)

Las tablas de resultados (`productos/`), las figuras, el sitio renderizado
(`docs/`) y los documentos de texto (README, articulo, resumen ejecutivo y
demas `.md`) se publican bajo **Creative Commons Atribucion 4.0 Internacional
(CC BY 4.0)**: https://creativecommons.org/licenses/by/4.0/deed.es

Puedes compartir y adaptar este material, incluso con fines comerciales,
siempre que des credito al autor. Atribucion sugerida:

> Javier Vera Bravo (2026). Participacion Ciudadana en Salud, analisis del
> REM-A19b. https://github.com/javierverabravo/participacion-salud-rem

## 3. Datos de origen (no se redistribuyen aqui)

Este repositorio **no incluye los datos crudos**: estan en `.gitignore` y se
descargan desde su fuente oficial al correr el pipeline. Por lo tanto, las
licencias de los datos de origen son las de cada portal, no las de este
proyecto. Las fuentes son portales de datos abiertos del Estado de Chile:

- **REM** (Resumenes Estadisticos Mensuales). Departamento de Estadisticas e
  Informacion de Salud (DEIS), Ministerio de Salud. Portal: https://deis.minsal.cl/
  (seccion Datos Abiertos). Descarga directa por ano desde el repositorio,
  por ejemplo https://repositoriodeis.minsal.cl/DatosAbiertos/REM/SERIE_REM_2025.zip
  (y `SERIE_REM_2026.zip` para los datos preliminares 2026).

- **CASEN comunal** (pobreza por ingresos y multidimensional). Observatorio
  Social, Ministerio de Desarrollo Social y Familia. Encuesta CASEN 2024.
  Portal: https://observatorio.ministeriodesarrollosocial.gob.cl/
  El pipeline usa las estimaciones de pobreza comunal por areas pequenas (SAE)
  de CASEN 2024 (archivos `SAE_ingresos_2024.xlsx` y `SAE_multidimensional_2024.xlsx`),
  no la microdata de la encuesta.

- **Base maestra de establecimientos** (tipo, dependencia, nivel, coordenadas).
  Portal de datos abiertos del Estado: https://datos.gob.cl/ (conjunto
  "Establecimientos de Salud vigentes").

- **FONASA** (poblacion beneficiaria por comuna, denominador per capita). Fondo
  Nacional de Salud, portal de datos abiertos: https://datosabiertos.fonasa.cl/dimensiones-beneficiarios/
  (tablero "Poblacion Beneficiaria"). El archivo usado es `Beneficiarios 2025.csv`
  (beneficiarios a diciembre 2025). El portal es interactivo y no expone una URL
  de descarga directa estable, por eso el archivo se coloca manualmente en la carpeta.

Estos portales publican sus datos como datos abiertos, en general bajo
licencias Creative Commons (por ejemplo, el INE usa CC BY-SA 4.0). Para
reutilizar los datos crudos, revisa y respeta los terminos del portal de
origen correspondiente. Las cifras y productos derivados de este proyecto se
licencian segun la seccion 2; los datos originales conservan su propia licencia.

## Resumen

| Capa | Que incluye | Licencia |
|---|---|---|
| Codigo | scripts R, configuracion, codigo del dashboard | MIT |
| Productos y textos | productos/, docs/, figuras, documentos .md | CC BY 4.0 |
| Datos de origen | REM, CASEN, FONASA, establecimientos (no redistribuidos) | Terminos del portal de origen |
