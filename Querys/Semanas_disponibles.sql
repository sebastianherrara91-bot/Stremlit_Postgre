WITH RangoVentas AS (
    SELECT MIN(fecha) as min_fecha, MAX(fecha) as max_fecha
    FROM dbo.dwh_ventas
)
SELECT DISTINCT
    to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') AS "SemanaFormateada",
    SEM.dia_fin AS "FinSemana"
FROM 
    dbo.semanas SEM
CROSS JOIN 
    RangoVentas RV
WHERE 
    SEM.dia_fin >= RV.min_fecha 
    AND SEM.dia_inicio <= RV.max_fecha
ORDER BY 
    "FinSemana" DESC;