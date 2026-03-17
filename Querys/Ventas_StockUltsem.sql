WITH Valid_Marca_Tipo AS (
    -- Pre-calculamos el universo de marcas/tipos que cumplen el umbral
    -- Pre-calculamos las marcas que cumplen el umbral de stock para reducir el universo de datos
    SELECT
        COALESCE(MS.marca, MA.new_marca, EC.marca) AS vmt_marca
        ,M.tipo AS vmt_tipo
        ,M.fit AS vmt_fit
    FROM dbo.dwh_stock AS ST
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    -- Unión con la nueva tabla marca_subclase
    LEFT JOIN dbo.marca_subclase AS MS 
        ON ST.ini_cliente = MS.ini_cliente 
        AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    WHERE ST.ini_cliente = :ini_cliente
      AND ST.fecha = :fecha_fin_venta -- Salta directo a la partición final
    GROUP BY 1, 2, 3
    HAVING SUM(ST.cant) >= :stock_threshold
)

SELECT
    syv.ini_cliente
    ,syv.c_l
    ,syv.local
    ,syv.ciudad
    ,syv.ean
    ,syv.sku
    ,syv.sku_madre
    ,syv.descripcion
    ,syv.modelo
    ,syv.marca as "Marca"
    ,syv.subclase
    ,syv.tipo_programa AS "Tipo_Programa"
    ,syv.fit_estilo
    ,syv.color
    ,syv.cod_color
    ,syv.color_hexa
    ,syv.talla
    ,syv.fecha
    ,to_char(syv.fecha, 'YY') || '/' || to_char(syv.n_sem, 'FM00') || ' - ' || to_char(syv.fecha, 'MM/DD') AS "semanas"
    ,SUM(syv.v_cant) AS "cant_venta"
    ,SUM(syv.s_cant) AS "cant_stock"
    ,NULLIF(ROUND(SUM(syv.v_cant * syv.v_pvp) / NULLIF(SUM(syv.v_cant), 0), 0), 0) AS "pvp_prom"
FROM (
    -- BLOQUE STOCK
    SELECT
        ST.ini_cliente
        ,ST.num_local AS "c_l"
        ,T.local
        ,T.ciudad
        ,ST.ean
        ,EC.sku
        ,CF.sku_madre
        ,EC.descripcion_nueva as "descripcion"
        ,EC.ref_modelo AS "modelo"
        ,VMT.vmt_marca AS "marca"
        ,substring(EC.categoria from 1 for 7) AS subclase
        ,M.tipo AS "tipo_programa"
        ,M.fit AS "fit_estilo"
        ,CO.color AS "color"
        ,CO.codigo AS "cod_color"
        ,CO.color_hexa AS "color_hexa"
        ,EC.talla AS "talla"
        ,(date_trunc('week', ST.fecha))::date AS fecha
        ,SEM.n_sem
        ,SEM.ano
        ,0 AS "v_cant"
        ,ST.cant AS "s_cant"
        ,0 AS "v_pvp"
    FROM dbo.dwh_stock AS ST
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.ecat_fala AS CF ON ST.ean = CF.upc
    LEFT JOIN dbo.cod_color AS CO ON EC.cod_color = CO.codigo
    LEFT JOIN dbo.tiendas AS T ON ST.num_local = T.codigo AND T.ini_cliente = ST.ini_cliente
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca_subclase AS MS ON ST.ini_cliente = MS.ini_cliente AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    LEFT JOIN Valid_Marca_Tipo AS VMT ON VMT.vmt_tipo = M.tipo
    AND VMT.vmt_fit IS NOT DISTINCT FROM M.fit
    AND VMT.vmt_marca = COALESCE(MS.marca, MA.new_marca, EC.marca)
    LEFT JOIN dbo.semanas AS SEM ON (date_trunc('week', ST.fecha))::date = SEM.dia_inicio
    WHERE ST.ini_cliente = :ini_cliente
      AND ST.fecha BETWEEN :fecha_inicio_stock AND :fecha_fin_venta

    UNION ALL

    -- BLOQUE VENTAS
    SELECT
        VT.ini_cliente
        ,VT.num_local AS "c_l"
        ,T.local
        ,T.ciudad
        ,VT.ean
        ,EC.sku
        ,CF.sku_madre
        ,EC.descripcion_nueva as "descripcion"
        ,EC.ref_modelo AS "modelo"
        ,VMT.vmt_marca AS "marca"
        ,substring(EC.categoria from 1 for 7) AS subclase
        ,M.tipo AS "tipo_programa"
        ,M.fit AS "fit_estilo"
        ,CO.color AS "color"
        ,EC.cod_color AS "cod_color"
        ,CO.color_hexa AS "color_hexa"
        ,EC.talla AS "talla"
        ,(date_trunc('week', VT.fecha))::date AS fecha
        ,SEM.n_sem
        ,SEM.ano
        ,VT.cant AS "v_cant"
        ,0 AS "s_cant"
        ,VT.pvp_unit AS "v_pvp"
    FROM dbo.dwh_ventas AS VT
    LEFT JOIN dbo.cat_sku AS EC ON VT.ean = EC.ean
    LEFT JOIN dbo.ecat_fala AS CF ON VT.ean = CF.upc
    LEFT JOIN dbo.cod_color AS CO ON EC.cod_color = CO.codigo
    LEFT JOIN dbo.tiendas AS T ON VT.num_local = T.codigo AND T.ini_cliente = VT.ini_cliente
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca_subclase AS MS ON VT.ini_cliente = MS.ini_cliente AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    LEFT JOIN Valid_Marca_Tipo AS VMT ON VMT.vmt_tipo = M.tipo 
    AND VMT.vmt_fit IS NOT DISTINCT FROM M.fit
    AND VMT.vmt_marca = COALESCE(MS.marca, MA.new_marca, EC.marca)
    LEFT JOIN dbo.semanas AS SEM ON (date_trunc('week', VT.fecha))::date = SEM.dia_inicio
    WHERE VT.ini_cliente = :ini_cliente
      AND VT.fecha BETWEEN :fecha_inicio_venta AND :fecha_fin_venta
) AS syv
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19;