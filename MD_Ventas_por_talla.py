import streamlit as st
import pandas as pd
import GraficaBarraDobleTalla as GBDT
from excel_exporter import to_excel
from datetime import datetime
from pandas.api.types import CategoricalDtype
import config
import sidebar_filters # Importar el nuevo módulo

def main(DataF, cliente_seleccionado):


    # Renderizar y aplicar filtros
    selections = sidebar_filters.get_filter_selections(DataF)
    df_filtroTL = sidebar_filters.apply_filters(DataF, selections)
    
    opciones = sorted(list(map(str, df_filtroTL["Color"].unique())))
    selecciones_multi = st.sidebar.multiselect("Color", opciones, key="ms_color")
    if selecciones_multi:
        selections["Color"] = selecciones_multi

    # --- Lógica de Filtro de Participación --- #
    # Se calcula la participación total por talla sobre los datos ya filtrados por el usuario
    if selecciones_multi:
        df_filtroTL = df_filtroTL[df_filtroTL['Color'].isin(selecciones_multi)]
        
    df_calculosTL = df_filtroTL.groupby(['Talla'], dropna=False).agg({'Cant_Venta': 'sum', 'Cant_Stock': 'sum'}).reset_index()
    df_calculosTL['Total_Unidades'] = df_calculosTL['Cant_Venta'] + df_calculosTL['Cant_Stock']
    total_unidades_global = df_calculosTL['Total_Unidades'].sum()
    df_calculosTL['%_Participacion_Total'] = (df_calculosTL['Total_Unidades'] / total_unidades_global) * 100 if total_unidades_global else None

    slider = st.sidebar.slider(
        "Quitar % participacion menor a:",
        min_value=0.00, 
        max_value=10.00, 
        value=0.50, 
        step=0.50,
        format="%.2f%%", 
    )
    
    st.sidebar.write(f'Quitar menor a {slider} % de participación')    
    df_calculosTL = df_calculosTL[df_calculosTL['%_Participacion_Total'] >= slider]
    tallas = df_calculosTL['Talla'].unique().tolist()

    df_filtroTL = df_filtroTL[df_filtroTL['Talla'].isin(tallas)]

    # --- Lógica de Ordenamiento Personalizado para Tallas ---
    if not df_filtroTL.empty:
        # Usa la lista de orden de tallas desde el archivo de configuración
        orden_tallas_personalizado = config.ORDEN_TALLAS_PERSONALIZADO[::-1]

        # Convierte la columna de tallas a string para una comparación consistente.
        df_filtroTL['Talla'] = df_filtroTL['Talla'].astype(str)
        
        # Obtiene las tallas únicas presentes en el DataFrame filtrado.
        tallas_unicas_df = set(df_filtroTL['Talla'].unique())
        
        # Filtra la lista de orden personalizado para incluir solo las tallas que existen en el DataFrame.
        # Esto mantiene el orden deseado y asegura que no haya errores si faltan algunas tallas.
        orden_final_tallas = [talla for talla in orden_tallas_personalizado if talla in tallas_unicas_df]
        
        # Crea el tipo categórico con el orden personalizado.
        talla_cat_type = CategoricalDtype(categories=orden_final_tallas, ordered=True)
        
        # Aplica el tipo categórico a la columna 'Talla'.
        df_filtroTL['Talla'] = df_filtroTL['Talla'].astype(talla_cat_type)

    # --- Preparación y visualización de gráficos --- #
    Locales = df_filtroTL[['Local', 'Ciudad']].drop_duplicates().sort_values(by=['Ciudad', 'Local']).values.tolist()

    Colu1, Colu2, Colu3 = st.columns(3)
    columnas = [Colu1, Colu2, Colu3]

    for indice, local in enumerate(Locales):
        Columna_Actual = columnas[indice % 3]
        with Columna_Actual:
            df_local = df_filtroTL[df_filtroTL['Local'] == local[0]].copy()
            df_local = df_local.groupby(['Talla'], observed=False).agg({'Cant_Venta': 'sum', 'Cant_Stock': 'sum'}).reset_index()
            T_Venta = df_local['Cant_Venta'].sum()
            T_Stock = df_local['Cant_Stock'].sum()
            df_local['%_Participacion_Venta'] = (df_local['Cant_Venta'] / T_Venta) * 100 if T_Venta else 0
            df_local['%_Participacion_Stock'] = (df_local['Cant_Stock'] / T_Stock) * 100 if T_Stock else 0

            df_local = df_local.sort_values(by='Talla') #Orden personalizado sado por orden_tallas_personalizado

            if not df_local.empty:
                
                fig = GBDT.crear_grafica_barra_doble_horizontal(
                    dataframe=df_local,
                    eje_y_col='Talla',
                    eje_x_col1='%_Participacion_Venta',
                    eje_x_col2='%_Participacion_Stock',
                    custom_data_col1='Cant_Venta',
                    custom_data_col2='Cant_Stock',
                    titulo=f"{local[0]} - {local[1][5:]}",
                    nombre_barra1="% Venta",
                    nombre_barra2="% Stock",
                    height=500
                )
                st.plotly_chart(fig, use_container_width=True, config={'scrollZoom': False, 'displayModeBar': False})

    st.write("Datos filtrados por talla")
    st.dataframe(df_filtroTL.head(10), width='stretch')
    #df_xlsx = to_excel(df_filtroTL)

"""     st.download_button(
        label="📥 Descargar en Excel",
        data=to_excel(df_filtroTL),
        file_name=f"Ventas_por_talla_{datetime.now().strftime('%Y%m%d_%H%M%S')}.xlsx",
        mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    ) """
