DECLARE @fecha_inicio DATE = ?;
DECLARE @fecha_fin DATE = ?;
DECLARE @fecha_inicio_stock DATE = ?; -- El inicio del rango de stock
DECLARE @ini_cliente VARCHAR(10) = ?;

Select
    syv.Ini_Cliente,
    syv.C_L,
    syv.Local,
    syv.Ciudad,
    syv.Marca,
    syv.Tipo_Programa,
    syv.Fit_Estilo,
    syv.Semanas,
    SUM(syv.Cant_Venta) as 'Cant_Venta',
    SUM(syv.Cant_Stock) as 'Cant_Stock',
    ROUND(CASE WHEN SUM(syv.Cant_Venta) = 0 THEN 0 ELSE SUM(syv.PVP_x_Venta) / SUM(syv.Cant_Venta) END, 0) as 'PVP_Prom'
From (
    SELECT
        ST.INI_CLIENTE AS 'Ini_Cliente',
        ST.NUM_LOCAL AS 'C_L',
        T.LOCAL AS 'Local',
        T.CIUDAD AS 'Ciudad',
        CASE
            WHEN SUBSTRING(EC.CATEGORIA,1,7) = 'J090103' THEN 'YAMP B'
            WHEN SUBSTRING(EC.CATEGORIA,1,7) = 'J090303' THEN 'YAMP G'
            WHEN SUBSTRING(EC.CATEGORIA,1,7) = 'J090504' THEN 'YAMP BEBA'
            WHEN SUBSTRING(EC.CATEGORIA,1,7) = 'J090503' THEN 'YAMP BEBO'
            ELSE ISNULL(MA.NEW_MARCA, EC.MARCA )
        END AS 'Marca',
        M.TIPO AS 'Tipo_Programa',
        M.FIT AS 'Fit_Estilo',
        FORMAT(SEM.DIA_FIN, 'yyyy-MM-dd') + ' Sem ' + FORMAT(SEM.N_SEM,'00') as 'Semanas',
        NULL AS 'Cant_Venta',
        ST.CANT AS 'Cant_Stock',
        NULL AS 'PVP_x_Venta' -- No aplica para stock
    FROM [DWH_INCO].[dbo].DWH_Stock AS ST
    LEFT JOIN [DWH_INCO].[dbo].[CAT_SKU] AS EC ON ST.EAN = EC.EAN
    LEFT JOIN [DWH_INCO].[dbo].[MONITOREO] AS M ON EC.REF_MODELO = M.MODELO and  EC.MARCA = M.MARCA
    LEFT JOIN [DWH_INCO].[dbo].TIENDAS AS T ON ST.NUM_LOCAL = T.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].MARCA AS MA ON EC.MARCA = MA.MARCA_BD
    LEFT JOIN [DWH_INCO].[dbo].SEMANAS AS SEM ON CAST(ST.FECHA as date) BETWEEN SEM.DIA_INICIO AND SEM.DIA_FIN
    LEFT JOIN [DWH_INCO].[dbo].TIPO_PROGRAMA AS TP ON ST.INI_CLIENTE = TP.INI_CLIENTE AND EC.MARCA = TP.MARCA and M.TIPO = TP.TIPO

    WHERE ST.INI_CLIENTE = @ini_cliente and T.TIPO = 'TIENDA' and ISNULL(TP.ACTIVO,1) = 1
    and ST.FECHA between @fecha_inicio_stock and @fecha_fin

    UNION ALL

    SELECT
        VT.INI_CLIENTE AS 'Ini_Cliente',
        VT.NUM_LOCAL AS 'C_L',
        T.LOCAL AS 'Local',
        T.CIUDAD AS 'Ciudad',
        CASE
            WHEN SUBSTRING(EC.CATEGORIA,1,7) = 'J090103' THEN 'YAMP B'
            WHEN SUBSTRING(EC.CATEGORIA,1,7) = 'J090303' THEN 'YAMP G'
            WHEN SUBSTRING(EC.CATEGORIA,1,7) = 'J090504' THEN 'YAMP BEBA'
            WHEN SUBSTRING(EC.CATEGORIA,1,7) = 'J090503' THEN 'YAMP BEBO'
            ELSE ISNULL(MA.NEW_MARCA, EC.MARCA )
        END AS 'Marca',
        M.TIPO AS 'Tipo_Programa',
        M.FIT AS 'Fit_Estilo',
        FORMAT(SEM.DIA_FIN, 'yyyy-MM-dd') + ' Sem ' + FORMAT(SEM.N_SEM,'00') as 'Semanas',
        VT.CANT as 'Cant_Venta',
        0 AS 'Cant_Stock',
        VT.CANT * NULLIF(VT.PVP_UNIT,0) as 'PVP_x_Venta' -- Pre-calculamos el total para el promedio ponderado
    FROM [DWH_INCO].[dbo].[DWH_Ventas] VT
    LEFT JOIN [DWH_INCO].[dbo].[CAT_SKU] AS EC ON VT.EAN = EC.EAN
    LEFT JOIN [DWH_INCO].[dbo].[MONITOREO] AS M ON EC.REF_MODELO = M.MODELO and  EC.MARCA = M.MARCA
    LEFT JOIN [DWH_INCO].[dbo].TIENDAS AS T ON VT.NUM_LOCAL = T.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].MARCA AS MA ON EC.MARCA = MA.MARCA_BD
    LEFT JOIN [DWH_INCO].[dbo].SEMANAS AS SEM ON CAST(VT.FECHA as date) BETWEEN SEM.DIA_INICIO AND SEM.DIA_FIN
    LEFT JOIN [DWH_INCO].[dbo].TIPO_PROGRAMA AS TP ON VT.INI_CLIENTE = TP.INI_CLIENTE AND EC.MARCA = TP.MARCA and M.TIPO = TP.TIPO
    
    WHERE VT.INI_CLIENTE = @ini_cliente and T.TIPO = 'TIENDA' and ISNULL(TP.ACTIVO,1) = 1
    and VT.FECHA between @fecha_inicio and @fecha_fin

) as syv
GROUP BY
    syv.Ini_Cliente,
    syv.C_L,
    syv.Local,
    syv.Ciudad,
    syv.Marca,
    syv.Tipo_Programa,
    syv.Fit_Estilo,
    syv.Semanas
