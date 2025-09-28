-- Query optimizado para el dashboard de Ventas por Color
-- Agrupa los datos directamente en el servidor para minimizar la transferencia de datos.
-- Trae 8 semanas de ventas y 1 semana de stock.
Select
    syv.Ini_Cliente,
    syv.Tipo_Programa,
    syv.C_L,
    syv.Local,
    syv.Ciudad,
    syv.Marca,
    syv.Semanas,
    syv.Fit_Estilo,
    syv.COLOR,
    syv.C_Color,
    syv.Color_Hexa,
    SUM(syv.Cant_Venta) as 'Cant_Venta',
    SUM(syv.Cant_Stock) as 'Cant_Stock'
From (
    -- Stock (última semana)
    SELECT
        ST.INI_CLIENTE AS 'Ini_Cliente',
        M.TIPO AS 'Tipo_Programa',
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
        CONCAT(FORMAT(SEM.ANO,'yy'),'/',FORMAT(SEM.N_SEM,'00'),' - ',FORMAT(SEM.DIA_INICIO, 'MM/dd')) as 'Semanas',
        M.FIT AS 'Fit_Estilo',
        CO.COLOR,
        EC.COD_COLOR as 'C_Color',
        CO.Color_Hexa,
        NULL AS 'Cant_Venta',
        ST.CANT AS 'Cant_Stock'
    FROM [DWH_INCO].[dbo].DWH_Stock AS ST
    LEFT JOIN [DWH_INCO].[dbo].[CAT_SKU] AS EC ON ST.EAN = EC.EAN
    LEFT JOIN [DWH_INCO].[dbo].[MONITOREO] AS M ON EC.REF_MODELO = M.MODELO and  EC.MARCA = M.MARCA
    LEFT JOIN [DWH_INCO].[dbo].[COD_COLOR] as CO on EC.COD_COLOR = CO.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].TIENDAS AS T ON ST.NUM_LOCAL = T.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].MARCA AS MA ON EC.MARCA = MA.MARCA_BD
    LEFT JOIN [DWH_INCO].[dbo].SEMANAS AS SEM ON DATEADD(day,1 -DATEPART(WEEKDAY,ST.FECHA),CAST(ST.FECHA as date)) = SEM.DIA_INICIO
    WHERE ST.INI_CLIENTE = 'FL' and T.TIPO = 'TIENDA' and st.FECHA between convert(date,DATEADD(day,-(7*(1)),DATEADD(day,-(DATEPART(dw, GETDATE())-2), GETDATE()))) and convert(date,DATEADD(day,-(7*(0)),DATEADD(day,-(DATEPART(dw, GETDATE())-2), GETDATE())))

    UNION ALL

    -- Ventas (últimas 8 semanas)
    SELECT
        VT.INI_CLIENTE AS 'Ini_Cliente',
        M.TIPO AS 'Tipo_Programa',
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
        CONCAT(FORMAT(SEM.ANO,'yy'),'/',FORMAT(SEM.N_SEM,'00'),' - ',FORMAT(SEM.DIA_INICIO, 'MM/dd')) as 'Semanas',
        M.FIT AS 'Fit_Estilo',
        CO.COLOR,
        EC.COD_COLOR as 'C_Color',
        CO.Color_Hexa,
        VT.CANT as 'Cant_Venta',
        0 AS 'Cant_Stock'
    FROM [DWH_INCO].[dbo].[DWH_Ventas] VT
    LEFT JOIN [DWH_INCO].[dbo].[CAT_SKU] AS EC ON VT.EAN = EC.EAN
    LEFT JOIN [DWH_INCO].[dbo].[COD_COLOR] as CO on EC.COD_COLOR = CO.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].[MONITOREO] AS M ON EC.REF_MODELO = M.MODELO and  EC.MARCA = M.MARCA
    LEFT JOIN [DWH_INCO].[dbo].TIENDAS AS T ON VT.NUM_LOCAL = T.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].MARCA AS MA ON EC.MARCA = MA.MARCA_BD
    LEFT JOIN [DWH_INCO].[dbo].SEMANAS AS SEM ON DATEADD(day,1 -DATEPART(WEEKDAY,VT.FECHA),CAST(VT.FECHA as date)) = SEM.DIA_INICIO
    WHERE VT.INI_CLIENTE = 'FL' and T.TIPO = 'TIENDA' and VT.FECHA between convert(date,DATEADD(day,-(7*(8)),DATEADD(day,-(DATEPART(dw, GETDATE())-2), GETDATE()))) and convert(date,DATEADD(day,-(7*(0)),DATEADD(day,-(DATEPART(dw, GETDATE())-2), GETDATE())))
) as syv
GROUP BY
    syv.Ini_Cliente,
    syv.Tipo_Programa,
    syv.C_L,
    syv.Local,
    syv.Ciudad,
    syv.Marca,
    syv.Semanas,
    syv.Fit_Estilo,
    syv.COLOR,
    syv.C_Color,
    syv.Color_Hexa
