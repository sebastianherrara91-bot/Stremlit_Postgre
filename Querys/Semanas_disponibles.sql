WITH WeekData AS (
    SELECT DISTINCT
        SEM.DIA_FIN,
        SEM.N_SEM
    FROM 
        [DWH_INCO].[dbo].[DWH_Ventas] VT
    JOIN
        [DWH_INCO].[dbo].SEMANAS AS SEM ON CAST(VT.FECHA as date) BETWEEN SEM.DIA_INICIO AND SEM.DIA_FIN
)
SELECT 
    FORMAT(DIA_FIN, 'yyyy-MM-dd') + ' Sem ' + FORMAT(N_SEM,'00') AS SemanaFormateada,
    DIA_FIN AS FinSemana
FROM 
    WeekData
ORDER BY 
    DIA_FIN DESC;