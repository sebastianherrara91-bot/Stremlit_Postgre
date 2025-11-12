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
    DB_DATABASE = os.getenv("DB_DATABASE")
    DB_USER = os.getenv("DB_USER")
    DB_PASSWORD = os.getenv("DB_PASSWORD")

    # Validar que todas las credenciales se hayan cargado
    if not all([DB_SERVER, DB_DATABASE, DB_USER, DB_PASSWORD]):
        st.error("Error de configuración: Faltan una o más credenciales de la base de datos en el archivo .env. Por favor, créelo en el servidor.")
        return None

    quoted_pwd = urllib.parse.quote_plus(DB_PASSWORD)

    # Lista de cadenas de conexión a probar
    connection_strings_to_try = [
        (f"mssql+pyodbc://{DB_USER}:{quoted_pwd}@{DB_SERVER}/{DB_DATABASE}?driver=ODBC+Driver+18+for+SQL+Server&TrustServerCertificate=yes", "Linux"),
        (f"mssql+pyodbc://{DB_USER}:{quoted_pwd}@{DB_SERVER}/{DB_DATABASE}?driver=SQL+Server", "Windows")
    ]

    error_messages = []
    for conn_str, config_type in connection_strings_to_try:
        try:
            print(f"Intentando conectar con la configuración de {config_type}...")
            engine = create_engine(conn_str, connect_args={"timeout": 5})
            with engine.connect():
                print(f"¡Conexión exitosa con la configuración de {config_type}!")
                return engine
        except Exception as e:
            error_str = f"Falló el intento con '{config_type}': {e}"
            print(error_str + "\n")
            error_messages.append(error_str)

    if error_messages:
        full_error_message = "No se pudo conectar a la base de datos. Se intentaron las siguientes configuraciones:\n\n" + "\n\n".join(error_messages)
        st.error(full_error_message)
    
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

def obtener_datos_desde_sql(conexion, consulta_sql, params=None):
    """Ejecuta una consulta SQL y devuelve un DataFrame"""
    try:
        return pd.read_sql(consulta_sql, conexion, params=params)
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
