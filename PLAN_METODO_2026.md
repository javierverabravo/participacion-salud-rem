# Plan de metodo, REM 2026 preliminar (monitoreo y proyeccion)

Estado: diseno (no implementado). Fecha: 14 de junio de 2026.
Pertenece a la etapa investigar-metodo. Se conecta con el manifiesto de
procedencia (mejora A): cada corrida de 2026 registra su fecha de corte.

## Idea en una linea

El REM 2026 es preliminar e incompleto, asi que NO se usa como ano cerrado para
comparar contra 2025. Se usa como monitoreo del ano en curso: se mide solo sobre
los meses ya reportados, se compara el mismo periodo contra 2025 y se proyecta el
cierre con una banda de incertidumbre. El diseno es expandible: se re-corre cada
vez que el DEIS publica un mes nuevo y la estimacion se afina sola.

Principio rector: nunca medir sobre meses que no han ocurrido, ni sobre meses con
reporte aun incompleto sin corregir el rezago.

## 1. Deteccion del corte de meses

Al procesar 2026, detectar de forma dinamica el ultimo mes con dato y cuantos
establecimientos reportan por mes. Guardar un producto `corte_2026.csv` con: ano,
ultimo mes disponible, numero de meses, fecha de descarga (enlaza con el
manifiesto de procedencia). Todo lo que sigue usa ese corte, no el calendario.

## 2. Cobertura e intensidad sobre meses transcurridos

El panel de 2026 se construye como establecimiento por meses_disponibles, no por
12. Con ese denominador se recalculan cobertura, subregistro, intensidad y
mediana de meses con registro. Es la misma logica del motor (`04_engine.R`), solo
que el universo de meses viene recortado al corte. Asi el subregistro deja de
inflarse por los meses que aun no ocurren.

## 3. Comparacion del mismo periodo (2026 vs 2025)

En vez de ano contra ano, se toma de 2025 solo los meses 1 a ultimo_mes_2026 y se
comparan, por bloque A/B/C, cobertura, eventos y participantes. Producto
`comparacion_periodo.csv` con las cifras de 2025 (mismos meses) y 2026, mas la
variacion porcentual. Esto responde de forma honesta: vamos mejor o peor que el
ano pasado a esta misma altura.

## 4. Proyeccion de cierre con correccion de rezago

Es la pieza delicada. En datos preliminares los ultimos meses estan
subreportados por rezago administrativo (el establecimiento reporta tarde y el
dato se completa despues), no porque haya menos actividad. Una proyeccion a lo
bruto subestima el cierre. Enfoque propuesto, simple y defendible:

a. Perfil estacional de 2025: que proporcion de la actividad anual ocurre en cada
   mes (share mensual). En 2025 enero y febrero son bajos y marzo a diciembre
   altos.
b. Proyeccion base: escalar lo acumulado de 2026 por el inverso del share
   acumulado de los meses disponibles. Si a mayo 2025 habia ocurrido el 40 por
   ciento del ano, entonces lo acumulado a mayo 2026 dividido por 0,40 estima el
   total del ano.
c. Correccion de rezago: estimar cuanto suben tipicamente los ultimos uno o dos
   meses entre la version preliminar y la final (con 2025, o con versiones
   sucesivas del preliminar si se guardan), e inflar esos meses recientes antes
   de proyectar.
d. Banda de incertidumbre: reportar un rango por escenarios (sin correccion,
   correccion media, correccion alta) y etiquetar siempre "preliminar, sujeto a
   actualizacion". Producto `proyeccion_cierre.csv` con acumulado observado,
   proyeccion central, banda y supuestos.

La proyeccion nunca se presenta como cifra final, siempre como estimacion con su
fecha de corte.

## 5. Verificaciones antes de codificar (con el dato 2026 descargado)

Necesitan el `SERIE_REM_2026.zip` ya bajado en el equipo:

- Cuantos meses trae realmente el preliminar.
- Si se ve el rezago: graficar numero de establecimientos que reportan por mes y
  los eventos por mes. Si el ultimo mes cae notoriamente, el rezago es fuerte y la
  correccion 4c es obligatoria; si es leve, basta con 4b.
- Confirmar que la estructura de columnas del 2026 es igual a la del 2025 (mismos
  crosswalks A19b); si el instrumento cambio codigos, hay que revisar el crosswalk.

## 6. Diseno expandible (re-correr cada mes)

Todo queda parametrizado por `REM_ANIO` y por el corte detectado en el paso 1.
Cuando el DEIS publica un mes nuevo: re-descargar el zip (sobrescribe), re-correr
el pipeline, y los productos de 2026 se actualizan con el nuevo corte. La
comparacion del mismo periodo y la proyeccion se recalibran con cada mes
adicional: la proyeccion se vuelve mas precisa y la banda se angosta a medida que
avanza el ano. No hay que reescribir nada, solo volver a correr.

## 7. Scripts que se tocan

- `00_descarga.R`: ya parametrizado por `REM_ANIO`; confirmar que baja
  `SERIE_REM_2026.zip`.
- `01_procesamiento.R`: detectar meses disponibles, construir el universo sobre
  meses transcurridos (no 12) y escribir `corte_2026.csv`.
- `04_engine.R` o un modulo nuevo (por ejemplo `11_monitoreo_2026.R`): funciones
  de comparacion del mismo periodo y de proyeccion con correccion de rezago.
- Dashboard e informe: una vista "2026 en curso", claramente marcada como
  preliminar y separada de los hallazgos cerrados de 2025.

## 8. Encuadre y honestidad

- 2025 sigue siendo el ano de referencia, con conclusiones cerradas.
- 2026 es monitoreo: describe la tendencia del ano en curso, no reescribe las
  conclusiones de 2025.
- Cada producto de 2026 lleva su fecha de corte y la marca "preliminar".

## Pendiente para implementar

1. Descargar `SERIE_REM_2026.zip` y correr las verificaciones del paso 5.
2. Segun lo que muestre el rezago, decidir entre la proyeccion 4b sola o 4b mas 4c.
3. Implementar el corte de meses en `01_procesamiento.R` y el modulo de monitoreo.
4. Anadir la vista "2026 en curso" al dashboard.
