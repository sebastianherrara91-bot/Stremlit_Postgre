import streamlit as st
import pandas as pd
import numpy as np
import GraficaBarraDobleColor as GBD
import GraficaBarraDobleTalla as GBDT
from pandas.api.types import CategoricalDtype
import config
import sidebar_filters # Importar el nuevo módulo

# Re-using styling functions from MD_Ventas_por_Tienda
def resaltar_fila_max_semana(fila,semmax):
    if fila['Semanas'] == semmax:
        return ['background-color: #D4EDDA'] * len(fila)
    else:
        return [''] * len(fila)

def highlight_min_non_zero(col, color):
    non_zero_vals = col.replace(0, np.nan)
    min_val = non_zero_vals.min()
    return [f'background-color: {color}' if v == min_val else '' for v in col]

def main(df_tienda, df_color, df_talla):

    # --- 1. FILTRO PRINCIPAL POR TIENDA ---
    # Preparar los datos para el filtro de tienda
    tiendas_df = df_tienda[['C_L', 'Ciudad', 'Local']].drop_duplicates().sort_values(by=['Ciudad', 'Local'])
    
    # Hacer C_L invisible en el display
    tiendas_df['display'] = tiendas_df['Ciudad'].str[5:] + '-' + tiendas_df['Local']
    
    # Crear mapa de display a C_L para el filtrado
    mapa_display_cl = pd.Series(tiendas_df.C_L.values, index=tiendas_df.display).to_dict()
    lista_tiendas_display = tiendas_df['display'].tolist()

    # Crear el popover con el radio button para seleccionar la tienda
    with st.popover("Seleccione una Tienda para analizar"):
        tienda_display_seleccionada = st.radio(
            "Tiendas",
            lista_tiendas_display,
            index=0,
            label_visibility="collapsed"
        )
    
    st.header(f"Resumen: {tienda_display_seleccionada}")

    if not tienda_display_seleccionada:
        st.warning("Por favor, seleccione una tienda.")
        return

    # Obtener el C_L de la tienda seleccionada usando el mapa
    cl_seleccionado = mapa_display_cl[tienda_display_seleccionada]

    # --- 2. FILTRAR DATAFRAMES POR TIENDA SELECCIONADA (usando C_L) ---
    df_tienda_local = df_tienda[df_tienda['C_L'] == cl_seleccionado].copy()
    df_color_local = df_color[df_color['C_L'] == cl_seleccionado].copy()
    df_talla_local = df_talla[df_talla['C_L'] == cl_seleccionado].copy()

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
    df_tienda_local = df_tienda_local.sort_values(by=['sort_key', 'C_L', 'Local', 'Ciudad', 'Marca', 'Tipo_Programa', 'Fit_Estilo', 'Semanas'],ascending=[True, True, True, True, True, False, True, True])
    df_tienda_local = df_tienda_local.drop(columns=['sort_key'])

    # --- TABLA DE DETALLE ---
    st.subheader("Detalle de Ventas y Stock")
    if not df_tienda_local.empty:
        max_semana = df_tienda_local['Semanas'].max()
        st.dataframe(
            df_tienda_local[['Marca','Tipo_Programa','Fit_Estilo','Semanas','Cant_Venta','Cant_Stock','PVP_Prom','Sem_Evac']]
            .rename(columns={'Cant_Venta': 'Vnt','Cant_Stock': 'Stk','PVP_Prom': 'PVP','Sem_Evac': 'S_Evc'})
            .style.apply(resaltar_fila_max_semana, semmax=max_semana, axis=1)
            .highlight_max(subset=['Vnt'], color='#FFFF93')
            .apply(lambda x: highlight_min_non_zero(x, color='#FFFF93'), subset=['S_Evc'])
            .apply(lambda x: highlight_min_non_zero(x, color='#F8D7DA'), subset=['Vnt'])
            .highlight_max(subset=['S_Evc'], color='#F8D7DA')
            .format({'Vnt': '{:,.0f}','Stk': '{:,.0f}','PVP': '$ {:,.0f}','S_Evc': '{:.1f}'}),
            height=400, hide_index=True, 
            width='stretch'
        )
    else:
        st.warning("No hay datos de detalle para esta tienda con los filtros seleccionados.")

    st.divider()
    
    # --- GRÁFICOS ---
    col_grafico_color, col_grafico_talla = st.columns(2)

    with col_grafico_color:
        if not df_color_local.empty:
            df_color_chart = df_color_local.groupby(['COLOR', 'Color_Hexa']).agg({'Cant_Venta': 'sum', 'Cant_Stock': 'sum'}).reset_index()
            df_color_chart['Total_Unidades'] = df_color_chart['Cant_Venta'] + df_color_chart['Cant_Stock']
            total_unidades_color = df_color_chart['Total_Unidades'].sum()
            df_color_chart['%_Participacion_Total'] = (df_color_chart['Total_Unidades'] / total_unidades_color) * 100 if total_unidades_color > 0 else 0
            df_color_chart = df_color_chart[df_color_chart['%_Participacion_Total'] >= slider_participacion]

            T_Venta_Color = df_color_chart['Cant_Venta'].sum()
            T_Stock_Color = df_color_chart['Cant_Stock'].sum()
            df_color_chart['%_Participacion_Venta'] = (df_color_chart['Cant_Venta'] / T_Venta_Color) * 100 if T_Venta_Color else 0
            df_color_chart['%_Participacion_Stock'] = (df_color_chart['Cant_Stock'] / T_Stock_Color) * 100 if T_Stock_Color else 0
            
            fig_color = GBD.crear_grafica_barra_doble_horizontal(dataframe=df_color_chart, eje_y_col='COLOR', eje_x_col1='%_Participacion_Venta', eje_x_col2='%_Participacion_Stock', color_hex_col='Color_Hexa', custom_data_col1='Cant_Venta', custom_data_col2='Cant_Stock', titulo="Participación por Talla", nombre_barra1="% Venta", nombre_barra2="% Stock", height=800)
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
            df_talla_chart['%_Participacion_Venta'] = (df_talla_chart['Cant_Venta'] / T_Venta_Talla) * 100 if T_Venta_Talla else 0
            df_talla_chart['%_Participacion_Stock'] = (df_talla_chart['Cant_Stock'] / T_Stock_Talla) * 100 if T_Stock_Talla else 0
            df_talla_chart = df_talla_chart.sort_values(by='Talla')

            fig_talla = GBDT.crear_grafica_barra_doble_horizontal(dataframe=df_talla_chart, eje_y_col='Talla', eje_x_col1='%_Participacion_Venta', eje_x_col2='%_Participacion_Stock', custom_data_col1='Cant_Venta', custom_data_col2='Cant_Stock', titulo="Participación por Talla", nombre_barra1="% Venta", nombre_barra2="% Stock", height=800)
            st.plotly_chart(fig_talla, use_container_width=True, config={'scrollZoom': False, 'displayModeBar': False})
        else:
            st.warning("No hay datos de talla para esta tienda.")
