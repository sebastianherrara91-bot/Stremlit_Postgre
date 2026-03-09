# Project Overview: DashInco (PostgreSQL Version)

This project is a data analysis and visualization web application built with Python. It uses **Streamlit** to create an interactive dashboard for checking sales performance, inventory turnover (sell-through), and participation per colors/sizes. The application fetches data from a **PostgreSQL** database, processes it with Pandas, and displays interactive visuals with Plotly.

## Main Technologies

- **Backend:** Python
- **Frontend:** Streamlit 1.50.0 (Responsive `width='stretch'` layouts)
- **Data Manipulation:** Pandas & NumPy
- **Database:** PostgreSQL (via `psycopg2-binary` and `sqlalchemy`)
- **Visualization:** Plotly & AgGrid
- **Hosting/Execution Environment:** Windows local development, Ubuntu 22.04 LTS Container (Proxmox/LXC) for production.

## Architecture & Code Highlights

- `init.py`: The **main entry point** to run the app. It manages Sidebar selections, global filters, and uses **concurrent parallelism** (`concurrent.futures.ThreadPoolExecutor`) to dispatch heavy queries simultaneously, greatly minimizing waiting times for the dashboards.
- Modules: Dedicated dashboard sections handled in separate files like `MD_Resumen_Tienda.py`, `MD_Ventas_por_color.py`, `MD_Ventas_por_talla.py`, `MD_Ventas_Sem_Ano.py`. Exports functionality is handled by `excel_exporter.py`.
- `GestorSQL.py`: A data access layer handling the dynamic connection to PostgreSQL. It checks `os.name` to optionally vary driver strings, masks credentials loaded via `python-dotenv`, and uses `SQLAlchemy` mapping with Python dictionaries to securely inject parameters using `CAST(:param AS TYPE)` standard logic.
- `Querys/`: Directory housing `.sql` files. These queries have been migrated from SQL Server logic to PostgreSQL natively (e.g. usage of `date_trunc`, `interval`, native min/max boundary search avoiding intense nested loops on large tables like `dwh_ventas`).
- `.env`: The central hub for connection secrets containing `DB_SERVER`, `DB_PORT`, `DB_DATABASE`, `DB_USER` and `DB_PASSWORD`. This path is tracked via `.gitignore` to prevent exposure.

## Deploy instructions (LXC Ubuntu/Proxmox)

A detailed file `Despliegue_Contenedor_Ubuntu22.txt` resides in the main root outlining exact proxy integration with `Nginx` and `systemd` daemon handling for the App.

The application logic updates in production using mapped GitHub repositories under branch `Stremlit_Postgre`.

**Main bridge deployment run (Refresh env):**

```bash
cd /opt/DashInco && git remote set-url origin https://github.com/sebastianherrara91-bot/Stremlit_Postgre.git && git fetch origin && git reset --hard origin/main && rm -rf venv && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt && deactivate && sudo systemctl restart streamlit.service
```

**Standard daily deployment command:**

```bash
cd /opt/DashInco && git pull origin main && source venv/bin/activate && pip install -r requirements.txt && deactivate && sudo systemctl restart streamlit.service
```
