import streamlit as st
import pandas as pd
pd.set_option("styler.render.max_elements", 5419953)
import plotly.express as px
import plotly.graph_objects as go
import GestorSQL as GSQL
import MD_Ventas_por_color as VPC
import MD_Ventas_por_talla as VPT
import MD_Ventas_por_Tienda as VPTI
import StreamlitElements as SE

st.set_page_config(
    page_title="Ventas_Inco",
    page_icon=":bar_chart:",
    #layout="centered"
    layout="wide" # layout="wide" para que se adapte al ancho de la pantalla
    )

# Inyectar CSS para forzar la reducción de márgenes laterales
st.markdown("""
    <style>
    /* Estilos para el contenedor principal */
    .block-container {
        padding-left: 2rem !important;
        padding-right: 2rem !important;
    }

    /* Media query para pantallas pequeñas (móviles) */
    @media (max-width: 768px) {
        .block-container {
            /* En móvil, reduce el ancho máximo para forzar el apilamiento de columnas */
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

#padding-top: 2rem !important;

def main():

    st.sidebar.header("Menu")
    menu = st.sidebar.selectbox("Seleccionar Detalle", ["Ventas por Tienda", "Ventas por color", "Ventas por talla", "Ventas por Arte"])
    selec = menu

    if selec == "Ventas por Tienda":
        # Llama a la nueva consulta optimizada para tiendas
        df_tienda = GSQL.get_dataframe("Ventas_por_tienda.sql")
        if not df_tienda.empty:
            VPTI.main(df_tienda)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Tiendas.")

    elif selec == "Ventas por color":
        # Llama a la nueva consulta optimizada para color, sin groupby en python
        df_color = GSQL.get_dataframe("Ventas_por_color.sql")
        if not df_color.empty:
            VPC.main(df_color)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Color.")

    elif selec == "Ventas por talla":
        # Llama a la nueva consulta optimizada para talla, sin groupby en python
        df_talla = GSQL.get_dataframe("Ventas_por_talla.sql")
        if not df_talla.empty:
            VPT.main(df_talla)
        else:
            st.warning("No se pudieron cargar los datos para el dashboard de Talla.")

    elif selec == "Ventas por Arte":
        # SE.StreamElement() # Esta línea parece estar incompleta o es un placeholder
        st.info("El dashboard 'Ventas por Arte' está en construcción.")
    

    #st.dataframe(dfv, width='stretch', height=500)

if __name__ == '__main__':
    main()
