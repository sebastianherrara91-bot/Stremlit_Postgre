import plotly.graph_objects as go
import pandas as pd

def crear_grafica_barra_doble_horizontal(
    dataframe: pd.DataFrame,
    eje_y_col: list,
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
    bar_color = dataframe[color_hex_col] if color_hex_col is not None and color_hex_col in dataframe.columns else '#888888'

    # Precalcular suma de porcentajes por grupo de COLOR para el texto (Barra 1 y 2)
    col_agrupacion = eje_y_col[1]
    total_pct_1 = dataframe.groupby(col_agrupacion)[eje_x_col1].transform('sum')
    total_pct_2 = dataframe.groupby(col_agrupacion)[eje_x_col2].transform('sum')

    # Precalcular suma de unidades por grupo de COLOR para el hover
    total_und_1 = dataframe.groupby(col_agrupacion)[custom_data_col1].transform('sum')
    total_und_2 = dataframe.groupby(col_agrupacion)[custom_data_col2].transform('sum')

    # --- Barra 1 ---
    # Crear DataFrame para customdata con nombres únicos para evitar errores de duplicados
    customdata_1 = pd.DataFrame({
        'col0': dataframe[eje_y_col[0]],          # C_Color
        'col1': dataframe[custom_data_col1],      # Unds_Propia
        'col2': total_pct_1,                      # Pct_Total_Grupo
        'col3': total_und_1                       # Unds_Total_Grupo
    })

    # Usamos el último índice del grupo (quien está "más abajo" en la tabla) para el texto
    # Esto asegura consistencia visual si las barras se superponen
    idx_last_1 = dataframe.groupby(col_agrupacion).tail(1).index
    text_1 = pd.Series([''] * len(dataframe), index=dataframe.index)
    # Formateamos el texto solo para los índices seleccionados
    text_1.loc[idx_last_1] = total_pct_1.loc[idx_last_1].apply(lambda x: f'{x:.1f}%')

    fig.add_trace(go.Bar(
        x=dataframe[eje_x_col1],
        y=dataframe[eje_y_col[1]],
        orientation='h',
        name=nombre_barra1,
        customdata=customdata_1,
        marker_color=bar_color,
        marker_line_color='black',
        marker_line_width=1,
        hovertemplate=f'<b>%{{y}} %{{customdata[0]}}</b><br><b>% {nombre_barra1}:</b> %{{x:.1f}}% de %{{customdata[2]:.1f}}%<br><b>Unds:</b> %{{customdata[1]:,.0f}} de %{{customdata[3]:,.0f}}<extra></extra>',
        text=text_1,
        textposition='outside'
    ))

    # --- Barra 2 ---
    # Crear DataFrame para customdata con nombres únicos
    customdata_2 = pd.DataFrame({
        'col0': dataframe[eje_y_col[0]],          # C_Color
        'col1': dataframe[custom_data_col2],      # Unds_Propia (Stock)
        'col2': total_pct_2,                      # Pct_Total_Grupo
        'col3': total_und_2                       # Unds_Total_Grupo
    })

    # Máscara para texto de Barra 2: Usar el último registro del grupo
    idx_last_2 = dataframe.groupby(col_agrupacion).tail(1).index
    text_2 = pd.Series([''] * len(dataframe), index=dataframe.index)
    text_2.loc[idx_last_2] = total_pct_2.loc[idx_last_2].apply(lambda x: f'{x:.1f}%')

    fig.add_trace(go.Bar(
        x=dataframe[eje_x_col2],
        y=dataframe[eje_y_col[1]],
        orientation='h',
        name=nombre_barra2,
        customdata=customdata_2,
        marker_color=bar_color,
        marker_line_color='black',
        marker_line_width=1,
        hovertemplate=f'<b>%{{y}} %{{customdata[0]}}</b><br><b>% {nombre_barra2}:</b> %{{x:.1f}}% de %{{customdata[2]:.1f}}%<br><b>Unds:</b> %{{customdata[1]:,.0f}} de %{{customdata[3]:,.0f}}<extra></extra>',
        text=text_2,
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
