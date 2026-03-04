WITH params AS (
    SELECT 
        :fecha_inicio_venta::DATE AS fecha_inicio_venta,
        :fecha_fin_venta::DATE AS fecha_fin_venta,
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
      AND ST.fecha = P.fecha_fin_venta
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

Select
    syv.ini_cliente AS "Ini_Cliente",
    syv.c_l AS "C_L",
    syv.local AS "Local",
    syv.ciudad AS "Ciudad",
    syv.l_tipo AS "L_Tipo",
    syv.curva as "Curva",
    syv.ean AS "EAN",
    syv.sku AS "SKU",
    syv.desc_agrupacion AS "Desc Agrupacion",
    syv.modelo AS "Modelo",
    syv.marca AS "Marca",
    syv.subclase AS "Subclase",
    syv.tipo_programa AS "Tipo_Programa",
    syv.fit_estilo as "Fit_Estilo",
    syv.c_color as "C_Color",
    syv.color_xxxx AS "COLOR_XXXX",
    syv.color AS "COLOR",
    syv.color_hexa AS "Color_Hexa",
    syv.tipo_color AS "TIPO_COLOR",
    syv.talla as "Talla",
    syv.fecha AS "Fecha",
    to_char(syv.fecha, 'YY') || '/' || to_char(syv.n_sem, 'FM00') || ' - ' || to_char(syv.fecha, 'MM/DD') as "Semanas",
    syv.n_sem AS "N_Sem",
    syv.ano AS "Ano",
    SUM(syv.cant) as "Cant_Venta",
    SUM(syv.stock) as "Cant_Stock",
    CASE WHEN SUM(syv.cant) = 0 THEN NULL ELSE ROUND(SUM(syv.cant * syv.pvp_unit)/ SUM(syv.cant),0) END as "PVP_Prom"

From(

SELECT
    -- BASE DE DATOS STOCK
    ST.ini_cliente AS ini_cliente,
    ST.num_local AS c_l,
    T.local AS local,
    T.ciudad AS ciudad,
    T.tipo AS l_tipo,
    T.curva AS curva,
    ST.ean AS ean,
    EC.sku AS sku,
    EC.modelo_agrupacion AS desc_agrupacion,
    EC.ref_modelo AS modelo,
    CASE 
        WHEN substr(EC.categoria,1,7) = 'J090103' THEN 'YAMP B'
        WHEN substr(EC.categoria,1,7) = 'J090303' THEN 'YAMP G'
        WHEN substr(EC.categoria,1,7) = 'J090504' THEN 'YAMP BEBA'
        WHEN substr(EC.categoria,1,7) = 'J090503' THEN 'YAMP BEBO'
        ELSE COALESCE(MA.new_marca, EC.marca )
    END  AS marca,
    substr(EC.categoria,1,7) AS subclase,
    M.tipo AS tipo_programa,
    M.fit AS fit_estilo,
    EC.cod_color AS c_color,
    CO.color_xxxx AS color_xxxx,
    CO.color AS color,
    CO.color_hexa AS color_hexa,
    CO.tipo_color AS tipo_color,
    EC.talla AS talla,
    date_trunc('week', ST.fecha)::date AS fecha,
    SEM.n_sem as n_sem,
    SEM.ano as ano,
    0 AS cant,
    ST.cant AS stock,
    0 AS pvp_unit
 
FROM dbo.dwh_stock AS ST
CROSS JOIN params P
LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo and EC.marca = M.marca
LEFT JOIN dbo.cod_color as CO on EC.cod_color = CO.codigo
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
and st.fecha between P.fecha_inicio_stock and P.fecha_fin_venta

UNION ALL

SELECT
    -- BASE DE DATOS VENTAS
    VT.ini_cliente AS ini_cliente,
    VT.num_local AS c_l,
    T.local AS local,
    T.ciudad AS ciudad,
    T.tipo AS l_tipo,
    T.curva AS curva,
    VT.ean AS ean,
    EC.sku AS sku,
    EC.modelo_agrupacion AS desc_agrupacion,
    EC.ref_modelo AS modelo,
    CASE 
        WHEN substr(EC.categoria,1,7) = 'J090103' THEN 'YAMP B'
        WHEN substr(EC.categoria,1,7) = 'J090303' THEN 'YAMP G'
        WHEN substr(EC.categoria,1,7) = 'J090504' THEN 'YAMP BEBA'
        WHEN substr(EC.categoria,1,7) = 'J090503' THEN 'YAMP BEBO'
        ELSE COALESCE(MA.new_marca, EC.marca )
    END  AS marca,
    substr(EC.categoria,1,7) AS subclase,
    M.tipo AS tipo_programa,
    M.fit AS fit_estilo,
    EC.cod_color AS c_color,
    CO.color_xxxx AS color_xxxx,
    CO.color AS color,
    CO.color_hexa AS color_hexa,
    CO.tipo_color AS tipo_color,
    EC.talla AS talla,
    date_trunc('week', VT.fecha)::date AS fecha,
    SEM.n_sem as n_sem,
    SEM.ano as ano,
    VT.cant as cant,
    0 AS stock,
    NULLIF(VT.pvp_unit,0) as pvp_unit
 
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
and VT.fecha between P.fecha_inicio_venta and P.fecha_fin_venta

) as syv

GROUP BY
    syv.ini_cliente,
    syv.c_l,
    syv.local,
    syv.ciudad,
    syv.l_tipo,
    syv.curva,
    syv.ean,
    syv.sku,
    syv.desc_agrupacion,
    syv.modelo,
    syv.marca,
    syv.subclase,
    syv.tipo_programa,
    syv.fit_estilo,
    syv.c_color,
    syv.color_xxxx,
    syv.color,
    syv.color_hexa,
    syv.tipo_color,
    syv.talla,
    syv.fecha,
    to_char(syv.fecha, 'YY') || '/' || to_char(syv.n_sem, 'FM00') || ' - ' || to_char(syv.fecha, 'MM/DD'),
    syv.n_sem,
    syv.ano;
