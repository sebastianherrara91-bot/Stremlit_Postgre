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
    titulo_eje_x: str = "",
    titulo_eje_y: str = "",
    height: int = 800
):
    """ 
    Crea una gráfica de barras dobles horizontal con un diseño minimalista para Tallas.
    """
    fig = go.Figure()

    # --- Barra 1 (ej. Ventas) ---
    fig.add_trace(go.Bar(
        x=dataframe[eje_x_col1],
        y=dataframe[eje_y_col],
        orientation='h',
        name=nombre_barra1,
        customdata=dataframe[custom_data_col1],
        marker_color='#A9A9A9',  # Gris oscuro
        marker_line_color='#333333', # Borde más oscuro
        marker_line_width=1,
        hovertemplate=f'<b>Talla: %{{y}}</b><br><b>{nombre_barra1}:</b> %{{x:.2f}}%<br><b>Unidades:</b> %{{customdata:,}}<extra></extra>',
        text=dataframe[eje_x_col1].apply(lambda x: f'{x:.1f}%'),
        textposition='outside' # Posición automática para evitar solapamiento
    ))

    # --- Barra 2 (ej. Stock) ---
    fig.add_trace(go.Bar(
        x=dataframe[eje_x_col2],
        y=dataframe[eje_y_col],
        orientation='h',
        name=nombre_barra2,
        customdata=dataframe[custom_data_col2],
        marker_color='#F0F0F0', # Gris claro
        marker_line_color='#333333',
        marker_line_width=1,
        hovertemplate=f'<b>Talla: %{{y}}</b><br><b>{nombre_barra2}:</b> %{{x:.2f}}%<br><b>Unidades:</b> %{{customdata:,}}<extra></extra>',
        text=dataframe[eje_x_col2].apply(lambda x: f'{x:.1f}%'),
        textposition='outside' # Posición automática para evitar solapamiento
    ))

    # --- Layout Minimalista y Profesional ---
    fig.update_layout(
        template='plotly_white',
        showlegend=False,
        height=height,
        barmode='group',
        title=dict(text=f"<b>{titulo}</b>", x=0.2, font=dict(size=20)),
        font=dict(family="sans-serif", size=10, color="#333333"),
        yaxis=dict(showgrid=False, showline=False, showticklabels=True, categoryorder='trace'), # Ordena según el orden del dataframe
        xaxis=dict(visible=False), # Oculta completamente el eje X
        margin=dict(l=10, r=10, t=35, b=10),
        bargap=0.15,
        bargroupgap=0.10,
        dragmode=False
    )

    # Se reduce el tamaño de la fuente para evitar solapamiento
    fig.update_traces(textfont_size=9, textangle=0, textfont_color="#333333")

    return fig