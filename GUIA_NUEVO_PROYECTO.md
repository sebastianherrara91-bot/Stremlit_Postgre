# Guía Base: Evolución a DashInco 2.0 (PostgreSQL)

Este documento es una guía estructural y de mejores prácticas para la siguiente gran iteración del Dashboard. Captura las lecciones aprendidas de nuestro primer contacto (optimización, migraciones y UX) para asegurar que el próximo panel no solo sea potente a nivel técnico, sino también **útil, fácil de interpretar, visualmente atractivo y vital para la toma de decisiones del negocio**.

---

## 1. Visión y Objetivos del Negocio 🎯

El objetivo principal del nuevo panel es permitir que cualquier persona con acceso pueda **saber inmediatamente si el negocio va bien o mal**.
- **Regla de Oro:** Menos clics para ver más valor. 
- **Estética:** Debe invitar al uso. Pantallas responsivas (`width='stretch'`), colores contrastantes, modo oscuro/claro armonizado, y una jerarquía visual clara (usar `st.subheader` o métricas destacadas en vez de tablas planas y aburridas).

## 2. Arquitectura de Datos: El Motor SQL 🐘

Dado el tremendo éxito en las últimas optimizaciones, **los queries de PostgreSQL se mantendrán casi intactos**. Éstos representan la mayor ventaja competitiva actual.

**Lecciones a replicar en nuevos queries:**
1. **CTEs Perfiladores (`Valid_Marca_Tipo`):** Filtra primero usando `HAVING SUM(cant) > umbral`, y luego cruza eso contra millones de registros. Es infinitamente más rápido.
2. **Prioridad de Reglas de Negocio con `COALESCE`:** La técnica `COALESCE(excepcion, correccion, original)` elimina la necesidad de queries anidados pesados o bucles `LIMIT 1`.
3. **Cruces Robustos (`IS NOT DISTINCT FROM`):** Nunca perder inventario por campos nulos.
4. **Paralelismo en Python:** Cargar en interfaz usando siempre `concurrent.futures.ThreadPoolExecutor` para disparar estos queries al mismo tiempo.

## 3. Pruebas de Rendimiento Constantes (Testing) ⏱️

El script `test_rendimiento.py` demostró ser **esencial**. Nunca se deben enviar queries nuevos a producción sin pasar por esta suite de pruebas.

**Metodología a mantener:**
- Usar `EXPLAIN (ANALYZE, BUFFERS)` para diagnosticar si un join está escaneando secuencialmente (cuello de botella) en lugar de usar índices.
- Guardar `logs_rendimiento` iterativos para auditar los tiempos.

```python
# Muestra del core de testing usado
import concurrent.futures

def probar_query(nombre_archivo, sql_text, params):
    # Ejecuta el Query con EXPLAIN ANALYZE
    query_explain = text(f"EXPLAIN (ANALYZE, BUFFERS) {sql_text}")
    # Guarda los logs y mide el tiempo exacto de base de datos vs Python
```

## 4. Visualización Estrella: Partición de Ventas vs Stock 📊

Esta es la joya de la corona del dashboard. Permite diagnosticar problemas de exceso de inventario o desabastecimiento rápidamente.

### Gráfico de Barras Dobles (Con representación Hexadecimal)

Para los análisis de color, aplicar directamente los colores reales del inventario en Plotly usando las variables hexagonales nativas de los datos (`Color_Hexa`).

**Fragmento de implementación recomendada (Plotly + Streamlit):**

```python
import plotly.graph_objects as go
import streamlit as st

def crear_grafica_participacion_real(df_chart, titulo_local):
    """
    df_chart debe contener: 'Color', 'Color_Hexa', '%_Participacion_Venta', '%_Participacion_Stock'
    """
    fig = go.Figure()

    # 1. Trazo para el % de Ventas
    fig.add_trace(go.Bar(
        y=df_chart['Color'],
        x=df_chart['%_Participacion_Venta'],
        name='% Venta',
        orientation='h',
        marker=dict(
            # Aplicamos el color hexadecimal extraído de la BD para la barra de ventas
            color=df_chart['Color_Hexa'], 
            line=dict(color='rgba(255, 255, 255, 0.5)', width=1) # Borde sutil
        ),
        text=df_chart['%_Participacion_Venta'].round(1).astype(str) + '%',
        textposition='auto',
        hoverinfo='x+y'
    ))

    # 2. Trazo para el % de Stock
    fig.add_trace(go.Bar(
        y=df_chart['Color'],
        x=df_chart['%_Participacion_Stock'],
        name='% Stock',
        orientation='h',
        # Un gris neutro o bordeado vacío para contrastar rápidamente vs las ventas
        marker=dict(
            color='rgba(200, 200, 200, 0.5)', 
            line=dict(color=df_chart['Color_Hexa'], width=2)
        ),
        text=df_chart['%_Participacion_Stock'].round(1).astype(str) + '%',
        textposition='auto'
    ))

    fig.update_layout(
        title=titulo_local,
        barmode='group', # Agrupa las barras para compararlas cara a cara
        height=600,
        plot_bgcolor='rgba(0,0,0,0)',
        xaxis=dict(showgrid=True, gridcolor='rgba(128,128,128,0.2)'),
        margin=dict(l=0, r=0, t=40, b=0)
    )

    # Renderiza aprovechando todo el tamaño de pantalla
    st.plotly_chart(fig, use_container_width=True, config={'displayModeBar': False})
```

## 5. Control de Calidad en Datos y Excepciones 🛡️

Todo dashboard potente choca con datos imperfectos.
1. **Nulos en Pandas (`NoneType` o `NaN`):** Tal como sucedió con los locales sin ciudad, siempre validar o convertir a strings antes de interactuar con textos.
   - *Ejemplo Correcto:* `f" {str(local[1])} " if str(local[1]) not in ['None', 'nan'] else ""`
2. **KeyErrors con Nombres de Columnas:** Las agrupaciones SQL arrojan variables. En Streamlit, asegurar siempre usar el case estándar (ej. `'Color'`, no `'COLOR'`).

## 6. Resumen de Flujo para Nuevos Módulos

Al crear un nuevo módulo (Ej: `MD_Rentabilidad_Margen.py`):
1. Crear el `.sql` ultra-optimizado usando CTEs.
2. Añadirlo a `test_rendimiento.py` y medir (< 5 segundos).
3. Añadir la llamada paralela en `init.py` (usando `executor.submit()`).
4. Construir la UI en su archivo propio `MD_*.py` usando Plotly o Pandas Styles.
5. Inyectarlo en la vista usando `st.tabs` o `st.columns`.
