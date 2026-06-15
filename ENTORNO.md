# Reproduccion del entorno con renv

Para que otra persona (o tu mismo, en otro equipo o mas adelante) obtenga
EXACTAMENTE las mismas versiones de R y de los paquetes, el entorno se fija con
`renv`. Hoy el README lista los paquetes pero no sus versiones; `renv` cierra esa
brecha y hace que el proyecto sea reproducible de verdad, no solo "a la vista".

## Que hace renv

Crea un archivo `renv.lock` que anota la version exacta de R y de cada paquete que
usa el proyecto. Cualquiera que clone el repo reconstruye ese entorno con un solo
comando, sin adivinar versiones.

## Pasos para crearlo (una sola vez, en tu equipo)

En la consola de R, desde la raiz del proyecto:

1. Instala renv, si no lo tienes:

   install.packages("renv")

2. Inicializa renv en el proyecto:

   renv::init()

   renv escanea el codigo de `R/`, detecta los paquetes que usas (here,
   data.table, readxl, lme4, ggplot2, plotly, DT, bslib, sf, spdep, chilemapas,
   digest, etc.) y crea `renv.lock`, la carpeta `renv/` y un `.Rprofile`.

3. Si algun paquete no quedo capturado (por ejemplo uno que cargas dinamico),
   instalalo y vuelve a registrar el estado:

   renv::snapshot()

## Que se sube a git

Sube `renv.lock`, `.Rprofile` y `renv/activate.R`. La carpeta `renv/library/`
NO se sube: es la libreria local y renv ya la ignora con su propio `.gitignore`.

   git add renv.lock .Rprofile renv/activate.R
   git commit -m "Fijar el entorno con renv (renv.lock)"
   git push

## Como lo reproduce otra persona

Clona el repo, abre el proyecto en R y corre:

   renv::restore()

renv instala las versiones exactas del lockfile. Listo, mismo entorno.

## Anadir al README

Conviene agregar al README, en la seccion "Como reproducir todo", una linea
antes de correr el pipeline:

   renv::restore()   # reconstruye el entorno exacto (una sola vez)

## Nota importante

El `renv.lock` se genera en TU equipo porque debe reflejar las versiones que
tienes instaladas. No se puede crear desde fuera sin tu entorno real, por eso
este paso lo corres tu. Una vez generado y subido, el proyecto queda con su
entorno fijado para siempre.
