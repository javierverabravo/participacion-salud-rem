# Auditoría total del proyecto (junio 2026)

Revisión completa de dashboard, pipeline, productos y documentos. Cada problema
indica su estado: CORREGIDO (ya aplicado en los archivos), RENDER (se ve al
renderizar) o PENDIENTE (requiere una acción tuya).

## 1. Problemas de fondo (datos y cifras)

1. **"Núcleo deliberativo 87,4%" estaba mal calculado.** CRÍTICO. El engine
   divide los 1.331 establecimientos deliberativos por los 1.523 que ya
   registran B, no por la red de 2.982. Por eso el tablero afirmaba que la
   "cobertura real" deliberativa (87,4%) era MAYOR que la cobertura total
   (51,1%), lo que es imposible si el núcleo es un subconjunto. La cifra
   correcta de red es **44,6%**. CORREGIDO en dos capas: el dashboard ahora
   calcula 44,6% desde productos existentes (no requiere re-correr nada), y
   `04_engine.R` quedó parchado para que la próxima corrida escriba ambos
   indicadores con nombres inequívocos.
2. **`sub_b1_clase.csv` reporta 3.921 establecimientos deliberativos**, más que
   toda la red, porque sumaba establecimientos por instancia (un centro con 5
   instancias contaba 5 veces). CORREGIDO en `04_engine.R` (cuenta únicos);
   el CSV en disco se corrige en la próxima corrida del pipeline. El dashboard
   no muestra ese campo, así que no urge.
3. **Tipologías k-means**: dos perfiles compartían la etiqueta "Centrado en
   OIRS / reclamos" (el gráfico duplicaba barras con el mismo nombre), la
   palabra "reclamos" contradice el hallazgo "OIRS no es reclamos", y el texto
   decía que k se eligió "por silueta máxima" cuando la silueta máxima está en
   k=3, no en el k=4 usado. CORREGIDO: etiquetas únicas según composición
   (con n de cada perfil) y texto honesto ("partición exploratoria, silueta
   similar entre k=2 y k=4").
4. **Inconsistencia 2.982 vs 2.983 establecimientos** entre README (2.983) y
   kpis/artículo (2.982). CORREGIDO a 2.982 en README.
5. **Artículo: "35.337 combinaciones esperadas"** era de una versión antigua del
   panel; con 2.982 establecimientos por 12 meses son 35.784. CORREGIDO.

## 2. Dashboard: estructura y responsividad

6. **Mapa de Territorio roto** (error "'type' (list) de argumento no válido").
   Dos causas probables encontradas en el código: (a) las etiquetas usaban
   `mapa$nombre_comuna`, columna que NO existe en `chilemapas::mapa_comunas`
   (los nombres viven en `codigos_territoriales`); (b) merges de objetos sf
   contra data.table, mezcla que a veces despacha mal. CORREGIDO: el chunk se
   reescribió uniendo los nombres de comuna y convirtiendo a data.frame antes
   de cada merge con sf. Además se creó **`R/diag_mapa.R`**: si al renderizar
   el mapa siguiera fallando, córrelo en Positron y dime cuál es el último
   "PASO:" impreso.
7. **Sobrecarga visual**: 9 páginas con 4 a 8 gráficos simultáneos cada una.
   CORREGIDO: reestructurado a 7 páginas (Resumen, Territorio, A, B, C,
   Síntesis que fusiona "Indicadores de gestión" + "Nivel y robustez", y
   "Acerca de" que fusiona Metodología + Glosario). Los gráficos secundarios
   van en pestañas: cada página muestra 2 a 3 visuales a la vez.
8. **Números cortados en value boxes** ("16.805.9 / 09"). CORREGIDO: formato
   compacto ("16,8 M", con el número completo en el subtítulo) y CSS
   `white-space: nowrap`.
9. **Ejes ilegibles en "Composición por sexo e identidad de género"** (el
   facetado con escalas libres encimaba los ticks). CORREGIDO: se separó en
   dos pestañas, "Sexo (binario)" e "Identidades de género diversas", cada una
   con su escala.
10. **Gráficos territoriales facetados (3 secciones x 16 regiones)** ilegibles
    en pantallas chicas. CORREGIDO: una sección por pestaña.
11. **Semáforo regional**: orden de filas por IdRegion antiguo (mezcla
    geográficamente) y una segunda tabla de regiones duplicada dentro del chunk
    con el nombre "Arica" inconsistente. CORREGIDO: tabla única de regiones
    ordenada de norte a sur en todo el tablero.
12. **Móvil**: sidebar ahora limitado a 35vh con scroll, pestañas con scroll
    horizontal, value boxes 2x2, tarjetas compactas, plotly responsivo y sin
    barra de herramientas. RENDER: pruébalo achicando la ventana o desde el
    teléfono cuando publiques.
13. **Código muerto y duplicado en index.qmd**: `plot_mapa_cob` no se usaba;
    `res_aud`/`av()` estaban definidos dos veces; dos tablas de regiones.
    CORREGIDO al reescribir.
14. **Gráfico "¿Región o comuna?"** mostraba solo región vs servicio (dos
    barras casi invisibles) sin el término de comparación relevante.
    CORREGIDO: ahora incluye la comuna, que es donde vive la varianza.

## 3. Documentos

15. **Artículo, contradicción interna**: la Discusión decía que el volumen está
    "dominado por el reclamo (OIRS, 17,4 millones de eventos)" cuando el
    hallazgo central de A es que el grueso son CONSULTAS (los reclamos son 138
    mil). CORREGIDO.
16. **Artículo, citas placeholder**: "[análisis bioético, 2025]" y "[Medwave,
    mortalidad por cáncer de mama en la R.M.]" no existen en las referencias.
    CORREGIDO (eliminadas; si quieres citar el estudio de Medwave hay que
    buscar la referencia completa y verificarla).
