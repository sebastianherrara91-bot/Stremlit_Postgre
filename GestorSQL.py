from sqlalchemy import create_engine
import pandas as pd
import streamlit as st
from pathlib import Path
import urllib
import os
from dotenv import load_dotenv

# Cargar las variables de entorno desde el archivo .env
load_dotenv()

def get_connection():
    # Cargar credenciales desde las variables de entorno
    DB_SERVER = os.getenv("DB_SERVER")
    DB_PORT = os.getenv("DB_PORT", "5432")
    DB_DATABASE = os.getenv("DB_DATABASE")
    DB_USER = os.getenv("DB_USER")
    DB_PASSWORD = os.getenv("DB_PASSWORD")

    # Validar que todas las credenciales se hayan cargado
    if not all([DB_SERVER, DB_PORT, DB_DATABASE, DB_USER, DB_PASSWORD]):
        st.error("Error de configuración: Faltan una o más credenciales de la base de datos en el archivo .env.")
        return None

    quoted_pwd = urllib.parse.quote_plus(DB_PASSWORD)

    # Identificamos el sistema operativo
    os_name = "Windows" if os.name == "nt" else "Ubuntu/Linux"

    # En Postgres no hay tanta dependencia de Driver ODBC, pero manejamos la lógica condicional pedida
    if os_name == "Windows":
        conn_str = f"postgresql+psycopg2://{DB_USER}:{quoted_pwd}@{DB_SERVER}:{DB_PORT}/{DB_DATABASE}"
    else:
        conn_str = f"postgresql+psycopg2://{DB_USER}:{quoted_pwd}@{DB_SERVER}:{DB_PORT}/{DB_DATABASE}"

    try:
        engine = create_engine(conn_str, connect_args={"connect_timeout": 5})
        with engine.connect():
            return engine
    except Exception as e:
        error_str = f"Falló el intento de conexión en {os_name}: {e}"
        print(error_str + "\n")
        st.error(error_str)
    
    return None

def test_connection():
    """Función para probar la conexión"""
    try:
        engine = get_connection()
        if engine:
            return True
        else:
            return False
    except Exception as e:
        st.error(f"Error al conectar a la base de datos: {str(e)}")
        return False

def cargar_consulta_sql(nombre_archivo):
    """Carga una consulta SQL desde un archivo .sql"""
    try:
        ruta_archivo = Path(__file__).parent / "Querys" / nombre_archivo
        with open(ruta_archivo, 'r', encoding='utf-8') as f:
            return f.read()
    except Exception as e:
        st.error(f"Error al cargar la consulta SQL: {str(e)}")
        return ""

from sqlalchemy import text

def obtener_datos_desde_sql(conexion, consulta_sql, params=None):
    """Ejecuta una consulta SQL y devuelve un DataFrame"""
    try:
        if params:
            return pd.read_sql(text(consulta_sql), conexion, params=params)
        else:
            return pd.read_sql(text(consulta_sql), conexion)
    except Exception as e:
        st.error(f"Error al ejecutar la consulta: {str(e)}")
        return pd.DataFrame()

@st.cache_data(ttl=1800)
def get_dataframe(consulta_sql, params=None):
    try:
        engine = get_connection()
        if engine is None:
            # get_connection ya muestra un error detallado
            return pd.DataFrame()
        
        query = cargar_consulta_sql(consulta_sql)
        if not query:
            return pd.DataFrame()
            
        df = obtener_datos_desde_sql(engine, query, params=params)
        return df
        
    except Exception as e:
        st.error(f"Error al obtener datos: {str(e)}")
        return pd.DataFrame()  # Retorna un DataFrame vacío en caso de error

@st.cache_data(ttl=3600)
def get_semanas_disponibles():
    """
    Obtiene las semanas disponibles desde la base de datos, formateadas para los selectbox.
    Retorna un diccionario que mapea la etiqueta de la semana a su fecha de fin real.
    """
    try:
        engine = get_connection()
        if engine is None:
            return {}
        
        query = cargar_consulta_sql("Semanas_disponibles.sql")
        if not query:
            return {}
            
        df_semanas = obtener_datos_desde_sql(engine, query)
        
        if df_semanas.empty:
            return {}

        # Asegurar que la columna de fecha es del tipo datetime para evitar TypeErrors
        df_semanas['FinSemana'] = pd.to_datetime(df_semanas['FinSemana'])

        # Crear un diccionario de 'SemanaFormateada' -> 'FinSemana'
        # Esto es más fácil de usar en el frontend.
        # st.selectbox mostrará las keys, y podremos obtener la fecha (value) fácilmente.
        semanas_dict = pd.Series(df_semanas.FinSemana.values, index=df_semanas.SemanaFormateada).to_dict()
        
        return semanas_dict
        
    except Exception as e:
        st.error(f"Error al obtener la lista de semanas: {str(e)}")
        return {}

@st.cache_data(ttl=3600)
def get_clientes():
    """
    Obtiene una lista de clientes únicos desde la base de datos.
    """
    try:
        engine = get_connection()
        if engine is None:
            return []
        
        query = cargar_consulta_sql("Clientes.sql")
        if not query:
            return []
            
        df_clientes = obtener_datos_desde_sql(engine, query)
        
        if df_clientes.empty:
            return []

        # Devuelve una lista simple de los clientes
        return df_clientes['INI_CLIENTE'].tolist()
        
    except Exception as e:
        st.error(f"Error al obtener la lista de clientes: {str(e)}")
        return []
