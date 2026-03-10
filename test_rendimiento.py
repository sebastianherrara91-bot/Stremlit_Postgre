import time
import os
import datetime
import pandas as pd
import GestorSQL as GSQL
from sqlalchemy import text
from concurrent.futures import ThreadPoolExecutor

def probar_query_explain(nombre_archivo, params, log_file):
    """
    Toma una consulta, le añade EXPLAIN (ANALYZE, BUFFERS),
    la ejecuta y la escribe en un archivo log_file.
    """
    print(f"[*] Ejecutando {nombre_archivo}...")
    
    # Cargar el SQL original
    query_original = GSQL.cargar_consulta_sql(nombre_archivo)
    if not query_original:
        print(f"[!] Error: No se pudo cargar {nombre_archivo}")
        return

    # Añadir EXPLAIN (ANALYZE, BUFFERS) al inicio
    query_explain = "EXPLAIN (ANALYZE, BUFFERS)\n" + query_original
    
    engine = GSQL.get_connection()
    if engine is None:
        print("[!] Error: No hay conexión a la base de datos.")
        return

    inicio = time.time()
    try:
        if params:
            # pd.read_sql ejecuta el query y nos devuelve las lineas del plan de ejecución como DataFrame
            df_explain = pd.read_sql(text(query_explain), engine, params=params)
        else:
            df_explain = pd.read_sql(text(query_explain), engine)
    except Exception as e:
        error_msg = f"[!] Error al ejecutar {nombre_archivo}: {str(e)}"
        print(error_msg)
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(error_msg + "\n")
        return
        
    fin = time.time()
    tiempo_total_app = fin - inicio
    
    # Extraer el texto del plan
    # SQLAlchemy normalmente devuelve una única columna llamada "QUERY PLAN"
    plan_lines = df_explain.iloc[:, 0].astype(str).tolist()
    plan_text = "\n".join(plan_lines)

    # Escribir en el log de manera segura (con append 'a')
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(f"============================================================\n")
        f.write(f"[*] QUERY: {nombre_archivo}\n")
        f.write(f"[*] TIEMPO TOTAL DESDE PYTHON: {tiempo_total_app:.2f} segundos\n")
        f.write(f"============================================================\n")
        f.write(plan_text + "\n\n")

    print(f"[+] Completado {nombre_archivo} en {tiempo_total_app:.2f} s.")

if __name__ == "__main__":
    # --- 1. CONFIGURACIÓN DE PARÁMETROS REALES PARA LA PRUEBA ---
    # AJUSTA estos valores para que coincidan con algo que un usuario buscaría realmente
    fecha_inicio_prueba = datetime.date(2026, 2, 1)
    fecha_fin_prueba = datetime.date(2026, 3, 8)
    cliente_prueba = 'FL' # Cambia esto por un cliente real de tu BD
    umbral_stock_prueba = 800

    params_test = {
        'fecha_inicio_venta': fecha_inicio_prueba,
        'fecha_fin_venta': fecha_fin_prueba,
        'fecha_inicio_stock': fecha_inicio_prueba,
        'ini_cliente': cliente_prueba,
        'stock_threshold': umbral_stock_prueba,
        'semanas_stock': 8,
        'semanas_venta': 8,
        # Si tienes consultas que piden solo 'fecha_inicio' en vez de 'fecha_inicio_venta', las agrupamos:
        'fecha_inicio': fecha_inicio_prueba,
        'fecha_fin': fecha_fin_prueba,
    }

    # queries a testear
    queries_a_evaluar = [
        "Ventas_por_tienda.sql",
        "Ventas_por_talla.sql",
        "Ventas_por_color.sql",
        "Ventas_StockUltsem.sql",
        "Ventas_Sem_Ano.sql",
        "Ventas_Stock_8Sem.sql"
    ]

    # Nombre del archivo log en la carpeta logs_rendimiento
    os.makedirs("logs_rendimiento", exist_ok=True)
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    log_filename = f"logs_rendimiento/rendimiento_queries_{timestamp}.log"
    
    # Escribir cabecera del log
    with open(log_filename, "w", encoding="utf-8") as f:
        f.write(f"REPORTE DE RENDIMIENTO EXPLAIN (ANALYZE, BUFFERS) DASHINCO\n")
        f.write(f"Generado el: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Parámetros usados: {params_test}\n\n")

    print(f"[*] Iniciando prueba de estrés en paralelo (Log: {log_filename}) ...\n")
    tiempo_total_inicio = time.time()

    # --- 2. EJECUCIÓN EN PARALELO IGUAL QUE LA APP ---
    # max_workers=5 significa que lanzará hasta 5 consultas AL MISMO TIEMPO a Postgres
    with ThreadPoolExecutor(max_workers=5) as executor:
        futuros = []
        for q in queries_a_evaluar:
            futuros.append(executor.submit(probar_query_explain, q, params_test, log_filename))
        
        # Esperamos a que todos los hilos terminen
        for f in futuros:
            f.result()

    tiempo_total_fin = time.time()
    print(f"\n[*] PRUEBA FINALIZADA. Tiempo total de carga paralela: {tiempo_total_fin - tiempo_total_inicio:.2f} segundos")
    print(f"[*] Revisa los detalles en el archivo: {log_filename}")
