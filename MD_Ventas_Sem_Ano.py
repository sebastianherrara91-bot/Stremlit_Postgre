import streamlit as st
import pandas as pd

def main(df, cliente_seleccionado):
    st.subheader("Comparativo Ventas Semanales por Año")

    # --- Filtros ---
    with st.sidebar:
        st.divider()
        st.subheader("Filtros")
        
        # Filtro: Tipo Cliente (Ini_Cliente)
        opciones_cliente = ['Todos'] + sorted(df['Ini_Cliente'].unique().tolist())
        cliente_sel = st.selectbox("Tipo Cliente", opciones_cliente)
        if cliente_sel != 'Todos':
            df = df[df['Ini_Cliente'] == cliente_sel]

        # Filtro: Marca
        opciones_marca = ['Todos'] + sorted(df['Marca'].unique().tolist())
        marca_sel = st.selectbox("Marca", opciones_marca)
        if marca_sel != 'Todos':
            df = df[df['Marca'] == marca_sel]

        # Filtro: Tipo Programa
        opciones_programa = ['Todos'] + sorted(df['Tipo_Programa'].unique().tolist())
        programa_sel = st.selectbox("Tipo Programa", opciones_programa)
        if programa_sel != 'Todos':
            df = df[df['Tipo_Programa'] == programa_sel]

    if df.empty:
        st.warning("No hay datos para los filtros seleccionados.")
        return

    # --- Procesamiento de Datos ---
    # Asegurar tipo fecha
    df['FECHA'] = pd.to_datetime(df['FECHA'])
    df['Dia_Semana'] = df['FECHA'].dt.day_name()
    
    # Mapeo de días a español para ordenamiento y visualización
    dias_map = {
        'Monday': 'Lunes', 'Tuesday': 'Martes', 'Wednesday': 'Miércoles',
        'Thursday': 'Jueves', 'Friday': 'Viernes', 'Saturday': 'Sábado', 'Sunday': 'Domingo'
    }
    df['Dia_ES'] = df['Dia_Semana'].map(dias_map)
    
    # Obtener lista de semanas únicas ordenadas descendentemente
    semanas = sorted(df['N_SEM'].unique(), reverse=True)
    
    for semana in semanas:
        st.markdown(f"### Semana {semana}")
        df_sem = df[df['N_SEM'] == semana]
        
        if df_sem.empty:
            continue

        # Pivotar para tener días como columnas
        pivot_ventas = df_sem.pivot_table(
            index='ANO', 
            columns='Dia_ES', 
            values='Cant_Venta', 
            aggfunc='sum',
            fill_value=0
        )
        
        # Reordenar columnas de días
        orden_dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo']
        for dia in orden_dias:
            if dia not in pivot_ventas.columns:
                pivot_ventas[dia] = 0
        
        pivot_ventas = pivot_ventas[orden_dias]

        # Calcular Stock Inicial y Final para esta semana
        stock_data = []
        for ano in df_sem['ANO'].unique():
            df_ano = df_sem[df_sem['ANO'] == ano]
            if df_ano.empty:
                continue
                
            fechas = sorted(df_ano['FECHA'].unique())
            if not fechas:
                s_ini = 0
                s_fin = 0
            else:
                fecha_ini = fechas[0]
                fecha_fin = fechas[-1]
                s_ini = df_ano[df_ano['FECHA'] == fecha_ini]['Cant_Stock'].sum()
                s_fin = df_ano[df_ano['FECHA'] == fecha_fin]['Cant_Stock'].sum()
                
            stock_data.append({'ANO': ano, 'Stock Inicial': s_ini, 'Stock Final': s_fin})
        
        df_stock = pd.DataFrame(stock_data).set_index('ANO')
        
        # Unir Stock y Ventas
        df_final = df_stock.join(pivot_ventas)
        
        # Calcular Venta Total
        df_final['Venta Total'] = df_final[orden_dias].sum(axis=1)
        
        # Reordenar columnas final
        cols_final = ['Stock Inicial'] + orden_dias + ['Stock Final', 'Venta Total']
        for c in cols_final:
            if c not in df_final.columns:
                df_final[c] = 0
                
        df_final = df_final[cols_final]
        
        # Mostrar tabla
        st.dataframe(df_final.style.format("{:,.0f}"), use_container_width=True)
        
        # Calcular KPI de Crecimiento
        # Asumimos que hay 2 años para comparar. Si hay más o menos, ajustamos.
        anos_presentes = sorted(df_final.index.unique())
        if len(anos_presentes) >= 2:
            ano_actual = anos_presentes[-1] # El mayor año
            ano_anterior = anos_presentes[-2] # El anterior
            
            venta_actual = df_final.loc[ano_actual, 'Venta Total']
            venta_anterior = df_final.loc[ano_anterior, 'Venta Total']
            
            if venta_anterior > 0:
                crecimiento = ((venta_actual - venta_anterior) / venta_anterior) * 100
            else:
                crecimiento = 0 if venta_actual == 0 else 100 # Si no hubo venta anterior y ahora si, 100% (o infinito)
            
            color = "green" if crecimiento >= 0 else "red"
            delta_symbol = "▲" if crecimiento >= 0 else "▼"
            
            st.markdown(f"""
                <div style="text-align: center; padding: 10px; background-color: rgba(0,0,0,0.05); border-radius: 5px; margin-bottom: 20px;">
                    <span style="font-size: 1.2em; font-weight: bold;">Crecimiento vs Año Anterior</span><br>
                    <span style="font-size: 2em; color: {color}; font-weight: bold;">
                        {delta_symbol} {crecimiento:,.1f}%
                    </span>
                </div>
            """, unsafe_allow_html=True)
        else:
            st.info("No hay suficientes datos de años anteriores para calcular crecimiento.")
        
        st.divider()
