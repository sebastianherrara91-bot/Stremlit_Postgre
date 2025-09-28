import plotly.graph_objects as go
import pandas as pd

def crear_grafica_barra_doble_horizontal(
    dataframe: pd.DataFrame,
    eje_y_col: str,
    eje_x_col1: str,
    eje_x_col2: str,
    custom_data_col1: str,
    custom_data_col2: str,
    titulo: str,
    nombre_barra1: str,
    nombre_barra2: str,
    color_hex_col: str = None, # Parámetro de color ahora es opcional
    titulo_eje_x: str = "Valor",
    titulo_eje_y: str = "Categoría",
    height: int = 800
):
    """
    Crea una gráfica de barras dobles horizontal personalizable y reutilizable.

    Args:
        dataframe (pd.DataFrame): DataFrame con los datos.
        eje_y_col (str): Nombre de la columna para el eje Y (categorías).
        eje_x_col1 (str): Nombre de la columna para los valores de la primera barra.
        eje_x_col2 (str): Nombre de la columna para los valores de la segunda barra.
        color_hex_col (str, optional): Columna con colores. Si es None, usa un color por defecto.
        custom_data_col1 (str): Columna con datos extra para el hover de la barra 1.
        custom_data_col2 (str): Columna con datos extra para el hover de la barra 2.
        titulo (str): Título principal del gráfico.
        nombre_barra1 (str): Nombre para la leyenda de la primera barra.
        nombre_barra2 (str): Nombre para la leyenda de la segunda barra.
        titulo_eje_x (str, optional): Título para el eje X. Defaults to "Valor".
        titulo_eje_y (str, optional): Título para el eje Y. Defaults to "Categoría".
        height (int, optional): Altura del gráfico en píxeles. Defaults to 1000.
    Returns:
        go.Figure: Objeto Figure de Plotly con el gráfico generado.
    """
    fig = go.Figure()

    # Define el color de la barra: usa la columna de color si existe, si no, un gris por defecto.
    bar_color = dataframe[color_hex_col] if color_hex_col is not None else '#888888'

    # --- Barra 1 ---
    fig.add_trace(go.Bar(
        x=dataframe[eje_x_col1],
        y=dataframe[eje_y_col],
        orientation='h',
        name=nombre_barra1,
        customdata=dataframe[custom_data_col1],
        marker_color=bar_color,
        marker_line_color='black',
        marker_line_width=1,
        hovertemplate=f'<b>%{{y}}</b><br><b>{nombre_barra1}:</b> %{{x:.2f}}%<br><b>Unidades:</b> %{{customdata:,}}<extra></extra>',
        text=dataframe[eje_x_col1].apply(lambda x: f'{x:.1f}%'),
        textposition='outside'
    ))

    # --- Barra 2 ---
    fig.add_trace(go.Bar(
        x=dataframe[eje_x_col2],
        y=dataframe[eje_y_col],
        orientation='h',
        name=nombre_barra2,
        customdata=dataframe[custom_data_col2],
        marker_color=bar_color,
        marker_line_color='black',
        marker_line_width=1,
        hovertemplate=f'<b>%{{y}}</b><br><b>{nombre_barra2}:</b> %{{x:.2f}}%<br><b>Unidades:</b> %{{customdata:,}}<extra></extra>',
        text=dataframe[eje_x_col2].apply(lambda x: f'{x:.1f}%'),
        textposition='outside'
    ))

    # --- Layout --- 
    fig.update_layout(
        template='plotly_white',                # Tema visual de la gráfica (fondo blanco, etc.)
        showlegend=False,                       # Oculta la leyenda (ej: la caja que dice '% Venta', '% Stock')
        height=height,                          # Altura total de la gráfica en píxeles
        barmode='group',                        # Modo de las barras. 'group' las pone una al lado de la otra.
        yaxis_title=titulo_eje_y,               # Título del eje Y (vertical)
        xaxis_title=titulo_eje_x,               # Título del eje X (horizontal)
        title=dict(
            text=f"<b>{titulo}</b>",            # Texto del título principal
            x=0.2,                              # Posición horizontal del título (0.5 es el centro)
            font=dict(size=20)                  # Tamaño de la fuente del título
        ),
        font=dict(family="sans-serif", size=10),  # Fuente y tamaño de letra para todo el gráfico
        yaxis=dict(
            categoryorder='total ascending',    # Ordena las categorías en el eje Y de menor a mayor
            showgrid=False,
            visible=False                      # Oculta las líneas de la cuadrícula vertical
        ),
        xaxis=dict(visible=False),              # Oculta completamente el eje X (línea, números y título)
        margin=dict(l=20, r=20, t=35, b=10),    # Márgenes (left, right, top, bottom) en píxeles
        bargap=0.15,                            # Espacio entre barras de la misma categoría (si hubiera más)
        bargroupgap=0.10,                        # Espacio entre grupos de barras (ej: entre 'BLANCO' y 'NEGRO')
        dragmode=False                          # Desactiva el poder 'arrastrar' la gráfica, para mejorar el scroll en móviles
    )

    fig.update_traces(textfont_size=10, textangle=0, textposition='outside')

    return fig
