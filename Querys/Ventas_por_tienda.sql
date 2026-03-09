WITH Valid_Marca_Tipo AS (
    -- Paso 1: Filtro de productos con stock suficiente
    SELECT
        COALESCE(MS.marca, MA.new_marca, EC.marca) AS vmt_marca,
        M.tipo AS vmt_tipo,
        M.fit AS vmt_fit
    FROM dbo.dwh_stock AS ST
    INNER JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.marca_subclase AS MS 
        ON ST.ini_cliente = MS.ini_cliente 
        AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    LEFT JOIN dbo.tiendas AS T ON ST.num_local = T.codigo
    WHERE ST.ini_cliente = :ini_cliente
      AND ST.fecha = :fecha_fin -- Pruning al cuatrimestre final
      AND T.tipo = 'TIENDA'
    GROUP BY 1, 2, 3
    HAVING SUM(ST.cant) >= :stock_threshold
)

SELECT
    syv.ini_cliente AS "Ini_Cliente",
    syv.c_l AS "C_L",
    syv.local AS "Local",
    syv.ciudad AS "Ciudad",
    syv.marca AS "Marca",
    syv.tipo_programa AS "Tipo_Programa",
    syv.fit_estilo AS "Fit_Estilo",
    syv.semanas AS "Semanas",
    SUM(syv.cant_v) AS "Cant_Venta",
    SUM(syv.cant_s) AS "Cant_Stock",
    -- PVP Promedio Ponderado
    ROUND(CASE 
        WHEN SUM(syv.cant_v) = 0 THEN 0 
        ELSE SUM(syv.pvp_total) / NULLIF(SUM(syv.cant_v), 0) 
    END, 0) AS "PVP_Prom"
FROM (
    -- Bloque Stock
    SELECT
        ST.ini_cliente, ST.num_local AS c_l, T.local, T.ciudad,
        VMT.vmt_marca AS marca, VMT.vmt_tipo AS tipo_programa, VMT.vmt_fit AS fit_estilo,
        to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') AS semanas,
        0 AS cant_v, ST.cant AS cant_s, 0 AS pvp_total
    FROM dbo.dwh_stock ST
    INNER JOIN dbo.cat_sku EC ON ST.ean = EC.ean
    INNER JOIN dbo.tiendas T ON ST.num_local = T.codigo AND T.tipo = 'TIENDA'
    INNER JOIN dbo.monitoreo M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    INNER JOIN Valid_Marca_Tipo VMT ON VMT.vmt_tipo = M.tipo 
        AND VMT.vmt_fit IS NOT DISTINCT FROM M.fit
        AND VMT.vmt_marca = COALESCE(
            (SELECT marca FROM dbo.marca_subclase WHERE ini_cliente = ST.ini_cliente AND subcategoria = substring(EC.categoria from 1 for 7) LIMIT 1),
            (SELECT new_marca FROM dbo.marca WHERE marca_bd = EC.marca LIMIT 1),
            EC.marca
        )
    LEFT JOIN dbo.semanas SEM ON ST.fecha BETWEEN SEM.dia_inicio AND SEM.dia_fin
    WHERE ST.ini_cliente = :ini_cliente 
      AND ST.fecha BETWEEN :fecha_inicio_stock AND :fecha_fin

    UNION ALL

    -- Bloque Ventas
    SELECT
        VT.ini_cliente, VT.num_local AS c_l, T.local, T.ciudad,
        VMT.vmt_marca AS marca, VMT.vmt_tipo AS tipo_programa, VMT.vmt_fit AS fit_estilo,
        to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') AS semanas,
        VT.cant AS cant_v, 0 AS cant_s, (VT.cant * VT.pvp_unit) AS pvp_total
    FROM dbo.dwh_ventas VT
    INNER JOIN dbo.cat_sku EC ON VT.ean = EC.ean
    INNER JOIN dbo.tiendas T ON VT.num_local = T.codigo AND T.tipo = 'TIENDA'
    INNER JOIN dbo.monitoreo M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    INNER JOIN Valid_Marca_Tipo VMT ON VMT.vmt_tipo = M.tipo 
        AND VMT.vmt_fit IS NOT DISTINCT FROM M.fit
        AND VMT.vmt_marca = COALESCE(
            (SELECT marca FROM dbo.marca_subclase WHERE ini_cliente = VT.ini_cliente AND subcategoria = substring(EC.categoria from 1 for 7) LIMIT 1),
            (SELECT new_marca FROM dbo.marca WHERE marca_bd = EC.marca LIMIT 1),
            EC.marca
        )
    LEFT JOIN dbo.semanas SEM ON VT.fecha BETWEEN SEM.dia_inicio AND SEM.dia_fin
    WHERE VT.ini_cliente = :ini_cliente 
      AND VT.fecha BETWEEN :fecha_inicio AND :fecha_fin
) syv
GROUP BY 1,2,3,4,5,6,7,8;