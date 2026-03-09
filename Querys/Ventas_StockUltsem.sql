WITH Valid_Marca_Tipo AS (
    -- Pre-calculamos las marcas que cumplen el umbral de stock para reducir el universo de datos
    SELECT
        CASE
            WHEN substring(EC.categoria from 1 for 7) = 'J090103' THEN 'YAMP B'
            WHEN substring(EC.categoria from 1 for 7) = 'J090303' THEN 'YAMP G'
            WHEN substring(EC.categoria from 1 for 7) = 'J090504' THEN 'YAMP BEBA'
            WHEN substring(EC.categoria from 1 for 7) = 'J090503' THEN 'YAMP BEBO'
            ELSE COALESCE(MA.new_marca, EC.marca)
        END AS vmt_marca,
        M.tipo AS vmt_tipo,
        M.fit AS vmt_fit
    FROM dbo.dwh_stock AS ST
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    LEFT JOIN dbo.tiendas AS T ON ST.num_local = T.codigo
    WHERE ST.ini_cliente = :ini_cliente
      AND ST.fecha = :fecha_fin_venta -- Pruning directo al cuatrimestre final
      AND T.tipo = 'TIENDA'
    GROUP BY 1, 2, 3
    HAVING SUM(ST.cant) >= :stock_threshold
)

SELECT
    syv.ini_cliente AS "Ini_Cliente",
    syv.c_l AS "C_L",
    syv.local AS "Local",
    syv.ciudad AS "Ciudad",
    syv.l_tipo AS "L_Tipo",
    syv.curva AS "Curva",
    syv.ean AS "EAN",
    syv.sku AS "SKU",
    syv.desc_agrupacion AS "Desc Agrupacion",
    syv.modelo AS "Modelo",
    syv.marca AS "Marca",
    syv.subclase AS "Subclase",
    syv.tipo_programa AS "Tipo_Programa",
    syv.fit_estilo AS "Fit_Estilo",
    syv.c_color AS "C_Color",
    syv.color_xxxx AS "COLOR_XXXX",
    syv.color AS "COLOR",
    syv.color_hexa AS "Color_Hexa",
    syv.tipo_color AS "TIPO_COLOR",
    syv.talla AS "Talla",
    syv.fecha AS "Fecha",
    to_char(syv.fecha, 'YY') || '/' || to_char(syv.n_sem, 'FM00') || ' - ' || to_char(syv.fecha, 'MM/DD') AS "Semanas",
    syv.n_sem AS "N_Sem",
    syv.ano AS "Ano",
    SUM(syv.v_cant) AS "Cant_Venta",
    SUM(syv.s_cant) AS "Cant_Stock",
    CASE 
        WHEN SUM(syv.v_cant) = 0 THEN NULL 
        ELSE ROUND(SUM(syv.v_cant * syv.v_pvp) / NULLIF(SUM(syv.v_cant), 0), 0) 
    END AS "PVP_Prom"
