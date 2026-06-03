# Plan de trabajo — Rediseño del dashboard de Participación en Salud (REM A19b)

> Basado en el documento "comentarios del dashboard" (jun 2026). Los comentarios son **acumulativos**: varios obligan a rehacer el flujo completo, no solo un recuadro. Este plan los ordena por tema y define el orden de ejecución.

---

## 0. Decisión de arquitectura (define todo lo demás)

El comentario más estructural es: *"¿No se puede hacer como una app con Shiny? El dashboard puede ser un borrador."*

| Opción | Interactividad | Hosting | Esfuerzo |
|---|---|---|---|
| **Quarto actual** (estático, GitHub Pages) | Media (plotly/DT, filtros JS limitados) | Gratis, automático | Bajo — ya existe |
| **Shiny** | Alta (filtros/desplegables reales, mapa reactivo por región) | Requiere servidor (shinyapps.io o propio) | Alto — reescritura de la capa de presentación |

Casi todos los comentarios pedidos (filtro por región, segmentación dinámica sexo/género, mapa reactivo, cruces de probabilidad por variable) **apuntan a Shiny**. Propuesta: **mantener Quarto como borrador** mientras se consolida el contenido, y **construir en paralelo una app Shiny** como entrega final interactiva. El backend de datos (productos/) es el mismo para ambos, así que no se pierde trabajo.

---

## 1. Estructura y navegación (transversal)

1. **Reordenar páginas:** Metodología → Glosario → Resumen → **Territorio (nuevo, mapa interactivo)** → A (OIRS) → B (Participación) → C (Satisfacción) → Síntesis/Auditoría.
2. **Sacar todos los "tableros de interpretación"** (cajas de texto interpretativo) de todas las páginas.
3. **Glosario antes del Resumen**, con lenguaje para cualquier persona sin formación técnica. Términos a definir: subregistro, meses con registro, ICC barrera, OR pobreza, p pobreza, hurdle/barrera-intensidad, multinivel.
4. **Tooltips de ayuda** (viñeta "?" al pasar el mouse) en **cada** indicador y encabezado de columna: qué significa + cómo se calcula, en una frase simple.
5. **Bugs de presentación** (repetidos en el documento): (a) gráficos se **superponen en celular** → responsive; (b) **texto de ejes superpuesto** en varios gráficos → rotar/ajustar márgenes.

---

## 2. Página Resumen

- "**Red analizada**" debe ser el **primer** recuadro.
- Clarificar "**Meses c/registro**" (¿promedio de meses registrados por establecimiento y tipo de actividad?).
- Clarificar "**subregistro 60.4%**" (¿% de meses sin registro?) — redacción ambigua.
- El resumen es **demasiado simple**; C1/C2 tiene información más rica. Revaluar qué más mostrar aquí.

---

## 3. Nueva página: Territorio (mapa interactivo)

- Lámina territorial **después del Resumen**, siguiendo la distribución del **otro dashboard de referencia** *(necesito que me pases el enlace/captura).*
- **Mapa interactivo por región, en detalle.** Patrón: un panel con la **realidad nacional** + paneles que se **reenfocan en la región seleccionada** vía filtro/desplegable.
- Concentrar aquí los gráficos territoriales que hoy están dispersos: **% participantes por región según pueblos originarios / migrantes**, replicado para **A (OIRS), B (participación), C (satisfacción/humanización)**.
- Rehacer el gráfico "**dónde vive la variación**": comuna pesa ~29–30%, que **sí es relevante** → presentarlo como señal de desigualdad territorial latente, no como residual.

---

## 4. Presentar A, B y C con lógica propia (no la misma plantilla)

Cada bloque debe leerse en su propia lógica, con indicadores propios:

- **A — OIRS:** separar **Reclamos** de **Consultas / Felicitaciones / Sugerencias** (hoy van con la misma estructura). Indicadores propios: razón felicitaciones/reclamos, % por tiempos de espera, fuera de plazo.
- **B — Participación:** **diferenciar B.1 de B.2.**
  - **B.1** = actividades según **instancias de participación**: cruzar *tipo de actividad × tipo de instancia × tipo de participante* (Ambos sexos, Hombres, Mujeres, Trans Masc., Trans Fem., No binarie, No revelado, Pueblos Originarios, Migrantes, PRAIS).
  - **B.2** = total de **sesiones según líneas de acción**.
  - Indicadores que distingan ambas líneas + graficar el **subregistro** de cada una.
  - Puede ocupar **dos páginas** si hace falta (ya habías pedido esto antes).
- **C — Satisfacción:** C1/C2 es lo más rico → expandir. Arreglar el gráfico **cobertura vs pobreza** (no se entiende; probar otro tipo de gráfico, más explicativo).

**Equidad/segmentación (transversal a A, B, C):** agregar indicadores de **sexo/género** (hombre, mujer, trans masc., trans fem., no binarie, PRAIS), **NNA y gestantes**, **pueblos originarios y migrantes**. No basta "% de mujeres": ofrecer **segmentación dinámica** (filtros) en vez de un número fijo.

---

## 5. Página Síntesis / Auditoría

- Gráfico "**composición media del perfil**": el eje llega a **200** → aclarar **200% respecto de qué** (o normalizar). Corregir texto superpuesto.
- **Encabezados de columnas**: replantear o agregar tooltip explicativo.

---

## 6. Modelado: nuevas variables y cruces

- **Dependencia administrativa**: hoy **no se está usando** como variable. Ya está en la base maestra de establecimientos → incorporarla al modelo multinivel y a los cortes del dashboard (puede explicar parte de la varianza de establecimiento).
- **Nivel de atención "No aplica / Otro"**: investigar si esos establecimientos pueden **reclasificarse** en uno de los 3 niveles.
- **Gráfico "probabilidad de registrar según sección y nivel"** (te gusta): generalizarlo para **cruzar otras variables** — tipo de establecimiento, dependencia administrativa, comuna/región — igual que en la vista territorial.
- Comentario metodológico: el multinivel ya incluye **establecimiento / comuna / región**; falta **exponer también tipo de establecimiento y nivel de atención** en la presentación (el dato existe, no se está mostrando).

---

## 7. Orden de ejecución propuesto

1. **Decidir** Quarto-borrador vs Shiny (sección 0) y conseguir el dashboard de referencia.
2. **Backend** (scripts R): añadir dependencia administrativa, reclasificar "Otro", generar los productos de equidad B.1/B.2 y los cortes territoriales por bloque. Reaprovecha el motor `04_engine.R`.
3. **Glosario + Metodología + tooltips** (capa de texto, rápida y desbloquea el resto).
4. **Reordenar páginas** y **quitar tableros interpretativos**.
5. **Página Territorio** con mapa interactivo.
6. Rehacer **A, B (B.1/B.2), C** con lógica propia + segmentación.
7. Arreglar **bugs responsive y de ejes**; corregir Síntesis.
8. Si se eligió Shiny: portar la capa de presentación a la app.

---

## Lo que necesito de ti (Javier)

1. **Decisión Quarto vs Shiny** (y si Shiny, dónde se hospedaría).
2. **Enlace o captura del "otro dashboard"** de referencia para la lámina territorial.
3. Confirmar que el **archivo FONASA** (Beneficiarios 2025) sigue disponible para los indicadores per cápita.
4. Quedó pendiente de la sesión anterior: **`quarto render` + push** del dashboard reconstruido (ver PASOS_FINALES.md). ¿Lo dejamos así o lo retomamos antes de empezar el rediseño?
