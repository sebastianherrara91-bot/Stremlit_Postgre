import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import numpy as np
import GraficaBarraDobleColor as GBD
import io
from datetime import datetime
from excel_exporter import to_excel
import sidebar_filters # Importar el nuevo módulo

def main(DataF, cliente_seleccionado):

    # Renderizar y aplicar filtros
    selections = sidebar_filters.get_filter_selections(DataF)
    df_filtrado = sidebar_filters.apply_filters(DataF, selections)

    # Inicio de los cálculos de participación para el gráfico___________________________________________________________________________________________________________
    
    df_calculos = df_filtrado.groupby(['COLOR','Color_Hexa','C_Color'], dropna=False).agg({'Cant_Venta': 'sum','Cant_Stock': 'sum'}).reset_index()
    df_calculos['Total_Unidades'] = df_calculos['Cant_Venta'] + df_calculos['Cant_Stock']
    total_unidades_global = df_calculos['Total_Unidades'].sum()
    df_calculos['%_Participacion_Total'] = (df_calculos['Total_Unidades'] / total_unidades_global) * 100 if total_unidades_global else None

    slider = st.sidebar.slider(
        "Quitar % Color, menor a: ", # texto
        min_value=0.00, # valor minimo
        max_value=10.00, # valor maximo
        value=1.50, # Valor Inicial
        step=0.50, # Incremento de 1 en 1
        format="%.2f%%" # Formato de 2 decimales
        )
    
    st.sidebar.write(f'Quitar menor a {slider} % de participación')    
    df_calculos = df_calculos[df_calculos['%_Participacion_Total'] >= slider]
    Colores = df_calculos['COLOR'].unique().tolist()
    
    df_ParaFor = df_filtrado.groupby(['C_L','Local','Ciudad','COLOR','Color_Hexa','C_Color'], dropna=False).agg({'Cant_Venta': 'sum','Cant_Stock': 'sum'}).reset_index()
    df_ParaFor = df_ParaFor[df_ParaFor['COLOR'].isin(Colores)]

    Locales = df_ParaFor[['Local', 'Ciudad']].drop_duplicates().sort_values(by=['Ciudad', 'Local']).values.tolist()

    Colu1, Colu2, Colu3 = st.columns(3)
    columnas = [Colu1,Colu2,Colu3]
    for indice, local in enumerate(Locales):

        Columna_Actual = columnas[indice % 3]#Seleccionamos la columna actual

        with Columna_Actual:
            df_local = df_ParaFor[df_ParaFor['Local'] == local[0]].copy() 
            df_local = df_local.groupby(['COLOR', 'Color_Hexa','C_Color']).agg({'Cant_Venta': 'sum', 'Cant_Stock': 'sum'}).reset_index()
            T_Venta = df_local['Cant_Venta'].sum()
            T_Stock = df_local['Cant_Stock'].sum()
            df_local['%_Participacion_Venta'] = (df_local['Cant_Venta'] / T_Venta) * 100 if T_Venta else None
            df_local['%_Participacion_Stock'] = (df_local['Cant_Stock'] / T_Stock) * 100 if T_Stock else None

            #st.dataframe(df_local, width='stretch', height=500)

            # INICIO: Gráfico de Barras de Participación por Color___________________________________________________________________________________________________________
            # 1. Agregamos los datos por COLOR y Color_Hexa para el gráfico___________________________________________________________________________________________________________
            df_chart = df_local.dropna(subset=['COLOR', 'Color_Hexa']).copy()
            df_chart = df_chart.groupby(['COLOR', 'Color_Hexa','C_Color']).agg({'%_Participacion_Venta': 'sum', '%_Participacion_Stock': 'sum', 'Cant_Venta': 'sum', 'Cant_Stock': 'sum'}).reset_index()

            # Solo proceder si tenemos datos para graficar
            if not df_chart.empty:
                
                # 3. Llamamos a la función reutilizable para crear la gráfica (sin título)
                fig = GBD.crear_grafica_barra_doble_horizontal(
                    dataframe=df_chart,
                    eje_y_col=['C_Color','COLOR'],
                    eje_x_col1='%_Participacion_Venta',
                    eje_x_col2='%_Participacion_Stock',
                    color_hex_col='Color_Hexa',
                    custom_data_col1='Cant_Venta',
                    custom_data_col2='Cant_Stock',
                    titulo=f"{local[0]} - {local[1][5:]}",  # Título vacío para que no se muestre en la gráfica
                    nombre_barra1="% Vta",
                    nombre_barra2="% Stk",
                    titulo_eje_x="",
                    titulo_eje_y="",
                    height=800
                )

                # 4. Mostramos el gráfico en Streamlit con configuración para deshabilitar zoom
                # 4. Mostramos el gráfico en Streamlit con configuración para deshabilitar zoom y la barra de modo
                st.plotly_chart(fig, use_container_width=True, config={'scrollZoom': False, 'displayModeBar': False})
            else:
                st.warning("No hay datos suficientes para generar el gráfico de participación por color después de aplicar los filtros.")
        # FIN: Gráfico de Barras___________________________________________________________________________________________________________

    st.write("Datos filtrados")
    st.dataframe(df_filtrado.head(10), width='stretch', height=200)

    # --- Botón de descarga ---
    #df_xlsx = to_excel(df_filtrado)

"""     st.download_button(
        label="📥 Descargar en Excel",
        data=to_excel(df_filtrado),
        file_name=f"Ventas_por_color_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx",
        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    ) """



