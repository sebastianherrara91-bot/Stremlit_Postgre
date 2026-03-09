WITH Valid_Marca_Tipo AS (
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
      AND ST.fecha = :fecha_fin
      AND T.tipo = 'TIENDA'
    GROUP BY 1, 2, 3
    HAVING SUM(ST.cant) >= :stock_threshold
)

SELECT
    syv.ini_cliente AS "Ini_Cliente",
    syv.tipo_programa AS "Tipo_Programa",
    syv.c_l AS "C_L",
    syv.local AS "Local",
    syv.ciudad AS "Ciudad",
    syv.marca AS "Marca",
    syv.semanas AS "Semanas",
    syv.fit_estilo AS "Fit_Estilo",
    syv.color_final AS "COLOR",
    syv.talla AS "Talla",
    SUM(syv.cant_v) as "Cant_Venta",
    SUM(syv.cant_s) as "Cant_Stock"
FROM (
    -- Bloque Stock
    SELECT
        ST.ini_cliente, M.tipo as tipo_programa, ST.num_local as c_l, T.local, T.ciudad,
        VMT.vmt_marca as marca,
        to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') as semanas,
        M.fit as fit_estilo, (CO.color || '-' || EC.cod_color) as color_final, EC.talla,
        0 AS cant_v, ST.cant AS cant_s
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
    LEFT JOIN dbo.cod_color CO ON EC.cod_color = CO.codigo
    LEFT JOIN dbo.semanas SEM ON ST.fecha BETWEEN SEM.dia_inicio AND SEM.dia_fin
    WHERE ST.ini_cliente = :ini_cliente 
      AND ST.fecha BETWEEN :fecha_inicio_stock AND :fecha_fin

    UNION ALL

    -- Bloque Ventas
    SELECT
        VT.ini_cliente, M.tipo as tipo_programa, VT.num_local as c_l, T.local, T.ciudad,
        VMT.vmt_marca as marca,
        to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') as semanas,
        M.fit as fit_estilo, (CO.color || '-' || EC.cod_color) as color_final, EC.talla,
        VT.cant AS cant_v, 0 AS cant_s
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
    LEFT JOIN dbo.cod_color CO ON EC.cod_color = CO.codigo
    LEFT JOIN dbo.semanas SEM ON VT.fecha BETWEEN SEM.dia_inicio AND SEM.dia_fin
    WHERE VT.ini_cliente = :ini_cliente 
      AND VT.fecha BETWEEN :fecha_inicio AND :fecha_fin
) syv
GROUP BY 1,2,3,4,5,6,7,8,9,10;