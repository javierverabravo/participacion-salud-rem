# Participación Ciudadana en Salud — Análisis de los REM (MINSAL Chile)

Análisis estadístico de las actividades de **participación ciudadana, comunitaria
e institucional** registradas en los Resúmenes Estadísticos Mensuales (REM) de la
red pública de salud de Chile, a partir de las bases del DEIS-MINSAL.

## Objetivo

Caracterizar quién participa, cómo varía en el territorio y en el tiempo, qué
factores explican las diferencias y qué revela el patrón de subregistro, usando
métodos adecuados a la naturaleza de los datos (conteos, panel, datos espaciales).

## Fuente de datos

Series REM publicadas por el [Departamento de Estadísticas e Información de Salud
(DEIS)](https://deis.minsal.cl/) del MINSAL. La participación se concentra en la
**Serie A, sección REM-A19b** (OIRS/reclamos, participación social, satisfacción usuaria).

> Los archivos CSV de datos crudos (~1 GB) **no** forman parte de este repositorio:
> se descargan automáticamente con el script de descarga. Aquí solo vive el código,
> los diccionarios de códigos y los manuales de referencia.

## Estructura del proyecto

```
R/            Scripts de R (descarga, limpieza, análisis)
Diccionarios/ Diccionarios de códigos REM (.xlsm)
*.pdf         Manuales oficiales de las series REM
datos/        (ignorada por Git) CSV crudos descargados del DEIS
salidas/      (ignorada por Git) resultados, gráficos y tablas generados
```

## Estado

En desarrollo. Fase 1 (diagnóstico de datos) completada.

## Autor

Javier — Salud Pública, Chile · GitHub [@Arleq89](https://github.com/Arleq89)
