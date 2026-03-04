WITH WeekData AS (
    SELECT DISTINCT
        SEM.dia_fin,
        SEM.n_sem
    FROM 
        dbo.dwh_ventas VT
    JOIN
        dbo.semanas AS SEM ON VT.fecha BETWEEN SEM.dia_inicio AND SEM.dia_fin
)
SELECT 
    to_char(dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(n_sem, 'FM00') AS "SemanaFormateada",
    dia_fin AS "FinSemana"
FROM 
    WeekData
ORDER BY 
    dia_fin DESC;