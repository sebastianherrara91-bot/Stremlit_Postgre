WITH params AS (
    SELECT 
        :fecha_inicio::DATE AS fecha_inicio,
        :fecha_fin::DATE AS fecha_fin,
        :fecha_inicio_stock::DATE AS fecha_inicio_stock,
        :ini_cliente::VARCHAR AS ini_cliente,
        :stock_threshold::INT AS stock_threshold
),
Valid_Marca_Tipo AS (
    SELECT
        CASE
            WHEN substr(EC.categoria,1,7) = 'J090103' THEN 'YAMP B'
            WHEN substr(EC.categoria,1,7) = 'J090303' THEN 'YAMP G'
            WHEN substr(EC.categoria,1,7) = 'J090504' THEN 'YAMP BEBA'
            WHEN substr(EC.categoria,1,7) = 'J090503' THEN 'YAMP BEBO'
            ELSE COALESCE(MA.new_marca, EC.marca )
        END AS "Marca",
        M.tipo AS "Tipo_Programa",
        M.fit AS "Fit_Estilo"
    FROM dbo.dwh_stock AS ST
    CROSS JOIN params P
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo and EC.marca = M.marca
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    LEFT JOIN dbo.tiendas AS T ON ST.num_local = T.codigo
    WHERE ST.ini_cliente = P.ini_cliente
      AND T.tipo = 'TIENDA'
      AND ST.fecha = P.fecha_fin
    GROUP BY
        CASE
            WHEN substr(EC.categoria,1,7) = 'J090103' THEN 'YAMP B'
            WHEN substr(EC.categoria,1,7) = 'J090303' THEN 'YAMP G'
            WHEN substr(EC.categoria,1,7) = 'J090504' THEN 'YAMP BEBA'
            WHEN substr(EC.categoria,1,7) = 'J090503' THEN 'YAMP BEBO'
            ELSE COALESCE(MA.new_marca, EC.marca )
        END,
        M.tipo,
        M.fit
    HAVING SUM(ST.cant) >= MAX(P.stock_threshold)
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
    syv.color AS "COLOR",
    syv.c_color AS "C_Color",
    syv.color_hexa AS "Color_Hexa",
    SUM(syv.cant_venta) as "Cant_Venta",
    SUM(syv.cant_stock) as "Cant_Stock"
FROM (
    -- Stock
    SELECT
        ST.ini_cliente AS ini_cliente,
        M.tipo AS tipo_programa,
        ST.num_local AS c_l,
        T.local AS local,
        T.ciudad AS ciudad,
        CASE
            WHEN substr(EC.categoria,1,7) = 'J090103' THEN 'YAMP B'
            WHEN substr(EC.categoria,1,7) = 'J090303' THEN 'YAMP G'
            WHEN substr(EC.categoria,1,7) = 'J090504' THEN 'YAMP BEBA'
            WHEN substr(EC.categoria,1,7) = 'J090503' THEN 'YAMP BEBO'
            ELSE COALESCE(MA.new_marca, EC.marca )
        END AS marca,
        to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') as semanas,
        M.fit AS fit_estilo,
        CO.color,
        EC.cod_color as c_color,
        CO.color_hexa,
        0 AS cant_venta,
        ST.cant AS cant_stock
    FROM dbo.dwh_stock AS ST
    CROSS JOIN params P
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo and EC.marca = M.marca
    LEFT JOIN dbo.cod_color as CO on EC.cod_color = CO.codigo
    LEFT JOIN dbo.tiendas AS T ON ST.num_local = T.codigo
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    LEFT JOIN dbo.semanas AS SEM ON ST.fecha BETWEEN SEM.dia_inicio AND SEM.dia_fin
    INNER JOIN Valid_Marca_Tipo VMT ON VMT."Marca" = (
        CASE
            WHEN substr(EC.categoria,1,7) = 'J090103' THEN 'YAMP B'
            WHEN substr(EC.categoria,1,7) = 'J090303' THEN 'YAMP G'
            WHEN substr(EC.categoria,1,7) = 'J090504' THEN 'YAMP BEBA'
            WHEN substr(EC.categoria,1,7) = 'J090503' THEN 'YAMP BEBO'
            ELSE COALESCE(MA.new_marca, EC.marca )
        END
    ) AND VMT."Tipo_Programa" = M.tipo AND COALESCE(VMT."Fit_Estilo",'') = COALESCE(M.fit,'')

    WHERE ST.ini_cliente = P.ini_cliente and T.tipo = 'TIENDA'
    and ST.fecha between P.fecha_inicio_stock and P.fecha_fin

    UNION ALL

    -- Ventas
    SELECT
        VT.ini_cliente AS ini_cliente,
        M.tipo AS tipo_programa,
        VT.num_local AS c_l,
        T.local AS local,
        T.ciudad AS ciudad,
        CASE
            WHEN substr(EC.categoria,1,7) = 'J090103' THEN 'YAMP B'
            WHEN substr(EC.categoria,1,7) = 'J090303' THEN 'YAMP G'
            WHEN substr(EC.categoria,1,7) = 'J090504' THEN 'YAMP BEBA'
            WHEN substr(EC.categoria,1,7) = 'J090503' THEN 'YAMP BEBO'
            ELSE COALESCE(MA.new_marca, EC.marca )
        END AS marca,
        to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') as semanas,
        M.fit AS fit_estilo,
        CO.color,
        EC.cod_color as c_color,
        CO.color_hexa,
        VT.cant as cant_venta,
        0 AS cant_stock
    FROM dbo.dwh_ventas VT
    CROSS JOIN params P
    LEFT JOIN dbo.cat_sku AS EC ON VT.ean = EC.ean
    LEFT JOIN dbo.cod_color as CO on EC.cod_color = CO.codigo
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo and EC.marca = M.marca
    LEFT JOIN dbo.tiendas AS T ON VT.num_local = T.codigo
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    LEFT JOIN dbo.semanas AS SEM ON VT.fecha BETWEEN SEM.dia_inicio AND SEM.dia_fin
    INNER JOIN Valid_Marca_Tipo VMT ON VMT."Marca" = (
        CASE
            WHEN substr(EC.categoria,1,7) = 'J090103' THEN 'YAMP B'
            WHEN substr(EC.categoria,1,7) = 'J090303' THEN 'YAMP G'
            WHEN substr(EC.categoria,1,7) = 'J090504' THEN 'YAMP BEBA'
            WHEN substr(EC.categoria,1,7) = 'J090503' THEN 'YAMP BEBO'
            ELSE COALESCE(MA.new_marca, EC.marca )
        END
    ) AND VMT."Tipo_Programa" = M.tipo AND COALESCE(VMT."Fit_Estilo",'') = COALESCE(M.fit,'')

    WHERE VT.ini_cliente = P.ini_cliente and T.tipo = 'TIENDA'
    and VT.fecha between P.fecha_inicio and P.fecha_fin

) as syv
GROUP BY
    syv.ini_cliente,
    syv.tipo_programa,
    syv.c_l,
    syv.local,
    syv.ciudad,
    syv.marca,
    syv.semanas,
    syv.fit_estilo,
    syv.color,
    syv.c_color,
    syv.color_hexa;
