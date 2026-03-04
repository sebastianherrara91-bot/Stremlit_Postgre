import streamlit as st
import pandas as pd
import numpy as np
import GraficaBarraDobleColor as GBD
import GraficaBarraDobleTalla as GBDT
import GestorSQL as GSQL
from pandas.api.types import CategoricalDtype
import config
import sidebar_filters # Importar el nuevo módulo
import excel_exporter
import base64
from st_aggrid import AgGrid, GridOptionsBuilder, GridUpdateMode, DataReturnMode, JsCode # Importar AgGrid

def main(df_tienda, df_color, df_talla, fecha_inicio, fecha_fin, cliente_seleccionado, stock_threshold=800):

    # --- 1. FILTRO PRINCIPAL POR TIENDA ---
    # Preparar los datos para el filtro de tienda
    tiendas_df = df_tienda[['C_L', 'Ciudad', 'Local']].drop_duplicates().sort_values(by=['Ciudad', 'Local'])
    
    # Hacer C_L invisible en el display
    tiendas_df['display'] = tiendas_df['Ciudad'].str[5:] + '-' + tiendas_df['Local']
    
    # Crear mapa de display a C_L para el filtrado
    mapa_display_cl = pd.Series(tiendas_df.C_L.values, index=tiendas_df.display).to_dict()
    lista_tiendas_display = tiendas_df['display'].tolist()

    # Añadir la opción "Todas las Tiendas" y colocarla al principio
    opcion_todas = "Todas las Tiendas"
    lista_tiendas_display.insert(0, opcion_todas)

    # Crear el popover con el radio button para seleccionar la tienda
    with st.popover("Seleccione una Tienda para analizar"):
        tienda_display_seleccionada = st.radio(
            "Tiendas",
            lista_tiendas_display,
            index=0, # Por defecto, selecciona "Todas las Tiendas"
            label_visibility="collapsed"
        )
    
    st.header(f"Resumen: {tienda_display_seleccionada}")

    # Lógica de filtrado
    if tienda_display_seleccionada == opcion_todas:
        df_tienda_raw = df_tienda.copy()
        df_color_local = df_color.copy()
        df_talla_local = df_talla.copy()

        # --- AGREGACIÓN PARA LA VISTA "TODAS LAS TIENDAS" ---
        # Primero, calculamos el valor total de venta por fila para poder hacer el promedio ponderado después.
        df_tienda_raw['PVP_x_Venta'] = df_tienda_raw['PVP_Prom'] * df_tienda_raw['Cant_Venta']
        
        # Agrupamos y agregamos los valores
        group_by_cols = ['Ini_Cliente', 'Marca', 'Tipo_Programa', 'Fit_Estilo', 'Semanas']
        agg_spec = {
            'Cant_Venta': 'sum',
            'Cant_Stock': 'sum',
            'PVP_x_Venta': 'sum'
        }
        df_tienda_local = df_tienda_raw.groupby(group_by_cols, as_index=False).agg(agg_spec)

        # Recalculamos el PVP Promedio ponderado
        df_tienda_local['PVP_Prom'] = np.where(
            df_tienda_local['Cant_Venta'] == 0, 
            0, 
            df_tienda_local['PVP_x_Venta'] / df_tienda_local['Cant_Venta']
        ).round(0)
        
        # Eliminamos la columna auxiliar
        df_tienda_local = df_tienda_local.drop(columns=['PVP_x_Venta'])

    else:
        cl_seleccionado = mapa_display_cl[tienda_display_seleccionada]
        df_tienda_local = df_tienda[df_tienda['C_L'] == cl_seleccionado].copy()
        df_color_local = df_color[df_color['C_L'] == cl_seleccionado].copy()
        df_talla_local = df_talla[df_talla['C_L'] == cl_seleccionado].copy()

    if not tienda_display_seleccionada:
        st.warning("Por favor, seleccione una tienda.")
        return

    # --- 3. RENDERIZAR Y APLICAR FILTROS DEL SIDEBAR ---
    selections = sidebar_filters.get_filter_selections(df_tienda_local)
    if selections:
        df_tienda_local = sidebar_filters.apply_filters(df_tienda_local, selections)
        df_color_local = sidebar_filters.apply_filters(df_color_local, selections)
        df_talla_local = sidebar_filters.apply_filters(df_talla_local, selections)

    # Filtro de participación para el gráfico de color
    slider_participacion = st.sidebar.slider(
        "Quitar % participacion menor a:",
        min_value=0.0, max_value=10.0, value=1.5, step=0.5, format="%.2f%%"
    )

    # --- 4. CALCULAR Y MOSTRAR KPIs (SOLO DE LA SEMANA MÁXIMA) ---
    with st.container(border=True):
        df_kpi = df_tienda_local.copy()
        if not df_kpi.empty:
            max_semana_kpi = df_kpi['Semanas'].max()
            df_kpi = df_kpi[df_kpi['Semanas'] == max_semana_kpi]
        
        total_venta_unidades = df_kpi['Cant_Venta'].sum()
        total_stock_unidades = df_kpi['Cant_Stock'].sum()
        total_unidades = total_venta_unidades + total_stock_unidades
        sell_through = (total_venta_unidades / total_unidades) * 100 if total_unidades > 0 else 0
        pvp_ponderado = (df_kpi['PVP_Prom'] * df_kpi['Cant_Venta']).sum() / total_venta_unidades if total_venta_unidades > 0 else 0

        kpi_cols = st.columns(4)
        kpi_cols[0].metric("Venta Últ. Semana (Un)", f"{total_venta_unidades:,.0f}")
        kpi_cols[1].metric("Stock Últ. Semana (Un)", f"{total_stock_unidades:,.0f}")
        kpi_cols[2].metric("Sell-Through Últ. Semana", f"{sell_through:.1f}%")
        kpi_cols[3].metric("PVP Prom. Últ. Semana", f"$ {pvp_ponderado:,.0f}")

    # --- LÓGICA DE TABLA ---
    df_tienda_local['Sem_Evac'] = np.where((df_tienda_local['Cant_Venta'] == 0), 0, df_tienda_local['Cant_Stock'] / df_tienda_local['Cant_Venta'])
    df_tienda_local['sort_key'] = (df_tienda_local['Tipo_Programa'] != 'programa').astype(int)
    df_tienda_local = df_tienda_local.drop(columns=['sort_key'])
    df_tienda_local['__empty__'] = ''

    # --- TABLA DE DETALLE con AgGrid ---
    st.subheader("Detalle de Ventas y Stock")
    if not df_tienda_local.empty:
        
        js_number_formatter = JsCode("""
            function(params) {
                if (params.value != null && params.value != undefined) {
                    return Math.round(params.value).toString().replace(/\\B(?=(\\d{3})+(?!\\d))/g, '.');
                } 
                return '';
            }
        """)

        js_pvp_formatter = JsCode("""
            function(params) {
                if (params.value != null && params.value != undefined) {
                    return '$ ' + Math.round(params.value).toString().replace(/\\B(?=(\\d{3})+(?!\\d))/g, '.');
                }
                return '';
            }
        """)

        gb = GridOptionsBuilder.from_dataframe(df_tienda_local)

        gb.configure_column("Marca", rowGroup=True, hide=True)
        gb.configure_column("Fit_Estilo", header_name="Fit Estilo", initialSort='asc')
        
        gb.configure_column("C_L", hide=True)
        gb.configure_column("Local", hide=True)
        gb.configure_column("Ciudad", hide=True)
        gb.configure_column("Ini_Cliente", hide=True)

        gb.configure_column("Tipo_Programa", header_name="Tipo Programa")
        gb.configure_column("Semanas", header_name="Semanas", initialSort='asc')
        
        gb.configure_column("Cant_Venta", header_name="Venta", aggFunc='sum', valueFormatter=js_number_formatter)
        gb.configure_column("Cant_Stock", header_name="Stock", aggFunc='sum', valueFormatter=js_number_formatter)
        gb.configure_column("PVP_Prom", header_name="PVP", precision=0, valueFormatter=js_pvp_formatter)
        gb.configure_column("Sem_Evac", header_name="S_Evc", precision=1, valueFormatter=js_number_formatter)
        gb.configure_column("__empty__", header_name="", width=50, suppressMenu=True, suppressMovable=True, suppressResizable=True, sortable=False, filter=False)

        gb.configure_grid_options(
            domLayout='normal',
            groupDisplayType='groupRows',
            defaultColDef={
                'resizable': True,
                'sortable': True,
                'filter': True,
            }
        )
        
        gridOptions = gb.build()

        AgGrid(
            df_tienda_local,
            gridOptions=gridOptions,
            allow_unsafe_jscode=True,
            enable_enterprise_modules=True,
            height=400,
            columnSize="autoSizeAllColumns",
            data_return_mode=DataReturnMode.AS_INPUT,
            update_mode=GridUpdateMode.MODEL_CHANGED,
            key='resumen_tienda_grid'
        )

    else:
        st.warning("No hay datos de detalle para esta tienda con los filtros seleccionados.")

    st.divider()
    
    # --- GRÁFICOS ---

    
    col_grafico_color, col_grafico_talla = st.columns(2)

    with col_grafico_color:
        if not df_color_local.empty:
            df_color_chart = df_color_local.groupby(['COLOR', 'Color_Hexa','C_Color']).agg({'Cant_Venta': 'sum', 'Cant_Stock': 'sum'}).reset_index()
            df_color_chart['Total_Unidades'] = df_color_chart['Cant_Venta'] + df_color_chart['Cant_Stock']
            
            total_unidades_color = df_color_chart['Total_Unidades'].sum()
            df_color_chart['%_Participacion_Total'] = (df_color_chart['Total_Unidades'] / total_unidades_color) * 100 if total_unidades_color > 0 else 0
            df_color_chart = df_color_chart[df_color_chart['%_Participacion_Total'] >= slider_participacion]
            
            T_Venta_Color = df_color_chart['Cant_Venta'].sum()
            T_Stock_Color = df_color_chart['Cant_Stock'].sum()
            df_color_chart['%_Participacion_Venta_C'] = (df_color_chart['Cant_Venta'] / T_Venta_Color) * 100 if T_Venta_Color else 0
            df_color_chart['%_Participacion_Stock_C'] = (df_color_chart['Cant_Stock'] / T_Stock_Color) * 100 if T_Stock_Color else 0
            #Ordenar por participacion total y luego por Participacion por Venta
            df_color_chart = df_color_chart.sort_values(by=['%_Participacion_Total', '%_Participacion_Venta_C'], ascending=[False, False])
            #st.dataframe(df_color_chart)
            
            fig_color = GBD.crear_grafica_barra_doble_horizontal(dataframe=df_color_chart, eje_y_col=['C_Color','COLOR'], eje_x_col1='%_Participacion_Venta_C', eje_x_col2='%_Participacion_Stock_C', color_hex_col='Color_Hexa', custom_data_col1='Cant_Venta', custom_data_col2='Cant_Stock', titulo="Participación por Color", nombre_barra1="% Vnt", nombre_barra2="% Stk", height=800)
            st.plotly_chart(fig_color, use_container_width=True, config={'scrollZoom': False, 'displayModeBar': False})

            
        else:
            st.warning("No hay datos de color para esta tienda.")

    with col_grafico_talla:
        if not df_talla_local.empty:
            orden_tallas = config.ORDEN_TALLAS_PERSONALIZADO[::-1]
            df_talla_local['Talla'] = df_talla_local['Talla'].astype(str)
            tallas_unicas_df = set(df_talla_local['Talla'].unique())
            orden_final_tallas = [talla for talla in orden_tallas if talla in tallas_unicas_df]
            talla_cat_type = CategoricalDtype(categories=orden_final_tallas, ordered=True)
            df_talla_local['Talla'] = df_talla_local['Talla'].astype(talla_cat_type)

            df_talla_chart = df_talla_local.groupby(['Talla'], observed=False).agg({'Cant_Venta': 'sum', 'Cant_Stock': 'sum'}).reset_index()
            T_Venta_Talla = df_talla_chart['Cant_Venta'].sum()
            T_Stock_Talla = df_talla_chart['Cant_Stock'].sum()
            df_talla_chart['%_Participacion_Venta_Talla'] = (df_talla_chart['Cant_Venta'] / T_Venta_Talla) * 100 if T_Venta_Talla else 0
            df_talla_chart['%_Participacion_Stock_Talla'] = (df_talla_chart['Cant_Stock'] / T_Stock_Talla) * 100 if T_Stock_Talla else 0
            df_talla_chart = df_talla_chart.sort_values(by='Talla')

            fig_talla = GBDT.crear_grafica_barra_doble_horizontal(dataframe=df_talla_chart, eje_y_col='Talla', eje_x_col1='%_Participacion_Venta_Talla', eje_x_col2='%_Participacion_Stock_Talla', custom_data_col1='Cant_Venta', custom_data_col2='Cant_Stock', titulo="Participación por Talla", nombre_barra1="% Venta", nombre_barra2="% Stock", height=800)
            st.plotly_chart(fig_talla, use_container_width=True, config={'scrollZoom': False, 'displayModeBar': False})
        else:
            st.warning("No hay datos de talla para esta tienda.")

    st.divider()

    st.subheader("Descargar Informe Detallado")
    
    with st.container(border=True):
        st.markdown("##### Criterios de descarga:")
        
        col1, col2, col3 = st.columns(3)
        col1.markdown(f"**Tienda:** `{tienda_display_seleccionada}`")
        col2.markdown(f"**Fechas:** `{fecha_inicio.strftime('%Y-%m-%d')}` a `{fecha_fin.strftime('%Y-%m-%d')}`")
        col3.markdown(f"**Cliente:** `{cliente_seleccionado}`")
        
        # Mostrar otros filtros activos
        if selections:
            otros_filtros = []
            for filtro, valor in selections.items():
                valor_str = ", ".join(map(str, valor)) if isinstance(valor, list) else str(valor)
                otros_filtros.append(f"**{filtro.replace('_', ' ')}:** `{valor_str}`")
            st.markdown(" ".join(otros_filtros))

    if st.button("Generar y Descargar Excel", type="primary"):
        with st.spinner("Generando archivo Excel... Esto puede tardar unos segundos."):
            # Usar el rango de fecha completo para el stock, como se solicitó.
            params_stock_ultsem = {
                'fecha_inicio_venta': fecha_inicio,
                'fecha_fin_venta': fecha_fin,
                'fecha_inicio_stock': fecha_inicio,
                'ini_cliente': cliente_seleccionado,
                'stock_threshold': stock_threshold
            }
            df_detalle = GSQL.get_dataframe("Ventas_StockUltsem.sql", params=params_stock_ultsem)
            
            if not df_detalle.empty:
                df_filtrado = df_detalle.copy()
                if tienda_display_seleccionada != "Todas las Tiendas":
                    cl_seleccionado_map = mapa_display_cl[tienda_display_seleccionada]
                    df_filtrado = df_filtrado[df_filtrado['C_L'] == cl_seleccionado_map]
                
                df_filtrado = sidebar_filters.apply_filters(df_filtrado, selections)

                if not df_filtrado.empty:
                    excel_bytes = excel_exporter.to_excel(df_filtrado)
                    b64 = base64.b64encode(excel_bytes).decode()
                    href = f'<a href="data:application/octet-stream;base64,{b64}" download="detalle_ventas_stock.xlsx">**Descargar Archivo Excel**</a>'
                    st.markdown(href, unsafe_allow_html=True)
                    st.success("¡Tu archivo está listo para descargar!")
                else:
                    st.warning("No se encontraron datos detallados para los filtros seleccionados.")
            else:
                st.warning("No se pudieron obtener los datos detallados desde la base de datos.")
