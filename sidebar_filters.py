import streamlit as st




def get_filter_selections(df):
    """
    Renderiza los filtros de la barra lateral y devuelve las selecciones del usuario.
    """
    #st.sidebar.header("Filtros Dinámicos")
    selections = {}

    # Configuración de filtros
    filtros_selectbox = [
        ("Cliente", "Ini_Cliente", False),
        ("Tipo Programa", "Tipo_Programa", True),
        ("Marca", "Marca", False)
    ]
    filtros_multiselect = [
        ("Fit Estilo", "Fit_Estilo", True),
        ("Semanas", "Semanas", True)
    ]

    # Renderizar y capturar selecciones
    st.sidebar.divider()
    st.sidebar.subheader("Filtros")
    for titulo, columna, orden in filtros_selectbox:
        with st.sidebar.popover(titulo, use_container_width=True):
            opciones = ['Todos'] + sorted(list(map(str, df[columna].unique())), reverse=orden)
            seleccion = st.radio("titulo", opciones, key=f"sb_{columna}",label_visibility="collapsed")
            if seleccion != 'Todos':
                selections[columna] = seleccion

    #st.sidebar.subheader("Filtros Adicionales")
    st.sidebar.divider()
    for titulo, columna, orden in filtros_multiselect:
        opciones = sorted(list(map(str, df[columna].unique())), reverse=orden)
        selecciones_multi = st.sidebar.multiselect(titulo, opciones, key=f"ms_{columna}")
        if selecciones_multi:
            selections[columna] = selecciones_multi
            
    return selections

def apply_filters(df, selections):
    """
    Aplica un diccionario de selecciones a un dataframe.
    """
    df_filtrado = df.copy()
    for column, value in selections.items():
        if isinstance(value, list):
            df_filtrado = df_filtrado[df_filtrado[column].isin(value)]
        else:
            df_filtrado = df_filtrado[df_filtrado[column] == value]
    return df_filtrado