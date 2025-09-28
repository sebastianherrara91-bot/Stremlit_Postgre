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

st.set_page_config(
    page_title="Ventas_Inco",
    page_icon=":bar_chart:",
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
    menu_options = ["Resumen por Tienda", "Ventas por Tienda", "Ventas por color", "Ventas por talla", "Ventas por Arte"]
    selec = st.sidebar.selectbox("Seleccionar Detalle", menu_options)

    # 3. Añadir la lógica para el nuevo dashboard
    if selec == "Resumen por Tienda":
        df_tienda = GSQL.get_dataframe("Ventas_por_tienda.sql")
        df_color = GSQL.get_dataframe("Ventas_por_color.sql")
        df_talla = GSQL.get_dataframe("Ventas_por_talla.sql")
        
        if not df_tienda.empty and not df_color.empty and not df_talla.empty:
            RT.main(df_tienda, df_color, df_talla)
        else:
            st.warning("No se pudieron cargar todos los datos necesarios para el Resumen por Tienda.")

    elif selec == "Ventas por Tienda":
        df_tienda = GSQL.get_dataframe("Ventas_por_tienda.sql")
        if not df_tienda.empty:
            VPTI.main(df_tienda)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Tiendas.")

    elif selec == "Ventas por color":
        df_color = GSQL.get_dataframe("Ventas_por_color.sql")
        if not df_color.empty:
            VPC.main(df_color)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Color.")

    elif selec == "Ventas por talla":
        df_talla = GSQL.get_dataframe("Ventas_por_talla.sql")
        if not df_talla.empty:
            VPT.main(df_talla)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Talla.")

    elif selec == "Ventas por Arte":
        st.info("El dashboard 'Ventas por Arte' está en construcción.")

if __name__ == '__main__':
    main()
