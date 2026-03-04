WITH params AS (
    SELECT 
        CAST(:semanas_stock AS INT) AS semanas_stock,
        CAST(:semanas_venta AS INT) AS semanas_venta,
        CAST(:ini_cliente AS VARCHAR) AS ini_cliente,
        CAST(:stock_threshold AS INT) AS stock_threshold,
        (date_trunc('week', current_date) - interval '2 days')::date AS fecha_corte
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
      AND ST.fecha = P.fecha_corte
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
    concat(substr(syv.ciudad, 6, 20), ' - ', syv.local) AS "Tienda",    
    syv.marca AS "Marca",
    syv.fecha AS "FECHA",
    syv.n_sem AS "N_SEM",
    syv.ano AS "ANO",
    SUM(syv.cant_venta) as "Cant_Venta",
    SUM(syv.cant_stock) as "Cant_Stock"
FROM (
    -- Stock (última semana)
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
        ST.fecha AS fecha,
        SEM.n_sem AS n_sem,
        SEM.ano AS ano,
        0 AS cant_venta,
        ST.cant AS cant_stock
    FROM dbo.dwh_stock AS ST
    CROSS JOIN params P
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.cod_color as CO on EC.cod_color = CO.codigo
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo and EC.marca = M.marca
    LEFT JOIN dbo.tiendas AS T ON ST.num_local = T.codigo
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    LEFT JOIN dbo.semanas AS SEM ON date_trunc('week', ST.fecha)::date = SEM.dia_inicio
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
    and 
    (
        ST.fecha between (P.fecha_corte - (P.semanas_stock || ' weeks')::interval)::date and P.fecha_corte
        OR ST.fecha between (P.fecha_corte - interval '52 weeks' - (P.semanas_stock || ' weeks')::interval)::date and (P.fecha_corte - interval '52 weeks')::date
    )
    UNION ALL

    -- Ventas (últimas N semanas)
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
        VT.fecha AS fecha,
        SEM.n_sem AS n_sem,
        SEM.ano AS ano,
        VT.cant as cant_venta,
        0 AS cant_stock
    FROM dbo.dwh_ventas VT
    CROSS JOIN params P
    LEFT JOIN dbo.cat_sku AS EC ON VT.ean = EC.ean
    LEFT JOIN dbo.cod_color as CO on EC.cod_color = CO.codigo
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo and EC.marca = M.marca
    LEFT JOIN dbo.tiendas AS T ON VT.num_local = T.codigo
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    LEFT JOIN dbo.semanas AS SEM ON date_trunc('week', VT.fecha)::date = SEM.dia_inicio
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
    and 
    (
        VT.fecha between (P.fecha_corte - (P.semanas_venta || ' weeks')::interval)::date and P.fecha_corte
        OR VT.fecha between (P.fecha_corte - interval '52 weeks' - (P.semanas_venta || ' weeks')::interval)::date and (P.fecha_corte - interval '52 weeks')::date
    )

) as syv
GROUP BY
    syv.ini_cliente,
    syv.tipo_programa,
    syv.c_l,
    concat(substr(syv.ciudad, 6, 20), ' - ', syv.local),
    syv.marca,
    syv.fecha,
    syv.n_sem,
    syv.ano;
