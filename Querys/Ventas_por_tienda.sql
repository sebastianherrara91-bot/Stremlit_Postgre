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
    syv.c_l AS "C_L",
    syv.local AS "Local",
    syv.ciudad AS "Ciudad",
    syv.marca AS "Marca",
    syv.tipo_programa AS "Tipo_Programa",
    syv.fit_estilo AS "Fit_Estilo",
    syv.semanas AS "Semanas",
    SUM(syv.cant_venta) as "Cant_Venta",
    SUM(syv.cant_stock) as "Cant_Stock",
    ROUND(CASE WHEN SUM(syv.cant_venta) = 0 THEN 0 ELSE SUM(syv.pvp_x_venta) / SUM(syv.cant_venta) END, 0) as "PVP_Prom"
FROM (
    SELECT
        ST.ini_cliente AS ini_cliente,
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
        M.tipo AS tipo_programa,
        M.fit AS fit_estilo,
        to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') as semanas,
        0 AS cant_venta,
        ST.cant AS cant_stock,
        0 AS pvp_x_venta -- No aplica para stock
    FROM dbo.dwh_stock AS ST
    CROSS JOIN params P
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo and EC.marca = M.marca
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

    SELECT
        VT.ini_cliente AS ini_cliente,
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
        M.tipo AS tipo_programa,
        M.fit AS fit_estilo,
        to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') as semanas,
        VT.cant as cant_venta,
        0 AS cant_stock,
        VT.cant * NULLIF(VT.pvp_unit,0) as pvp_x_venta -- Pre-calculamos el total para el promedio ponderado
    FROM dbo.dwh_ventas VT
    CROSS JOIN params P
    LEFT JOIN dbo.cat_sku AS EC ON VT.ean = EC.ean
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
    syv.c_l,
    syv.local,
    syv.ciudad,
    syv.marca,
    syv.tipo_programa,
    syv.fit_estilo,
    syv.semanas;