FROM (
    -- BLOQUE DE STOCK (Apunta directamente a las particiones de stock)
    SELECT
        ST.ini_cliente, ST.num_local AS c_l, T.local, T.ciudad, T.tipo AS l_tipo, T.curva,
        ST.ean, EC.sku, EC.modelo_agrupacion AS desc_agrupacion, EC.ref_modelo AS modelo,
        VMT.vmt_marca AS marca, substring(EC.categoria from 1 for 7) AS subclase,
        VMT.vmt_tipo AS tipo_programa, VMT.vmt_fit AS fit_estilo,
        EC.cod_color AS c_color, CO.color_xxxx, CO.color, CO.color_hexa, CO.tipo_color,
        EC.talla, (date_trunc('week', ST.fecha))::date AS fecha, SEM.n_sem, SEM.ano,
        0 AS v_cant, ST.cant AS s_cant, 0 AS v_pvp
    FROM dbo.dwh_stock AS ST
    INNER JOIN dbo.tiendas AS T ON ST.num_local = T.codigo AND T.tipo = 'TIENDA'
    INNER JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    INNER JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    INNER JOIN Valid_Marca_Tipo VMT ON VMT.vmt_tipo = M.tipo 
        AND VMT.vmt_fit IS NOT DISTINCT FROM M.fit
        AND VMT.vmt_marca = (
            CASE 
                WHEN substring(EC.categoria from 1 for 7) = 'J090103' THEN 'YAMP B'
                WHEN substring(EC.categoria from 1 for 7) = 'J090303' THEN 'YAMP G'
                WHEN substring(EC.categoria from 1 for 7) = 'J090504' THEN 'YAMP BEBA'
                WHEN substring(EC.categoria from 1 for 7) = 'J090503' THEN 'YAMP BEBO'
                ELSE (SELECT COALESCE(new_marca, EC.marca) FROM dbo.marca WHERE marca_bd = EC.marca LIMIT 1)
            END
        )
    LEFT JOIN dbo.cod_color AS CO ON EC.cod_color = CO.codigo
    LEFT JOIN dbo.semanas AS SEM ON (date_trunc('week', ST.fecha))::date = SEM.dia_inicio
    WHERE ST.ini_cliente = :ini_cliente
      AND ST.fecha BETWEEN :fecha_inicio_stock AND :fecha_fin_venta

    UNION ALL

    -- BLOQUE DE VENTAS (Apunta directamente a las particiones de ventas)
    SELECT
        VT.ini_cliente, VT.num_local AS c_l, T.local, T.ciudad, T.tipo AS l_tipo, T.curva,
        VT.ean, EC.sku, EC.modelo_agrupacion AS desc_agrupacion, EC.ref_modelo AS modelo,
        VMT.vmt_marca AS marca, substring(EC.categoria from 1 for 7) AS subclase,
        VMT.vmt_tipo AS tipo_programa, VMT.vmt_fit AS fit_estilo,
        EC.cod_color AS c_color, CO.color_xxxx, CO.color, CO.color_hexa, CO.tipo_color,
        EC.talla, (date_trunc('week', VT.fecha))::date AS fecha, SEM.n_sem, SEM.ano,
        VT.cant AS v_cant, 0 AS s_cant, VT.pvp_unit AS v_pvp
    FROM dbo.dwh_ventas AS VT
    INNER JOIN dbo.tiendas AS T ON VT.num_local = T.codigo AND T.tipo = 'TIENDA'
    INNER JOIN dbo.cat_sku AS EC ON VT.ean = EC.ean
    INNER JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    INNER JOIN Valid_Marca_Tipo VMT ON VMT.vmt_tipo = M.tipo 
        AND VMT.vmt_fit IS NOT DISTINCT FROM M.fit
        AND VMT.vmt_marca = (
            CASE 
                WHEN substring(EC.categoria from 1 for 7) = 'J090103' THEN 'YAMP B'
                WHEN substring(EC.categoria from 1 for 7) = 'J090303' THEN 'YAMP G'
                WHEN substring(EC.categoria from 1 for 7) = 'J090504' THEN 'YAMP BEBA'
                WHEN substring(EC.categoria from 1 for 7) = 'J090503' THEN 'YAMP BEBO'
                ELSE (SELECT COALESCE(new_marca, VT.marca) FROM dbo.marca WHERE marca_bd = VT.marca LIMIT 1)
            END
        )
    LEFT JOIN dbo.cod_color AS CO ON EC.cod_color = CO.codigo
    LEFT JOIN dbo.semanas AS SEM ON (date_trunc('week', VT.fecha))::date = SEM.dia_inicio
    WHERE VT.ini_cliente = :ini_cliente
      AND VT.fecha BETWEEN :fecha_inicio_venta AND :fecha_fin_venta
) AS syv
GROUP BY 
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 24;