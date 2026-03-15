WITH Valid_Marca_Tipo AS (
    SELECT
        COALESCE(MS.marca, MA.new_marca, EC.marca) AS vmt_marca,
        M.tipo AS vmt_tipo
    FROM dbo.dwh_stock AS ST
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.marca_subclase AS MS ON ST.ini_cliente = MS.ini_cliente 
        AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    WHERE ST.ini_cliente = :ini_cliente
      AND ST.fecha = (date_trunc('week', current_date))::date
    GROUP BY 1, 2
    HAVING SUM(ST.cant) >= :stock_threshold
)
SELECT
    syv.ini_cliente AS "Ini_Cliente"
    ,syv.c_l AS "C_L"
    ,syv.local AS "Local"
    ,syv.ean AS "EAN"
    ,syv.sku AS "SKU"
    ,syv.modelo AS "Modelo"
    ,syv.marca AS "Marca"
    ,syv.tipo_programa AS "Tipo_Programa"
    ,syv.fecha AS "Fecha"
    ,to_char(syv.fecha, 'YY') || '/' || to_char(syv.n_sem, 'FM00') || ' - ' || to_char(syv.fecha, 'MM/DD') as "Semanas"
    ,SUM(syv.cant_v) as "Cant_Venta"
    ,SUM(syv.cant_s) as "Cant_Stock"
    ,CASE WHEN SUM(syv.cant_v) = 0 THEN NULL ELSE ROUND(SUM(syv.cant_v * syv.pvp)/NULLIF(SUM(syv.cant_v),0),0) END as "PVP_Prom"
FROM (
    SELECT
        ST.ini_cliente
        ,ST.num_local as c_l
        ,T.local
        ,ST.ean
        ,EC.sku
        ,EC.ref_modelo as modelo
        ,VMT.vmt_marca as marca
        ,M.tipo as tipo_programa
        ,(date_trunc('week', ST.fecha))::date as fecha
        ,SEM.n_sem
        ,SEM.ano
        ,0 as cant_v
        ,ST.cant as cant_s
        ,0 as pvp
    FROM dbo.dwh_stock AS ST
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.tiendas AS T ON ST.num_local = T.codigo AND T.ini_cliente = ST.ini_cliente
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca_subclase AS MS ON ST.ini_cliente = MS.ini_cliente AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    INNER JOIN Valid_Marca_Tipo VMT ON VMT.vmt_tipo = M.tipo 
        AND VMT.vmt_marca = COALESCE(MS.marca, MA.new_marca, EC.marca)
    LEFT JOIN dbo.semanas SEM ON (date_trunc('week', ST.fecha))::date = SEM.dia_inicio
    WHERE ST.ini_cliente = :ini_cliente 
      AND ST.fecha BETWEEN ((date_trunc('week', current_date))::date - interval '8 weeks')::date AND (date_trunc('week', current_date))::date
    
    UNION ALL

    SELECT
        VT.ini_cliente
        ,VT.num_local as c_l
        ,T.local
        ,VT.ean
        ,EC.sku
        ,EC.ref_modelo as modelo
        ,VMT.vmt_marca as marca
        ,M.tipo as tipo_programa
        ,(date_trunc('week', VT.fecha))::date as fecha
        ,SEM.n_sem
        ,SEM.ano
        ,VT.cant as cant_v
        ,0 as cant_s
        ,VT.pvp_unit as pvp
    FROM dbo.dwh_ventas AS VT
    LEFT JOIN dbo.cat_sku AS EC ON VT.ean = EC.ean
    LEFT JOIN dbo.tiendas AS T ON VT.num_local = T.codigo AND T.ini_cliente = VT.ini_cliente
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca_subclase AS MS ON VT.ini_cliente = MS.ini_cliente AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    INNER JOIN Valid_Marca_Tipo VMT ON VMT.vmt_tipo = M.tipo 
        AND VMT.vmt_marca = COALESCE(MS.marca, MA.new_marca, EC.marca)
    LEFT JOIN dbo.semanas SEM ON (date_trunc('week', VT.fecha))::date = SEM.dia_inicio
    WHERE VT.ini_cliente = :ini_cliente 
      AND VT.fecha BETWEEN ((date_trunc('week', current_date))::date - interval '8 weeks')::date AND (date_trunc('week', current_date))::date
) syv

GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10;