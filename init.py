import streamlit as st
import pandas as pd
pd.set_option("styler.render.max_elements", 5419953)
import plotly.express as px
import plotly.graph_objects as go
import GestorSQL as GSQL
import MD_Ventas_por_color as VPC
import MD_Ventas_por_talla as VPT
import MD_Ventas_por_Tienda as VPTI
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
    st.sidebar.header("Menu")
    menu_options = ["Resumen por Tienda", "Ventas por Tienda", "Ventas por Color", "Ventas por Talla", "Ventas por Arte", "Ventas Semanas Año"]
    selec = st.sidebar.selectbox("Seleccionar Detalle", menu_options, label_visibility="collapsed")

    # --- LÓGICA DE FILTROS ---
    # Los nuevos filtros de fecha solo se aplican a los dashboards principales
    if selec != "Ventas Semanas Año" and selec != "Ventas por Arte":
        st.sidebar.markdown("---")
        st.sidebar.header("Filtros de Fecha")
        semanas_dict = GSQL.get_semanas_disponibles()

        if not semanas_dict:
            st.sidebar.warning("No se pudieron cargar las semanas disponibles.")
            st.warning("No se pudieron cargar los filtros de fecha. Los datos mostrados pueden no ser correctos.")
            # Si no hay semanas disponibles, establecemos fechas por defecto para evitar errores
            fecha_fin = pd.Timestamp.today().date()
            fecha_inicio = fecha_fin - pd.Timedelta(weeks=1)
        else:
            lista_semanas = list(semanas_dict.keys())
            
            # Default a la última semana
            default_index = 0

            # Selectores de semana (Semana Desde antes que Semana Hasta)
            semana_desde_str = st.sidebar.selectbox("Semana Desde", lista_semanas, index=default_index)
            semana_hasta_str = st.sidebar.selectbox("Semana Hasta", lista_semanas, index=default_index)

            # Obtener las fechas reales del diccionario
            fecha_fin = semanas_dict[semana_hasta_str]
            fecha_inicio = semanas_dict[semana_desde_str]

            # Asegurarse de que el rango sea correcto (fecha_inicio <= fecha_fin)
            if fecha_inicio > fecha_fin:
                # st.sidebar.warning(f"La 'Semana Desde' ({semana_desde_str}) es posterior a la 'Semana Hasta' ({semana_hasta_str}). Se han intercambiado automáticamente.")
                fecha_inicio, fecha_fin = fecha_fin, fecha_inicio
            
    # --- LÓGICA DE CARGA DE DASHBOARDS ---
    # Inicializar params con fechas por defecto si no se cargaron las semanas (para evitar errores)
    # o si se está en una vista que no usa los filtros generales.
    if selec == "Ventas Semanas Año" or selec == "Ventas por Arte" or not semanas_dict:
        fecha_fin = pd.Timestamp.today().date()
        fecha_inicio = fecha_fin - pd.Timedelta(weeks=1)
        # fecha_inicio_stock_default = fecha_inicio # Valor por defecto, se ajustará por cada dashboard
    
    # Calcular fecha_inicio_stock para cada caso
    if selec == "Resumen por Tienda":
        fecha_inicio_stock_tienda = fecha_inicio # Rango completo para Ventas por Tienda
        fecha_inicio_stock_color_talla = fecha_fin - pd.Timedelta(days=6) # Última semana para Color y Talla
        df_tienda = GSQL.get_dataframe("Ventas_por_tienda.sql", params=(fecha_inicio, fecha_fin, fecha_inicio_stock_tienda))
        df_color = GSQL.get_dataframe("Ventas_por_color.sql", params=(fecha_inicio, fecha_fin, fecha_inicio_stock_color_talla))
        df_talla = GSQL.get_dataframe("Ventas_por_talla.sql", params=(fecha_inicio, fecha_fin, fecha_inicio_stock_color_talla))
        
        if not df_tienda.empty and not df_color.empty and not df_talla.empty:
            RT.main(df_tienda, df_color, df_talla)
        else:
            st.warning("No se pudieron cargar todos los datos necesarios para el Resumen por Tienda con el rango de fechas seleccionado.")

    elif selec == "Ventas por Tienda":
        fecha_inicio_stock_tienda = fecha_inicio # Rango completo
        df_tienda = GSQL.get_dataframe("Ventas_por_Tienda.sql", params=(fecha_inicio, fecha_fin, fecha_inicio_stock_tienda))
        if not df_tienda.empty:
            VPTI.main(df_tienda)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Tiendas con el rango de fechas seleccionado.")

    elif selec == "Ventas por Color":
        fecha_inicio_stock_color = fecha_fin - pd.Timedelta(days=6) # Última semana
        df_color = GSQL.get_dataframe("Ventas_por_color.sql", params=(fecha_inicio, fecha_fin, fecha_inicio_stock_color))
        if not df_color.empty:
            VPC.main(df_color)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Color con el rango de fechas seleccionado.")

    elif selec == "Ventas por Talla":
        fecha_inicio_stock_talla = fecha_fin - pd.Timedelta(days=6) # Última semana
        df_talla = GSQL.get_dataframe("Ventas_por_talla.sql", params=(fecha_inicio, fecha_fin, fecha_inicio_stock_talla))
        if not df_talla.empty:
            VPT.main(df_talla)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Talla con el rango de fechas seleccionado.")

    elif selec == "Ventas por Arte":
        st.info("El dashboard 'Ventas por Arte' está en construcción.")

    elif selec == "Ventas Semanas Año":
        st.sidebar.markdown("---")
        # Filtro de semanas único para esta query
        semanas = st.sidebar.number_input("Semanas a Analizar", min_value=1, value=4, step=1)
            
        # Esta query sigue usando la lógica de semanas hacia atrás, no el rango de fechas.
        # Sus parámetros son (semanas_stock, semanas_venta)
        df_sem_ano = GSQL.get_dataframe("Ventas_Sem_Ano.sql", params=(semanas, semanas))
        if not df_sem_ano.empty:
            VSA.main(df_sem_ano)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Ventas Semanas Año.")

if __name__ == '__main__':
    main()
