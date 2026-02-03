import streamlit as st
import pandas as pd
pd.set_option("styler.render.max_elements", 5419953)
import plotly.express as px
import plotly.graph_objects as go
import GestorSQL as GSQL
import MD_Ventas_por_color as VPC
import MD_Ventas_por_talla as VPT
import MD_Resumen_Tienda as RT  # <-- 1. Importar el nuevo módulo
import MD_Ventas_Sem_Ano as VSA
import StreamlitElements as SE
import PIL.Image as Image

logo = Image.open("INCO.png")
st.set_page_config(
    page_title="Ventas_Inco",
    page_icon=logo,
    layout="wide"
)

def main():
    # --- FILTRO GLOBAL DE CLIENTE ---
    lista_clientes = GSQL.get_clientes()
    # Poner 'FL' como opción por defecto si existe
    default_index = 0
    if 'FL' in lista_clientes: default_index = lista_clientes.index('FL')
    cliente_seleccionado = st.sidebar.selectbox("Cliente", lista_clientes, index=default_index)
    
    
    # Inicializar el umbral de stock en session_state si no existe
    if 'stock_threshold' not in st.session_state:
        st.session_state['stock_threshold'] = 800
    
    stock_threshold = st.session_state['stock_threshold']

    menu_options = ["Resumen por Tienda", "Ventas por Color", "Ventas por Talla", "Ventas por Arte", "Ventas Semanas Año"]
    selec = st.sidebar.selectbox("Menu", menu_options)

    # --- LÓGICA DE FILTROS DE FECHA ---
    if selec != "Ventas Semanas Año" and selec != "Ventas por Arte":
        semanas_dict = GSQL.get_semanas_disponibles()

        if not semanas_dict:
            st.sidebar.warning("No se pudieron cargar las semanas disponibles.")
            fecha_fin = pd.Timestamp.today().date()
            fecha_inicio = fecha_fin - pd.Timedelta(weeks=1)
        else:
            lista_semanas = list(semanas_dict.keys())
            default_index_hasta = 0
            default_index_desde = 5 if len(lista_semanas) > 5 else len(lista_semanas) -1
            
            semana_desde_str = st.sidebar.selectbox("Semana Desde", lista_semanas, index=default_index_desde)
            semana_hasta_str = st.sidebar.selectbox("Semana Hasta", lista_semanas, index=default_index_hasta)

            fecha_fin = semanas_dict[semana_hasta_str]
            fecha_inicio = semanas_dict[semana_desde_str]

            if fecha_inicio > fecha_fin: fecha_inicio, fecha_fin = fecha_fin, fecha_inicio
            
    # --- LÓGICA DE CARGA DE DASHBOARDS ---
    params = {}
    if selec == "Ventas Semanas Año" or selec == "Ventas por Arte":
        fecha_fin = pd.Timestamp.today().date()
        fecha_inicio = fecha_fin - pd.Timedelta(weeks=1)

    # El cliente seleccionado se añade a todos los parámetros
    # La mayoría de las queries ahora tienen 4 parámetros: fecha_inicio, fecha_fin, fecha_inicio_stock, y cliente
    if selec == "Resumen por Tienda":
        fecha_inicio_stock_tienda = fecha_inicio
        fecha_inicio_stock_color_talla = fecha_fin - pd.Timedelta(days=6)
        
        df_tienda = GSQL.get_dataframe("Ventas_por_tienda.sql", params=(fecha_inicio, fecha_fin, fecha_inicio_stock_tienda, cliente_seleccionado, stock_threshold))
        df_color = GSQL.get_dataframe("Ventas_por_color.sql", params=(fecha_inicio, fecha_fin, fecha_inicio_stock_color_talla, cliente_seleccionado, stock_threshold))
        df_talla = GSQL.get_dataframe("Ventas_por_talla.sql", params=(fecha_inicio, fecha_fin, fecha_inicio_stock_color_talla, cliente_seleccionado, stock_threshold))
        
        if not df_tienda.empty and not df_color.empty and not df_talla.empty:
            RT.main(df_tienda, df_color, df_talla, fecha_inicio, fecha_fin, cliente_seleccionado, stock_threshold)
        else:
            st.warning("No se pudieron cargar todos los datos necesarios para el Resumen por Tienda con los filtros seleccionados.")

    elif selec == "Ventas por Color":
        fecha_inicio_stock_color = fecha_fin - pd.Timedelta(days=6)
        df_color = GSQL.get_dataframe("Ventas_por_color.sql", params=(fecha_inicio, fecha_fin, fecha_inicio_stock_color, cliente_seleccionado, stock_threshold))
        if not df_color.empty:
            VPC.main(df_color, cliente_seleccionado)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Color con el rango de fechas seleccionado.")

    elif selec == "Ventas por Talla":
        fecha_inicio_stock_talla = fecha_fin - pd.Timedelta(days=6)
        df_talla = GSQL.get_dataframe("Ventas_por_talla.sql", params=(fecha_inicio, fecha_fin, fecha_inicio_stock_talla, cliente_seleccionado, stock_threshold))
        if not df_talla.empty:
            VPT.main(df_talla, cliente_seleccionado)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Talla con el rango de fechas seleccionado.")

    elif selec == "Ventas por Arte":
        st.info("El dashboard 'Ventas por Arte' está en construcción.")

    elif selec == "Ventas Semanas Año":
        st.sidebar.markdown("---")
        semanas = st.sidebar.number_input("Semanas a Analizar", min_value=1, value=4, step=1)
        df_sem_ano = GSQL.get_dataframe("Ventas_Sem_Ano.sql", params=(semanas, semanas, cliente_seleccionado, stock_threshold))
        if not df_sem_ano.empty:
            VSA.main(df_sem_ano)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Ventas Semanas Año.")

    # Renderizar el slider de stock al FINAL del sidebar

    st.sidebar.slider(
        "Quitar Stock menor a:", 
        min_value=0, 
        max_value=2000, 
        value=800, 
        step=100, 
        key='stock_threshold'
    )

if __name__ == '__main__':
    main()
