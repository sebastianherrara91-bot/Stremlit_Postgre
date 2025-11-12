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
import StreamlitElements as SE
import PIL.Image as Image

logo = Image.open("INCO.png")
st.set_page_config(
    page_title="Ventas_Inco",
    page_icon=logo,
    layout="wide"
)

# Inyectar CSS para forzar la reducción de márgenes laterales
st.markdown("""
    <style>
    .block-container {
        padding-left: 2rem !important;
        padding-right: 2rem !important;
    }
    /* Media query para pantallas pequeñas (móviles) */
    @media (max-width: 768px) {
        .block-container {
            max-width: 46rem;
            padding-left: 1rem !important;
            padding-right: 1rem !important;
        }
    }
    /* Reducir la altura de las filas en las tablas */
    div[data-testid="stDataFrame"] td {
        padding-top: 0.1rem !important;
        padding-bottom: 0.1rem !important;
    }
    </style>
""", unsafe_allow_html=True)

def main():
    st.sidebar.header("Menu")
    # 2. Añadir la nueva opción al menú
    menu_options = ["Resumen por Tienda", "Ventas por Tienda", "Ventas por Color", "Ventas por Talla", "Ventas por Arte"]
    selec = st.sidebar.selectbox("Seleccionar Detalle", menu_options,label_visibility="collapsed")

    # 3. Añadir la lógica para el nuevo dashboard
    if selec == "Resumen por Tienda":
        
        df_tienda = GSQL.get_dataframe("Ventas_por_tienda.sql", params=(8, 8))
        df_color = GSQL.get_dataframe("Ventas_por_color.sql", params=(1, 8))
        df_talla = GSQL.get_dataframe("Ventas_por_talla.sql", params=(1, 8))
        
        if not df_tienda.empty and not df_color.empty and not df_talla.empty:
            RT.main(df_tienda, df_color, df_talla)
        else:
            st.warning("No se pudieron cargar todos los datos necesarios para el Resumen por Tienda.")

    elif selec == "Ventas por Tienda":
        semanas_stock = 8
        semanas_venta = 8
        df_tienda = GSQL.get_dataframe("Ventas_por_Tienda.sql", params=(semanas_stock, semanas_venta))
        if not df_tienda.empty:
            VPTI.main(df_tienda)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Tiendas.")

    elif selec == "Ventas por Color":
        semanas_stock = 1
        semanas_venta = 8
        df_color = GSQL.get_dataframe("Ventas_por_color.sql", params=(semanas_stock, semanas_venta)) # El orden coincide con DECLARE
        if not df_color.empty:
            VPC.main(df_color)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Color.")

    elif selec == "Ventas por Talla":
        semanas_stock = 1
        semanas_venta = 8
        df_talla = GSQL.get_dataframe("Ventas_por_talla.sql", params=(semanas_stock, semanas_venta)) # El orden coincide con DECLARE
        if not df_talla.empty:
            VPT.main(df_talla)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Talla.")

    elif selec == "Ventas por Arte":
        st.info("El dashboard 'Ventas por Arte' está en construcción.")

if __name__ == '__main__':
    main()
