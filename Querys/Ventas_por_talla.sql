DECLARE @fecha_inicio DATE = ?;
DECLARE @fecha_fin DATE = ?;
DECLARE @fecha_inicio_stock DATE = ?; -- El inicio del rango de stock

Select
    syv.Ini_Cliente,
    syv.Tipo_Programa,
    syv.C_L,
    syv.Local,
    syv.Ciudad,
    syv.Marca,
    syv.Semanas,
    syv.Fit_Estilo,
	CONCAT(syv.COLOR ,'-', syv.C_Color) as 'COLOR',
    syv.Talla,
    SUM(syv.Cant_Venta) as 'Cant_Venta',
    SUM(syv.Cant_Stock) as 'Cant_Stock'
From (
    -- Stock
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
        FORMAT(SEM.DIA_FIN, 'yyyy-MM-dd') + ' Sem ' + FORMAT(SEM.N_SEM,'00') as 'Semanas',
        M.FIT AS 'Fit_Estilo',
		CO.COLOR,
        EC.COD_COLOR as 'C_Color',
        EC.TALLA as 'Talla',
        NULL AS 'Cant_Venta',
        ST.CANT AS 'Cant_Stock'
    FROM [DWH_INCO].[dbo].DWH_Stock AS ST
    LEFT JOIN [DWH_INCO].[dbo].[CAT_SKU] AS EC ON ST.EAN = EC.EAN
	LEFT JOIN [DWH_INCO].[dbo].[COD_COLOR] as CO on EC.COD_COLOR = CO.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].[MONITOREO] AS M ON EC.REF_MODELO = M.MODELO and  EC.MARCA = M.MARCA
    LEFT JOIN [DWH_INCO].[dbo].TIENDAS AS T ON ST.NUM_LOCAL = T.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].MARCA AS MA ON EC.MARCA = MA.MARCA_BD
    LEFT JOIN [DWH_INCO].[dbo].SEMANAS AS SEM ON CAST(ST.FECHA as date) BETWEEN SEM.DIA_INICIO AND SEM.DIA_FIN
    LEFT JOIN [DWH_INCO].[dbo].TIPO_PROGRAMA AS TP ON ST.INI_CLIENTE = TP.INI_CLIENTE AND EC.MARCA = TP.MARCA and M.TIPO = TP.TIPO
    
    WHERE ST.INI_CLIENTE = 'FL' and T.TIPO = 'TIENDA' and ISNULL(TP.ACTIVO,1) = 1
    and ST.FECHA between @fecha_inicio_stock and @fecha_fin


    UNION ALL

    -- Ventas
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
        FORMAT(SEM.DIA_FIN, 'yyyy-MM-dd') + ' Sem ' + FORMAT(SEM.N_SEM,'00') as 'Semanas',
        M.FIT AS 'Fit_Estilo',
		CO.COLOR,
        EC.COD_COLOR as 'C_Color',
        EC.TALLA as 'Talla',
        VT.CANT as 'Cant_Venta',
        0 AS 'Cant_Stock'
    FROM [DWH_INCO].[dbo].[DWH_Ventas] VT
    LEFT JOIN [DWH_INCO].[dbo].[CAT_SKU] AS EC ON VT.EAN = EC.EAN
	LEFT JOIN [DWH_INCO].[dbo].[COD_COLOR] as CO on EC.COD_COLOR = CO.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].[MONITOREO] AS M ON EC.REF_MODELO = M.MODELO and  EC.MARCA = M.MARCA
    LEFT JOIN [DWH_INCO].[dbo].TIENDAS AS T ON VT.NUM_LOCAL = T.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].MARCA AS MA ON EC.MARCA = MA.MARCA_BD
    LEFT JOIN [DWH_INCO].[dbo].SEMANAS AS SEM ON CAST(VT.FECHA as date) BETWEEN SEM.DIA_INICIO AND SEM.DIA_FIN
    LEFT JOIN [DWH_INCO].[dbo].TIPO_PROGRAMA AS TP ON VT.INI_CLIENTE = TP.INI_CLIENTE AND EC.MARCA = TP.MARCA and M.TIPO = TP.TIPO

    WHERE VT.INI_CLIENTE = 'FL' and T.TIPO = 'TIENDA' and ISNULL(TP.ACTIVO,1) = 1
    and VT.FECHA between @fecha_inicio and @fecha_fin

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
	CONCAT(syv.COLOR ,'-', syv.C_Color),
    syv.Talla

