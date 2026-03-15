WITH Valid_Marca_Tipo AS (
    -- Paso 1: Identificamos qué marcas/estilos tienen stock suficiente
    SELECT
        COALESCE(MS.marca, MA.new_marca, EC.marca) AS vmt_marca,
        M.tipo AS vmt_tipo
    FROM dbo.dwh_stock AS ST
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    LEFT JOIN dbo.marca_subclase AS MS 
        ON ST.ini_cliente = MS.ini_cliente 
        AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    WHERE ST.ini_cliente = :ini_cliente AND ST.fecha = :fecha_fin
    GROUP BY 1, 2
    HAVING SUM(ST.cant) >= :stock_threshold
)

SELECT
    sub.ini_cliente AS "Ini_Cliente",
    sub.tipo_calc AS "Tipo_Programa",
    sub.c_l AS "C_L",
    sub.local AS "Local",
    sub.ciudad AS "Ciudad",
    sub.marca_calc AS "Marca",
    to_char(SEM.dia_fin, 'YYYY-MM-DD') || ' Sem ' || to_char(SEM.n_sem, 'FM00') AS "Semanas",
    sub.fit_calc AS "Fit_Estilo",
    sub.color_final AS "Color",
    sub.talla AS "Talla",
    SUM(sub.v_cant) AS "Cant_Venta",
    SUM(sub.s_cant) AS "Cant_Stock"
FROM (
    -- BLOQUE STOCK
    SELECT
        ST.ini_cliente,
        M.tipo AS tipo_calc,
        ST.num_local AS c_l,
        T.local,
        T.ciudad,
        COALESCE(MS.marca, MA.new_marca, EC.marca) AS marca_calc,
        M.fit AS fit_calc,
        (CO.color || '-' || EC.cod_color) AS color_final,
        EC.talla,
        (date_trunc('week', ST.fecha))::date AS lunes_sem,
        0 AS v_cant,
        ST.cant AS s_cant
    FROM dbo.dwh_stock AS ST
    LEFT JOIN dbo.cat_sku AS EC ON ST.ean = EC.ean
    INNER JOIN dbo.tiendas AS T ON ST.num_local = T.codigo AND T.ini_cliente = ST.ini_cliente AND T.tipo = 'TIENDA'
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.cod_color AS CO ON EC.cod_color = CO.codigo
    LEFT JOIN dbo.marca_subclase AS MS ON ST.ini_cliente = MS.ini_cliente AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    WHERE ST.ini_cliente = :ini_cliente 
      AND ST.fecha BETWEEN :fecha_inicio_stock AND :fecha_fin

    UNION ALL

    -- BLOQUE VENTAS
    SELECT
        VT.ini_cliente,
        M.tipo AS tipo_calc,
        VT.num_local AS c_l,
        T.local,
        T.ciudad,
        COALESCE(MS.marca, MA.new_marca, EC.marca) AS marca_calc,
        M.fit AS fit_calc,
        (CO.color || '-' || EC.cod_color) AS color_final,
        EC.talla,
        (date_trunc('week', VT.fecha))::date AS lunes_sem,
        VT.cant AS v_cant,
        0 AS s_cant
    FROM dbo.dwh_ventas AS VT
    LEFT JOIN dbo.cat_sku AS EC ON VT.ean = EC.ean
    INNER JOIN dbo.tiendas AS T ON VT.num_local = T.codigo AND T.ini_cliente = VT.ini_cliente AND T.tipo = 'TIENDA'
    LEFT JOIN dbo.monitoreo AS M ON EC.ref_modelo = M.modelo AND EC.marca = M.marca
    LEFT JOIN dbo.cod_color AS CO ON EC.cod_color = CO.codigo
    LEFT JOIN dbo.marca_subclase AS MS ON VT.ini_cliente = MS.ini_cliente AND substring(EC.categoria from 1 for 7) = MS.subcategoria
    LEFT JOIN dbo.marca AS MA ON EC.marca = MA.marca_bd
    WHERE VT.ini_cliente = :ini_cliente 
      AND VT.fecha BETWEEN :fecha_inicio AND :fecha_fin
) AS sub
-- UNIÓN CON EL UNIVERSO DE MARCAS VALIDADO (Sin funciones pesadas en el ON)
INNER JOIN Valid_Marca_Tipo VMT ON VMT.vmt_marca = sub.marca_calc AND VMT.vmt_tipo = sub.tipo_calc
-- CRUCE EXACTO CON SEMANAS (Mucho más rápido que BETWEEN)
LEFT JOIN dbo.semanas SEM ON sub.lunes_sem = SEM.dia_inicio 

GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10;