17. **Artículo, restos de puntuación** de la limpieza de guiones ("),  y",
    "participación, .") y ausencia del hallazgo TICs/núcleo deliberativo en
    Resultados. CORREGIDO (se añadió párrafo con el 44,6% de red).
18. **README**: párrafo de reproducción decía que el default es `nAGQ = 0`
    (~30-40 min) contradiciendo el bloque de flags de más abajo (default
    exacto); el archivo terminaba truncado a mitad de la lección 6 (sin punto
    final, sin salto de línea: secuela de la corrupción del mount).
    CORREGIDO: párrafo coherente con el default exacto, lección 6 cerrada y
    lección 7 añadida (documentar resultados nulos).
19. **linkedin_post.md desactualizado**: cifras de la versión global vieja
    (63% cobertura, 54% subregistro, 49% ICC), bullets rotos por la limpieza
    de guiones (líneas que parten con coma), y prometía "dashboard que se
    actualiza solo cada mes" (el auto-update se eliminó). CORREGIDO con las
    cifras vigentes (49,9/51,1/24,4; 60/72/92; ICC 66 a 94; OR 0,58 en C).
20. **PASOS_FINALES.md obsoleto** (índice git ya reparado, renumeración ya
    hecha). CORREGIDO: reescrito como runbook vigente.
21. **articulo.pdf desactualizado** (renderizado el 3 de junio; el .qmd cambió
    después y de nuevo hoy). PENDIENTE: `quarto render articulo.qmd`.
22. **policy_brief_participacion_salud.pdf** (difusion/) es del 2 de junio:
    revisa si sus cifras son las vigentes antes de difundirlo. PENDIENTE.

## 4. Limpieza de archivos (PENDIENTE, comandos para PowerShell)

Restos de versiones anteriores que confunden el repo:

```powershell
# CSVs huerfanos de la version global antigua (el tablero lee solo productos/{A,B,C,sintesis})
Remove-Item productos\*.csv
# Salidas exploratorias de mayo
Remove-Item -Recurse salidas
# Texto de apoyo que quedo dentro de R/
Remove-Item "R\respuesta_tableau.txt"
# Productos del modulo ML eliminado
Remove-Item -Recurse productos\ml
```

Opcional: mover `PLAN_REDISENO_DASHBOARD.md` y `boceto_dashboard.md` a una
carpeta `docs_internos/` (ya cumplieron su función). `git status` muestra
además modificaciones sin commitear en `R/exploratorio/` y crosswalk: decide si
las commiteas o las descartas con `git checkout -- <archivo>`.

## 5. Qué correr ahora en Positron (en orden)

```powershell
quarto render                  # 1. dashboard nuevo (no requiere re-correr pipeline)
quarto render articulo.qmd     # 2. informe tecnico actualizado
```

Revisa en el navegador: que el mapa cargue (si no, `source("R/diag_mapa.R")` y
me cuentas el último PASO), las pestañas de cada página, el value box "Núcleo
deliberativo 44,6%", y el tablero en una ventana angosta (móvil).

Cuando todo se vea bien:

```powershell
git add -A
git commit -m "Auditoria: reestructura dashboard (7 paginas, tabsets), corrige nucleo deliberativo (44,6%), mapa, articulo y README"
git push
```

La próxima corrida completa del pipeline (`source("R/10_run_all.R")`, cuando
quieras, no urge) regenerará `kpis_B_nucleo.csv` y `sub_b1_clase.csv` con los
denominadores corregidos.
