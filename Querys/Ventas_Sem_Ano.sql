DECLARE @semanas_stock INT = ?;
DECLARE @semanas_venta INT = ?;

Select
    syv.Ini_Cliente,
    syv.Tipo_Programa,
    syv.C_L,
    concat(SUBSTRING (syv.Ciudad,6,20) ,' - ', syv.Local) as Tienda,    
    syv.Marca,
    syv.FECHA,
	syv.N_SEM,
	syv.ANO,
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
        ST.FECHA,
		SEM.N_SEM,
		SEM.ANO,
        NULL AS 'Cant_Venta',
        ST.CANT AS 'Cant_Stock'
    FROM [DWH_INCO].[dbo].DWH_Stock AS ST
    LEFT JOIN [DWH_INCO].[dbo].[CAT_SKU] AS EC ON ST.EAN = EC.EAN
	LEFT JOIN [DWH_INCO].[dbo].[COD_COLOR] as CO on EC.COD_COLOR = CO.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].[MONITOREO] AS M ON EC.REF_MODELO = M.MODELO and  EC.MARCA = M.MARCA
    LEFT JOIN [DWH_INCO].[dbo].TIENDAS AS T ON ST.NUM_LOCAL = T.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].MARCA AS MA ON EC.MARCA = MA.MARCA_BD
    LEFT JOIN [DWH_INCO].[dbo].SEMANAS AS SEM ON DATEADD(day,1 -DATEPART(WEEKDAY,ST.FECHA),CAST(ST.FECHA as date)) = SEM.DIA_INICIO
    LEFT JOIN [DWH_INCO].[dbo].TIPO_PROGRAMA AS TP ON ST.INI_CLIENTE = TP.INI_CLIENTE AND EC.MARCA = TP.MARCA and M.TIPO = TP.TIPO
    
    WHERE ST.INI_CLIENTE = 'FL' and T.TIPO = 'TIENDA' and ISNULL(TP.ACTIVO,1) = 1
    and 
	(
	ST.FECHA between convert(date,DATEADD(day,-(7*(@semanas_stock)),DATEADD(day,-1,DATEADD(week,DATEDIFF(week,-1,GETDATE()),-1)))) and convert(date,DATEADD(day,-1,DATEADD(week,DATEDIFF(week,-1,GETDATE()),-1)))
	OR ST.FECHA between convert(date,DATEADD(week,-52,DATEADD(day,-(7*(@semanas_stock)),DATEADD(day,-1,DATEADD(week,DATEDIFF(week,-1,GETDATE()),-1))))) and convert(date,DATEADD(week,-52,DATEADD(day,-1,DATEADD(week,DATEDIFF(week,-1,GETDATE()),-1))))
	)
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
        VT.FECHA,
		SEM.N_SEM,
		SEM.ANO,
        VT.CANT as 'Cant_Venta',
        0 AS 'Cant_Stock'
    FROM [DWH_INCO].[dbo].[DWH_Ventas] VT
    LEFT JOIN [DWH_INCO].[dbo].[CAT_SKU] AS EC ON VT.EAN = EC.EAN
	LEFT JOIN [DWH_INCO].[dbo].[COD_COLOR] as CO on EC.COD_COLOR = CO.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].[MONITOREO] AS M ON EC.REF_MODELO = M.MODELO and  EC.MARCA = M.MARCA
    LEFT JOIN [DWH_INCO].[dbo].TIENDAS AS T ON VT.NUM_LOCAL = T.CODIGO
    LEFT JOIN [DWH_INCO].[dbo].MARCA AS MA ON EC.MARCA = MA.MARCA_BD
    LEFT JOIN [DWH_INCO].[dbo].SEMANAS AS SEM ON DATEADD(day,1 -DATEPART(WEEKDAY,VT.FECHA),CAST(VT.FECHA as date)) = SEM.DIA_INICIO
    LEFT JOIN [DWH_INCO].[dbo].TIPO_PROGRAMA AS TP ON VT.INI_CLIENTE = TP.INI_CLIENTE AND EC.MARCA = TP.MARCA and M.TIPO = TP.TIPO

    WHERE VT.INI_CLIENTE = 'FL' and T.TIPO = 'TIENDA' and ISNULL(TP.ACTIVO,1) = 1
    and 
	(
	VT.FECHA between convert(date,DATEADD(day,-(7*(@semanas_venta)),DATEADD(day,-1,DATEADD(week,DATEDIFF(week,-1,GETDATE()),-1)))) and convert(date,DATEADD(day,-1,DATEADD(week,DATEDIFF(week,-1,GETDATE()),-1)))
	OR VT.FECHA between convert(date,DATEADD(week,-52,DATEADD(day,-(7*(@semanas_venta)),DATEADD(day,-1,DATEADD(week,DATEDIFF(week,-1,GETDATE()),-1))))) and convert(date,DATEADD(week,-52,DATEADD(day,-1,DATEADD(week,DATEDIFF(week,-1,GETDATE()),-1))))
	)

) as syv
GROUP BY
    syv.Ini_Cliente,
    syv.Tipo_Programa,
    syv.C_L,
	concat(SUBSTRING (syv.Ciudad,6,20) ,' - ', syv.Local),
    syv.Marca,
    syv.FECHA,
	syv.N_SEM,
	syv.ANO
