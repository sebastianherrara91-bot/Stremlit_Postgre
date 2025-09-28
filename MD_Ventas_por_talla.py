import streamlit as st
import pandas as pd
import GraficaBarraDobleTalla as GBDT
from excel_exporter import to_excel
from datetime import datetime
from pandas.api.types import CategoricalDtype

def main(DataF):
    st.sidebar.header("Filtros Dinámicos")

    # --- Sección de Filtros --- #
    filtros_selectbox = [
        ("Cliente", "Ini_Cliente", False),
        ("Tipo Programa", "Tipo_Programa", True),
        ("Marca", "Marca", False)
    ]
    filtros_multiselect = [
        ("Fit Estilo", "Fit_Estilo", True),
        ("Semanas", "Semanas", True)
    ]

    df_filtroTL = DataF.copy()

        # Bucle para Filtros de Selección ÚNICA (selectbox)___________________________________________________________________________________________________________
    for titulo, columna, orden in filtros_selectbox:
        opciones = ['Todos'] + sorted(list(df_filtroTL[columna].unique()), reverse=orden)
        seleccion = st.sidebar.selectbox(titulo, opciones)
        if seleccion != 'Todos':
            df_filtroTL = df_filtroTL[df_filtroTL[columna] == seleccion]

    # Bucle para Filtros de Selección MÚLTIPLE (multiselect)___________________________________________________________________________________________________________
    for titulo, columna, orden in filtros_multiselect:
        opciones = sorted(list(df_filtroTL[columna].unique()), reverse=orden)
        selecciones = st.sidebar.multiselect(titulo, opciones)
        if selecciones:
            df_filtroTL = df_filtroTL[df_filtroTL[columna].isin(selecciones)]

    # --- Lógica de Filtro de Participación --- #
    # Se calcula la participación total por talla sobre los datos ya filtrados por el usuario
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
        # Define el orden de tallas personalizado completo.
        orden_tallas_personalizado = [
            'XXL','XL','L','M','S','SX','XXS','50','49','48','47','46','45','44',
            '43','42','41','40','39','38','37','36','35','34','33','32','31','30',
            '29','28','27','26','25','24','23','22','21','20','19','18','17','16',
            '15','14','13','12','11','10','9','8','7','6','5','4','3','2','1','20M',
            '19M','18M','17M','16M','15M','14M','13M','12M','11M','10M','9M','8M',
            '7M','6M','5M','4M','3M','2M','1M','0M','U'
        ]
        orden_tallas_personalizado = orden_tallas_personalizado[::-1]

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
            df_local = df_local.groupby(['Talla'],observed=False).agg({'Cant_Venta': 'sum', 'Cant_Stock': 'sum'}).reset_index()
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
